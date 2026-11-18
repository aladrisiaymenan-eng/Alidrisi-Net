package com.example.internet_manager_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.os.IBinder
import android.os.Handler
import android.os.Looper
import androidx.core.app.NotificationCompat
import java.io.FileInputStream
import java.util.concurrent.ConcurrentHashMap

/**
 * Local selective blocker. Manual and automatic blocks are always blocked.
 * Background blocks are routed through the dropper only while their package
 * is not the current foreground package, based on UsageStats events.
 */
class InternetManagerVpnService : VpnService() {
    private var vpnInterface: android.os.ParcelFileDescriptor? = null
    private var packetThread: Thread? = null
    private val handler = Handler(Looper.getMainLooper())
    private val blockedPackages = ConcurrentHashMap.newKeySet<String>()
    private val manualBlockedPackages = ConcurrentHashMap.newKeySet<String>()
    private val automaticBlockedPackages = ConcurrentHashMap.newKeySet<String>()
    private val backgroundBlockedPackages = ConcurrentHashMap.newKeySet<String>()
    private var isRunning = false
    private var lastEffectivePackages: Set<String> = emptySet()
    private var currentForegroundPackage: String? = null

    private val foregroundTick = object : Runnable {
        override fun run() {
            if (!isRunning && blockedPackages.isEmpty()) return
            val changed = refreshForegroundPackage()
            val effective = effectiveBlockedPackages()
            if (changed || effective != lastEffectivePackages) {
                restartOrStop()
            }
            if (isRunning || backgroundBlockedPackages.isNotEmpty()) {
                handler.postDelayed(this, FOREGROUND_POLL_MS)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        lastError = null
        createNotificationChannel()
        manualBlockedPackages.addAll(loadPackageSet(KEY_MANUAL_BLOCKED))
        automaticBlockedPackages.addAll(loadPackageSet(KEY_AUTOMATIC_BLOCKED))
        backgroundBlockedPackages.addAll(loadPackageSet(KEY_BACKGROUND_BLOCKED))
        rebuildBlockedPackages()
        try {
            promoteToForeground()
            restartOrStop()
            handler.post(foregroundTick)
        } catch (error: Exception) {
            lastError = error.message ?: error.javaClass.simpleName
            closeInterface()
            instance = null
            stopSelf()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> stopSelf()
            ACTION_BLOCK_APP -> intent.getStringExtra(EXTRA_PACKAGE_NAME)?.let {
                manualBlockedPackages.add(it)
                persistPackageSets()
                rebuildBlockedPackages()
                restartOrStop()
            }
            ACTION_UNBLOCK_APP -> intent.getStringExtra(EXTRA_PACKAGE_NAME)?.let {
                manualBlockedPackages.remove(it)
                persistPackageSets()
                rebuildBlockedPackages()
                restartOrStop()
            }
            ACTION_UPDATE_AUTOMATIC_POLICIES -> {
                automaticBlockedPackages.clear()
                automaticBlockedPackages.addAll(intent.getStringArrayListExtra(EXTRA_AUTOMATIC_PACKAGES) ?: emptyList())
                persistPackageSets()
                rebuildBlockedPackages()
                restartOrStop()
            }
            ACTION_CLEAR_AUTOMATIC -> {
                automaticBlockedPackages.clear()
                persistPackageSets()
                rebuildBlockedPackages()
                restartOrStop()
            }
            ACTION_UPDATE_POLICIES -> {
                // A policy update is authoritative: replace only the lists supplied
                // by Flutter, while preserving optional lists when omitted.
                manualBlockedPackages.clear()
                manualBlockedPackages.addAll(intent.getStringArrayListExtra(EXTRA_BLOCKED_PACKAGES) ?: emptyList())
                if (intent.hasExtra(EXTRA_AUTOMATIC_PACKAGES)) {
                    automaticBlockedPackages.clear()
                    automaticBlockedPackages.addAll(intent.getStringArrayListExtra(EXTRA_AUTOMATIC_PACKAGES) ?: emptyList())
                }
                if (intent.hasExtra(EXTRA_BACKGROUND_PACKAGES)) {
                    backgroundBlockedPackages.clear()
                    backgroundBlockedPackages.addAll(intent.getStringArrayListExtra(EXTRA_BACKGROUND_PACKAGES) ?: emptyList())
                }
                persistPackageSets()
                rebuildBlockedPackages()
                restartOrStop()
            }
            ACTION_START -> {
                // Boot recovery sends ACTION_START without extras. Never erase
                // persisted policies in that case; an explicit start with lists
                // still replaces the lists exactly like the UI does.
                if (intent.hasExtra(EXTRA_BLOCKED_PACKAGES)) {
                    manualBlockedPackages.clear()
                    manualBlockedPackages.addAll(intent.getStringArrayListExtra(EXTRA_BLOCKED_PACKAGES) ?: emptyList())
                }
                if (intent.hasExtra(EXTRA_AUTOMATIC_PACKAGES)) {
                    automaticBlockedPackages.clear()
                    automaticBlockedPackages.addAll(intent.getStringArrayListExtra(EXTRA_AUTOMATIC_PACKAGES) ?: emptyList())
                }
                if (intent.hasExtra(EXTRA_BACKGROUND_PACKAGES)) {
                    backgroundBlockedPackages.clear()
                    backgroundBlockedPackages.addAll(intent.getStringArrayListExtra(EXTRA_BACKGROUND_PACKAGES) ?: emptyList())
                }
                persistPackageSets()
                rebuildBlockedPackages()
                restartOrStop()
            }
            else -> restartOrStop()
        }
        if (backgroundBlockedPackages.isNotEmpty()) {
            handler.removeCallbacks(foregroundTick)
            handler.post(foregroundTick)
        }
        return START_STICKY
    }

    private fun restartOrStop() {
        val effective = effectiveBlockedPackages()
        if (effective.isEmpty()) {
            lastEffectivePackages = emptySet()
            closeInterface()
            if (backgroundBlockedPackages.isEmpty()) {
                stopSelf()
            } else {
                updateNotification()
            }
        } else if (effective != lastEffectivePackages || vpnInterface == null) {
            restartVpn(effective)
        }
    }

    private fun effectiveBlockedPackages(): Set<String> {
        val effective = linkedSetOf<String>()
        effective.addAll(manualBlockedPackages)
        effective.addAll(automaticBlockedPackages)
        backgroundBlockedPackages.forEach { packageName ->
            if (packageName != currentForegroundPackage) effective.add(packageName)
        }
        return effective
    }

    private fun restartVpn(effective: Set<String>) {
        closeInterface()
        try {
            val builder = Builder()
                .setSession("الأدريسي — حظر التطبيقات")
                .addAddress("10.0.0.2", 32)
                .addRoute("0.0.0.0", 0)
                .addAddress("fd00:adri:1::2", 128)
                .addRoute("::", 0)
                .setBlocking(true)

            var added = 0
            for (packageName in effective) {
                try {
                    packageManager.getApplicationInfo(packageName, 0)
                    builder.addAllowedApplication(packageName)
                    added++
                } catch (_: PackageManager.NameNotFoundException) {
                    removePackageFromAllSets(packageName)
                } catch (_: Exception) {
                    removePackageFromAllSets(packageName)
                }
            }
            persistPackageSets()
            if (added == 0) {
                lastEffectivePackages = emptySet()
                stopSelf()
                return
            }

            vpnInterface = builder.establish()
            isRunning = vpnInterface != null
            isActive = isRunning
            lastEffectivePackages = effective.toSet()
            updateNotification()
            if (!isRunning) return

            packetThread = Thread {
                val descriptor = vpnInterface ?: return@Thread
                try {
                    FileInputStream(descriptor.fileDescriptor).use { stream ->
                        val buffer = ByteArray(32767)
                        while (isRunning) {
                            val length = stream.read(buffer)
                            if (length < 0) break
                            // Deliberately drop all packets routed into this blocker TUN.
                        }
                    }
                } catch (_: Exception) {
                    // Closing the descriptor or revocation ends the read loop.
                }
            }.also { it.name = "InternetManagerVpnPacketDropper"; it.start() }
        } catch (error: SecurityException) {
            lastError = error.message ?: "VPN permission/security error"
            isRunning = false
            isActive = false
            stopSelf()
        } catch (error: Exception) {
            lastError = error.message ?: error.javaClass.simpleName
            isRunning = false
            isActive = false
            stopSelf()
        }
    }

    private fun refreshForegroundPackage(): Boolean {
        val usageManager = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return false
        val now = System.currentTimeMillis()
        val events = try {
            usageManager.queryEvents(now - USAGE_EVENT_LOOKBACK_MS, now)
        } catch (_: SecurityException) {
            return false
        } catch (_: Exception) {
            return false
        }
        val event = UsageEvents.Event()
        var latest = currentForegroundPackage
        var changed = false
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val packageName = event.packageName ?: continue
            val isForeground = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                event.eventType == UsageEvents.Event.ACTIVITY_RESUMED
            } else {
                event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND
            }
            val isBackground = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                event.eventType == UsageEvents.Event.ACTIVITY_PAUSED ||
                    event.eventType == UsageEvents.Event.ACTIVITY_STOPPED
            } else {
                event.eventType == UsageEvents.Event.MOVE_TO_BACKGROUND
            }
            if (isForeground) latest = packageName
            if (isBackground && latest == packageName) latest = null
        }
        if (latest != currentForegroundPackage) {
            currentForegroundPackage = latest
            changed = true
        }
        return changed
    }

    private fun rebuildBlockedPackages() {
        blockedPackages.clear()
        blockedPackages.addAll(manualBlockedPackages)
        blockedPackages.addAll(automaticBlockedPackages)
        blockedPackages.addAll(backgroundBlockedPackages)
    }

    private fun removePackageFromAllSets(packageName: String) {
        manualBlockedPackages.remove(packageName)
        automaticBlockedPackages.remove(packageName)
        backgroundBlockedPackages.remove(packageName)
        rebuildBlockedPackages()
    }

    private fun closeInterface() {
        isRunning = false
        isActive = false
        try { vpnInterface?.close() } catch (_: Exception) { }
        vpnInterface = null
        packetThread?.interrupt()
        packetThread = null
    }

    private fun promoteToForeground() {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun buildNotification(): Notification = NotificationCompat.Builder(this, CHANNEL_ID)
        .setSmallIcon(android.R.drawable.ic_lock_lock)
        .setContentTitle("الأدريسي — حظر التطبيقات")
        .setContentText("حظر فعّال لـ ${lastEffectivePackages.size} تطبيق")
        .setSubText("يشمل الحجب اليدوي والتلقائي وحجب الخلفية")
        .setOngoing(true)
        .setOnlyAlertOnce(true)
        .setCategory(NotificationCompat.CATEGORY_SERVICE)
        .setPriority(NotificationCompat.PRIORITY_LOW)
        .build()

    private fun updateNotification() {
        getSystemService(NotificationManager::class.java)?.notify(NOTIFICATION_ID, buildNotification())
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "حظر التطبيقات", NotificationManager.IMPORTANCE_LOW).apply {
                description = "إشعار دائم عند تشغيل حظر التطبيقات"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)
        }
    }

    private fun loadPackageSet(key: String): Set<String> =
        getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .getStringSet(key, emptySet())?.toSet() ?: emptySet()

    private fun persistPackageSets() {
        getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).edit()
            .putStringSet(KEY_MANUAL_BLOCKED, manualBlockedPackages.toSet())
            .putStringSet(KEY_AUTOMATIC_BLOCKED, automaticBlockedPackages.toSet())
            .putStringSet(KEY_BACKGROUND_BLOCKED, backgroundBlockedPackages.toSet())
            .apply()
    }

    override fun onRevoke() {
        closeInterface()
        stopSelf()
        super.onRevoke()
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        closeInterface()
        getSystemService(NotificationManager::class.java)?.cancel(NOTIFICATION_ID)
        if (instance === this) instance = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        const val ACTION_START = "com.manus.internet_manager.VPN_START"
        const val ACTION_STOP = "com.manus.internet_manager.VPN_STOP"
        const val ACTION_UPDATE_POLICIES = "com.manus.internet_manager.VPN_UPDATE_POLICIES"
        const val ACTION_UPDATE_AUTOMATIC_POLICIES = "com.manus.internet_manager.VPN_UPDATE_AUTOMATIC_POLICIES"
        const val ACTION_CLEAR_AUTOMATIC = "com.manus.internet_manager.VPN_CLEAR_AUTOMATIC"
        const val ACTION_BLOCK_APP = "com.manus.internet_manager.VPN_BLOCK_APP"
        const val ACTION_UNBLOCK_APP = "com.manus.internet_manager.VPN_UNBLOCK_APP"
        const val EXTRA_BLOCKED_PACKAGES = "blockedPackages"
        const val EXTRA_AUTOMATIC_PACKAGES = "automaticBlockedPackages"
        const val EXTRA_BACKGROUND_PACKAGES = "backgroundBlockedPackages"
        const val EXTRA_PACKAGE_NAME = "packageName"
        const val CHANNEL_ID = "internet_vpn"
        const val NOTIFICATION_ID = 3102
        private const val FOREGROUND_POLL_MS = 2000L
        private const val USAGE_EVENT_LOOKBACK_MS = 60_000L
        private const val PREFERENCES = "internet_manager_native"
        private const val KEY_MANUAL_BLOCKED = "manual_blocked_packages"
        private const val KEY_AUTOMATIC_BLOCKED = "automatic_blocked_packages"
        private const val KEY_BACKGROUND_BLOCKED = "background_blocked_packages"
        @Volatile var instance: InternetManagerVpnService? = null
        @Volatile var isActive: Boolean = false
        @Volatile var lastError: String? = null

        fun hasSavedPolicies(context: Context): Boolean {
            val prefs = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            return listOf(KEY_MANUAL_BLOCKED, KEY_AUTOMATIC_BLOCKED, KEY_BACKGROUND_BLOCKED)
                .any { !prefs.getStringSet(it, emptySet()).isNullOrEmpty() }
        }
    }
}
