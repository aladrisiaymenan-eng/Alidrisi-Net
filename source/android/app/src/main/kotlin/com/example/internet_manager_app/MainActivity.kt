package com.example.internet_manager_app

import android.Manifest
import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private lateinit var deviceChannel: MethodChannel
    private lateinit var vpnChannel: MethodChannel
    // App/package metadata and NetworkStats are independent reads. Two workers
    // let Flutter publish the installed apps while the history query continues.
    private val worker = Executors.newFixedThreadPool(2)
    private var pendingVpnResult: MethodChannel.Result? = null
    private var pendingVpnPackages: List<String> = emptyList()
    private var pendingVpnAutomaticPackages: List<String> = emptyList()
    private var pendingVpnBackgroundPackages: List<String> = emptyList()
    private var pendingNotificationResult: MethodChannel.Result? = null
    private var pendingVpnPermissionResult: MethodChannel.Result? = null
    private val vpnRequestCode = 7101
    private val notificationRequestCode = 7102
    private val vpnPermissionRequestCode = 7103

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        deviceChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_CHANNEL)
        deviceChannel.setMethodCallHandler { call, result -> handleDeviceCall(call, result) }

        vpnChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VPN_CHANNEL)
        vpnChannel.setMethodCallHandler { call, result -> handleVpnCall(call, result) }
    }

    private fun handleDeviceCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getInstalledApps" -> worker.execute {
                try {
                    val rows = readInstalledApps()
                    runOnUiThread { result.success(rows) }
                } catch (error: Exception) {
                    runOnUiThread { result.error("APPS_READ_FAILED", error.message, null) }
                }
            }
            "getUsageStats" -> worker.execute {
                try {
                    val start = call.argument<Long>("startMillis") ?: System.currentTimeMillis() - 30L * DAY_MS
                    val end = call.argument<Long>("endMillis") ?: System.currentTimeMillis()
                    val rows = NetworkStatsReader(this).readPerUid(start, end)
                    runOnUiThread { result.success(rows) }
                } catch (error: Exception) {
                    runOnUiThread { result.error("USAGE_READ_FAILED", error.message, null) }
                }
            }
            "getUsageHistory" -> worker.execute {
                try {
                    val start = call.argument<Long>("startMillis") ?: System.currentTimeMillis() - 30L * DAY_MS
                    val end = call.argument<Long>("endMillis") ?: System.currentTimeMillis()
                    val rows = NetworkStatsReader(this).readDaily(start, end)
                    runOnUiThread { result.success(rows) }
                } catch (error: Exception) {
                    runOnUiThread { result.error("HISTORY_READ_FAILED", error.message, null) }
                }
            }
            "getPermissionStatus" -> result.success(permissionStatus())
            "getNetworkStatsDiagnostics" -> result.success(hashMapOf(
                "lastError" to (NetworkStatsReader.lastError ?: "")
            ))
            "openUsageAccessSettings" -> {
                startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                result.success("OPENED")
            }
            "openVpnSettings" -> {
                startActivity(Intent(Settings.ACTION_VPN_SETTINGS))
                result.success("OPENED")
            }
            "requestVpnPermission" -> requestVpnPermission(result)
            "requestNotificationPermission" -> requestNotificationPermission(result)
            "startSpeedService" -> startSpeedService(result)
            "stopSpeedService" -> {
                stopService(Intent(this, InternetSpeedService::class.java))
                result.success("STOPPED")
            }
            "startLimitMonitor" -> startLimitMonitor(result)
            "stopLimitMonitor" -> {
                stopService(Intent(this, InternetLimitMonitorService::class.java))
                result.success("STOPPED")
            }
            "clearAutomaticBlocks" -> {
                val intent = Intent(this, InternetManagerVpnService::class.java)
                    .setAction(InternetManagerVpnService.ACTION_CLEAR_AUTOMATIC)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent) else startService(intent)
                result.success("REQUESTED")
            }
            "getRealtimeSpeed" -> result.success(InternetSpeedService.snapshot(this))
            else -> result.notImplemented()
        }
    }

    private fun handleVpnCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startVpn" -> {
                val packages = call.argument<List<String>>("blockedPackages") ?: emptyList()
                val automaticPackages = call.argument<List<String>>("automaticBlockedPackages") ?: emptyList()
                val backgroundPackages = call.argument<List<String>>("backgroundBlockedPackages") ?: emptyList()
                if (packages.isEmpty() && automaticPackages.isEmpty() && backgroundPackages.isEmpty()) {
                    result.success("NO_BLOCKED_APPS")
                    return
                }
                val prepareIntent = VpnService.prepare(this)
                if (prepareIntent != null) {
                    pendingVpnResult?.error("VPN_REQUEST_REPLACED", "A VPN permission request is already pending", null)
                    pendingVpnResult = result
                    pendingVpnPackages = packages
                    pendingVpnAutomaticPackages = automaticPackages
                    pendingVpnBackgroundPackages = backgroundPackages
                    startActivityForResult(prepareIntent, vpnRequestCode)
                } else {
                    startVpnService(packages, automaticPackages, backgroundPackages, result)
                }
            }
            "updateAutomaticBlocks" -> {
                val packages = call.argument<List<String>>("automaticBlockedPackages") ?: emptyList()
                val intent = Intent(this, InternetManagerVpnService::class.java)
                    .setAction(InternetManagerVpnService.ACTION_UPDATE_AUTOMATIC_POLICIES)
                    .putStringArrayListExtra(InternetManagerVpnService.EXTRA_AUTOMATIC_PACKAGES, ArrayList(packages))
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent) else startService(intent)
                    result.success("UPDATED")
                } catch (error: Exception) {
                    result.error("VPN_UPDATE_FAILED", error.message, null)
                }
            }
            "updatePolicies" -> {
                val packages = call.argument<List<String>>("blockedPackages") ?: emptyList()
                val automaticPackages = call.argument<List<String>>("automaticBlockedPackages")
                val backgroundPackages = call.argument<List<String>>("backgroundBlockedPackages")
                val intent = Intent(this, InternetManagerVpnService::class.java)
                    .setAction(InternetManagerVpnService.ACTION_UPDATE_POLICIES)
                    .putStringArrayListExtra(InternetManagerVpnService.EXTRA_BLOCKED_PACKAGES, ArrayList(packages))
                if (automaticPackages != null) {
                    intent.putStringArrayListExtra(InternetManagerVpnService.EXTRA_AUTOMATIC_PACKAGES, ArrayList(automaticPackages))
                }
                if (backgroundPackages != null) {
                    intent.putStringArrayListExtra(InternetManagerVpnService.EXTRA_BACKGROUND_PACKAGES, ArrayList(backgroundPackages))
                }
                try {
                    // Send an empty manual list as well: the VPN service keeps
                    // automatic limit blocks and stops only when both sets are empty.
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent) else startService(intent)
                    result.success("UPDATED")
                } catch (error: Exception) {
                    result.error("VPN_UPDATE_FAILED", error.message, null)
                }
            }
            "blockApp" -> {
                val packageName = call.argument<String>("packageName")
                if (packageName.isNullOrBlank()) {
                    result.error("INVALID_PACKAGE", "packageName is required", null)
                } else {
                    val intent = Intent(this, InternetManagerVpnService::class.java)
                        .setAction(InternetManagerVpnService.ACTION_BLOCK_APP)
                        .putExtra(InternetManagerVpnService.EXTRA_PACKAGE_NAME, packageName)
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent) else startService(intent)
                        result.success("UPDATED")
                    } catch (error: Exception) {
                        result.error("VPN_UPDATE_FAILED", error.message, null)
                    }
                }
            }
            "stopVpn" -> {
                stopService(Intent(this, InternetManagerVpnService::class.java))
                result.success("STOPPED")
            }
            else -> result.notImplemented()
        }
    }

    private fun requestVpnPermission(result: MethodChannel.Result) {
        val prepareIntent = VpnService.prepare(this)
        if (prepareIntent == null) {
            result.success("GRANTED")
            return
        }
        pendingVpnPermissionResult?.error("VPN_PERMISSION_REQUEST_REPLACED", "A VPN permission request is already pending", null)
        pendingVpnPermissionResult = result
        startActivityForResult(prepareIntent, vpnPermissionRequestCode)
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success("GRANTED")
            return
        }
        pendingNotificationResult?.error("NOTIFICATION_REQUEST_REPLACED", "A notification permission request is already pending", null)
        pendingNotificationResult = result
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), notificationRequestCode)
    }

    private fun startSpeedService(result: MethodChannel.Result) {
        try {
            val intent = Intent(this, InternetSpeedService::class.java).setAction(InternetSpeedService.ACTION_START)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent) else startService(intent)
            verifyServiceStart(
                isRunning = { InternetSpeedService.snapshot(this)["serviceRunning"] == true },
                errorCode = "SPEED_SERVICE_NOT_RUNNING",
                message = { InternetSpeedService.snapshot(this)["lastError"]?.toString()?.ifBlank { "لم تبدأ خدمة العداد" } ?: "لم تبدأ خدمة العداد" },
                result = result,
            )
        } catch (error: Exception) {
            result.error("SPEED_SERVICE_START_FAILED", error.message, null)
        }
    }

    private fun startLimitMonitor(result: MethodChannel.Result) {
        try {
            val intent = Intent(this, InternetLimitMonitorService::class.java).setAction(InternetLimitMonitorService.ACTION_START)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent) else startService(intent)
            verifyServiceStart(
                isRunning = { InternetLimitMonitorService.isRunning },
                errorCode = "LIMIT_MONITOR_NOT_RUNNING",
                message = { InternetLimitMonitorService.lastError ?: "لم تبدأ خدمة مراقبة الحدود" },
                result = result,
            )
        } catch (error: Exception) {
            result.error("LIMIT_MONITOR_START_FAILED", error.message, null)
        }
    }

    private fun startVpnService(packages: List<String>, automaticPackages: List<String> = emptyList(), backgroundPackages: List<String> = emptyList(), result: MethodChannel.Result) {
        try {
            val intent = Intent(this, InternetManagerVpnService::class.java)
                .setAction(InternetManagerVpnService.ACTION_START)
                .putStringArrayListExtra(InternetManagerVpnService.EXTRA_BLOCKED_PACKAGES, ArrayList(packages))
            if (automaticPackages.isNotEmpty()) {
                intent.putStringArrayListExtra(InternetManagerVpnService.EXTRA_AUTOMATIC_PACKAGES, ArrayList(automaticPackages))
            }
            if (backgroundPackages.isNotEmpty()) {
                intent.putStringArrayListExtra(InternetManagerVpnService.EXTRA_BACKGROUND_PACKAGES, ArrayList(backgroundPackages))
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent) else startService(intent)
            verifyServiceStart(
                isRunning = { InternetManagerVpnService.isActive },
                errorCode = "VPN_NOT_RUNNING",
                message = { InternetManagerVpnService.lastError ?: "لم يتم إنشاء واجهة VPN" },
                result = result,
            )
        } catch (error: Exception) {
            result.error("VPN_SERVICE_START_FAILED", error.message, null)
        }
    }

    private fun verifyServiceStart(
        isRunning: () -> Boolean,
        errorCode: String,
        message: () -> String,
        result: MethodChannel.Result,
        deadline: Long = System.currentTimeMillis() + SERVICE_VERIFY_TIMEOUT_MS,
    ) {
        if (isRunning()) {
            result.success("STARTED")
        } else if (System.currentTimeMillis() >= deadline) {
            result.error(errorCode, message(), null)
        } else {
            window.decorView.postDelayed({
                verifyServiceStart(isRunning, errorCode, message, result, deadline)
            }, SERVICE_VERIFY_INTERVAL_MS)
        }
    }

    private fun permissionStatus(): HashMap<String, Any> {
        val usageGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) hasUsageAccess() else true
        val notificationGranted = Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        val vpnPrepared = VpnService.prepare(this) == null
        val speedRunning = InternetSpeedService.snapshot(this)["serviceRunning"] == true
        return hashMapOf(
            "supported" to true,
            "usageAccessGranted" to usageGranted,
            "notificationsGranted" to notificationGranted,
            "vpnPrepared" to vpnPrepared,
            "vpnError" to (InternetManagerVpnService.lastError ?: ""),
            "networkStatsError" to (NetworkStatsReader.lastError ?: ""),
            "speedServiceRunning" to speedRunning,
            "speedServiceError" to (InternetSpeedService.snapshot(this)["lastError"] ?: ""),
            "limitMonitorRunning" to InternetLimitMonitorService.isRunning,
            "limitMonitorError" to (InternetLimitMonitorService.lastError ?: ""),
            "apiLevel" to Build.VERSION.SDK_INT,
        )
    }

    @RequiresApi(Build.VERSION_CODES.M)
    private fun hasUsageAccess(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        return appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName) == AppOpsManager.MODE_ALLOWED
    }

    private fun readInstalledApps(): ArrayList<HashMap<String, Any?>> {
        val packageManager = packageManager
        val launchable = packageManager.queryIntentActivities(
            Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER),
            PackageManager.MATCH_ALL,
        ).map { it.activityInfo.packageName }.toSet()
        val flags = PackageManager.GET_META_DATA or PackageManager.GET_PERMISSIONS
        val applications = packageManager.getInstalledApplications(flags)
        val result = ArrayList<HashMap<String, Any?>>(applications.size)
        for (info in applications) {
            if (info.packageName == packageName) continue
            val packageInfo = try {
                packageManager.getPackageInfo(info.packageName, PackageManager.GET_PERMISSIONS)
            } catch (_: Exception) {
                null
            }
            val requested = packageInfo?.requestedPermissions?.toList() ?: emptyList()
            val granted = requested.filter { permission ->
                packageManager.checkPermission(permission, info.packageName) == PackageManager.PERMISSION_GRANTED
            }
            val row = hashMapOf<String, Any?>(
                "name" to info.loadLabel(packageManager).toString(),
                "packageName" to info.packageName,
                "uid" to info.uid,
                "isSystemApp" to (info.flags and ApplicationInfo.FLAG_SYSTEM != 0),
                "isLaunchable" to launchable.contains(info.packageName),
                "requestedPermissions" to requested,
                "grantedPermissions" to granted,
                "iconBytes" to iconBytes(info),
            )
            result.add(row)
        }
        result.sortBy { (it["name"] as? String)?.lowercase() ?: "" }
        return result
    }

    private fun iconBytes(info: ApplicationInfo): ByteArray? {
        return try {
            val drawable = info.loadIcon(packageManager)
            val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 96
            val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 96
            val bitmap = android.graphics.Bitmap.createBitmap(width, height, android.graphics.Bitmap.Config.ARGB_8888)
            val canvas = android.graphics.Canvas(bitmap)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            ByteArrayOutputStream().use { output ->
                bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 85, output)
                bitmap.recycle()
                output.toByteArray()
            }
        } catch (_: Exception) {
            null
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != notificationRequestCode) return
        val result = pendingNotificationResult
        pendingNotificationResult = null
        val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        result?.success(if (granted) "GRANTED" else "DENIED")
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == vpnPermissionRequestCode) {
            val permissionResult = pendingVpnPermissionResult
            pendingVpnPermissionResult = null
            permissionResult?.success(if (resultCode == RESULT_OK) "GRANTED" else "DENIED")
            return
        }
        if (requestCode == vpnRequestCode) {
            val result = pendingVpnResult
            pendingVpnResult = null
            if (resultCode == RESULT_OK) {
                startVpnService(pendingVpnPackages, pendingVpnAutomaticPackages, pendingVpnBackgroundPackages, result ?: return)
                pendingVpnPackages = emptyList()
                pendingVpnAutomaticPackages = emptyList()
                pendingVpnBackgroundPackages = emptyList()
            } else {
                pendingVpnPackages = emptyList()
                pendingVpnAutomaticPackages = emptyList()
                pendingVpnBackgroundPackages = emptyList()
                result?.error("VPN_PERMISSION_DENIED", "VPN permission was denied", null)
            }
        }
    }

    override fun onDestroy() {
        worker.shutdownNow()
        pendingVpnResult?.error("ACTIVITY_DESTROYED", "The activity was destroyed", null)
        pendingNotificationResult?.error("ACTIVITY_DESTROYED", "The activity was destroyed", null)
        pendingVpnPermissionResult?.error("ACTIVITY_DESTROYED", "The activity was destroyed", null)
        pendingVpnResult = null
        pendingNotificationResult = null
        pendingVpnPermissionResult = null
        pendingVpnPackages = emptyList()
        pendingVpnAutomaticPackages = emptyList()
        super.onDestroy()
    }

    companion object {
        const val DEVICE_CHANNEL = "com.manus.internet_manager/device"
        const val VPN_CHANNEL = "com.manus.internet_manager/vpn"
        private const val DAY_MS = 24L * 60L * 60L * 1000L
        private const val SERVICE_VERIFY_TIMEOUT_MS = 4000L
        private const val SERVICE_VERIFY_INTERVAL_MS = 100L
    }
}
