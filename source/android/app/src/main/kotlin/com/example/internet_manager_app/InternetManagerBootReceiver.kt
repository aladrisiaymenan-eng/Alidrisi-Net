package com.example.internet_manager_app

import android.Manifest
import android.app.AppOpsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build

class InternetManagerBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED && intent?.action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        // Do not abort VPN recovery when notifications are disabled; each
        // foreground service handles its own permission result.

        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        if (prefs.getBoolean("flutter.speed_service_enabled", false)) {
            val speedIntent = Intent(context, InternetSpeedService::class.java).setAction(InternetSpeedService.ACTION_START)
            startServiceSafely(context, speedIntent)
        }
        if (prefs.getBoolean("flutter.limit_monitor_enabled", false) && hasUsageAccess(context)) {
            val limitIntent = Intent(context, InternetLimitMonitorService::class.java).setAction(InternetLimitMonitorService.ACTION_START)
            startServiceSafely(context, limitIntent)
        }
        // VPN policies live in a separate native preference store. Restore them
        // after reboot/package replacement without requiring Flutter to open.
        if (VpnService.prepare(context) == null && InternetManagerVpnService.hasSavedPolicies(context)) {
            val vpnIntent = Intent(context, InternetManagerVpnService::class.java)
                .setAction(InternetManagerVpnService.ACTION_START)
            startServiceSafely(context, vpnIntent)
        }
    }

    private fun hasUsageAccess(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager ?: return false
        return appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), context.packageName) == AppOpsManager.MODE_ALLOWED
    }

    private fun startServiceSafely(context: Context, intent: Intent) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startForegroundService(intent) else context.startService(intent)
        } catch (_: Exception) {
            // Android may reject background service starts on a specific vendor/build.
        }
    }
}
