package com.example.internet_manager_app

import android.app.AppOpsManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.VpnService
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import org.json.JSONArray
import org.json.JSONObject

/**
 * Periodically evaluates saved per-app limits against real NetworkStats data.
 * Android does not offer a guaranteed per-second quota callback, so this service
 * applies the policy at a conservative interval while it is allowed to run.
 */
class InternetLimitMonitorService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    private val checking = AtomicBoolean(false)
    private var running = false
    private var lastAppliedPackages: Set<String> = emptySet()
    private var lastBlockedByLimit: Set<String> = emptySet()
    private var lastError: String? = null

    private val tick = object : Runnable {
        override fun run() {
            if (!running) return
            checkInBackground()
            handler.postDelayed(this, CHECK_INTERVAL_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        InternetLimitMonitorService.lastError = null
        createNotificationChannel()
        running = true
        isRunning = true
        try {
            startForegroundCompat(buildNotification("جارٍ تجهيز مراقبة الحدود"))
        } catch (error: Exception) {
            lastError = error.message ?: error.javaClass.simpleName
            InternetLimitMonitorService.lastError = lastError
            running = false
            isRunning = false
            instance = null
            stopSelf()
            return
        }
        handler.post(tick)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        if (!running) {
            running = true
            isRunning = true
            handler.post(tick)
        }
        return START_STICKY
    }

    private fun checkInBackground() {
        if (!checking.compareAndSet(false, true)) return
        executor.execute {
            try {
                val result = evaluateLimits()
                handler.post {
                    if (!running) return@post
                    if (result.error != null) {
                        publishNotification(result.error)
                    } else {
                        val newlyBlocked = result.autoBlocked - lastBlockedByLimit
                        applyAutomaticVpnPolicy(result.autoBlocked)
                        if (newlyBlocked.isNotEmpty() && smartNotificationsEnabled()) {
                            publishLimitAlert(newlyBlocked.size)
                        }
                        lastBlockedByLimit = result.autoBlocked
                        publishNotification(
                            if (result.autoBlocked.isEmpty()) {
                                "لا يوجد تطبيق تجاوز حده — فحص دوري كل ${CHECK_INTERVAL_MS / 1000} ثانية"
                            } else {
                                "تم حجب ${result.autoBlocked.size} تطبيق بعد تجاوز الحد"
                            },
                        )
                    }
                }
            } catch (error: Exception) {
                handler.post { if (running) publishNotification("تعذر فحص الحدود: ${error.message ?: "خطأ غير معروف"}") }
            } finally {
                checking.set(false)
            }
        }
    }

    private fun evaluateLimits(): Evaluation {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !hasUsageAccess()) {
            return Evaluation(emptySet(), "فعّل إذن الوصول إلى بيانات الاستخدام لتطبيق الحدود")
        }

        val prefs = getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        val policies = readPolicies(prefs.getString(KEY_POLICIES, null))
        val limitRuleEnabled = readLimitRuleEnabled(prefs.getString(KEY_RULES, null))
        val end = System.currentTimeMillis()
        val todayStart = startOfDay(end)
        val todayBaseline = readTodayBaseline(prefs, end)
        val usageByUid = NetworkStatsReader(this)
            .readPerUid(todayStart, end)
            .associateBy { asInt(it["uid"]) }
        val manualBlocked = policies.filterValues { it.mode == "blocked" && !it.autoBlocked }.keys
        val autoBlocked = mutableSetOf<String>()
        if (limitRuleEnabled) {
            for ((packageName, policy) in policies) {
                if (!policy.enabled || policy.limitBytes <= 0) continue
                try {
                    val uid = packageManager.getApplicationInfo(packageName, 0).uid
                    val rawUsage = asLong(usageByUid[uid]?.get("totalBytes"))
                    val usage = (rawUsage - baselineForPackage(todayBaseline, packageName))
                        .coerceAtLeast(0L)
                    if (usage >= policy.limitBytes) autoBlocked.add(packageName)
                } catch (_: PackageManager.NameNotFoundException) {
                    // A stale policy is ignored until the Flutter layer refreshes it.
                } catch (_: Exception) {
                    // A single package must not stop monitoring all other limits.
                }
            }
        }
        // Keep the set conservative: manual blocks are always preserved, while
        // auto blocks are removed on the next pass if the usage/limit no longer matches.
        val visibleAuto = autoBlocked - manualBlocked
        return Evaluation(visibleAuto, null)
    }

    private fun applyAutomaticVpnPolicy(automaticPackages: Set<String>) {
        if (automaticPackages == lastAppliedPackages && (automaticPackages.isEmpty() || InternetManagerVpnService.isActive)) return
        if (automaticPackages.isNotEmpty() && VpnService.prepare(this) != null) {
            lastAppliedPackages = emptySet()
            publishNotification("افتح التطبيق ووافق على VPN لتطبيق حد الاستهلاك تلقائيًا")
            return
        }
        lastAppliedPackages = automaticPackages
        val intent = Intent(this, InternetManagerVpnService::class.java)
            .setAction(InternetManagerVpnService.ACTION_UPDATE_AUTOMATIC_POLICIES)
            .putStringArrayListExtra(InternetManagerVpnService.EXTRA_AUTOMATIC_PACKAGES, ArrayList(automaticPackages))
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent) else startService(intent)
        } catch (_: Exception) {
            // The next check will retry. VPN permission and another active VPN
            // are controlled by the system and cannot be silently overridden.
        }
    }

    private fun startOfDay(timestamp: Long): Long {
        val calendar = java.util.Calendar.getInstance().apply { timeInMillis = timestamp }
        calendar.set(java.util.Calendar.HOUR_OF_DAY, 0)
        calendar.set(java.util.Calendar.MINUTE, 0)
        calendar.set(java.util.Calendar.SECOND, 0)
        calendar.set(java.util.Calendar.MILLISECOND, 0)
        return calendar.timeInMillis
    }

    private fun readTodayBaseline(
        prefs: android.content.SharedPreferences,
        now: Long,
    ): JSONObject? {
        val raw = prefs.all[KEY_TODAY_RESET] ?: return null
        val resetAt = when (raw) {
            is Number -> raw.toLong()
            is String -> raw.toLongOrNull()
            else -> null
        } ?: return null
        if (!sameDay(resetAt, now)) return null
        return try {
            prefs.getString(KEY_TODAY_BASELINE, null)?.let { JSONObject(it) }
        } catch (_: Exception) {
            null
        }
    }

    private fun baselineForPackage(baseline: JSONObject?, packageName: String): Long {
        if (baseline == null) return 0L
        val appUsage = baseline.optJSONObject("appUsage") ?: return 0L
        if (appUsage.has(packageName)) return appUsage.optLong(packageName, 0L).coerceAtLeast(0L)
        val keys = appUsage.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            val packages = key.split(" + ")
            if (packages.firstOrNull() == packageName) {
                return appUsage.optLong(key, 0L).coerceAtLeast(0L)
            }
        }
        return 0L
    }

    private fun sameDay(firstMillis: Long, secondMillis: Long): Boolean {
        val first = java.util.Calendar.getInstance().apply { timeInMillis = firstMillis }
        val second = java.util.Calendar.getInstance().apply { timeInMillis = secondMillis }
        return first.get(java.util.Calendar.YEAR) == second.get(java.util.Calendar.YEAR) &&
            first.get(java.util.Calendar.DAY_OF_YEAR) == second.get(java.util.Calendar.DAY_OF_YEAR)
    }

    private fun readPolicies(encoded: String?): Map<String, Policy> {
        if (encoded.isNullOrBlank()) return emptyMap()
        return try {
            val root = JSONObject(encoded)
            val result = mutableMapOf<String, Policy>()
            val keys = root.keys()
            while (keys.hasNext()) {
                val packageName = keys.next()
                val value = root.optJSONObject(packageName) ?: continue
                result[packageName] = Policy(
                    limitBytes = value.optLong("limitBytes", 0L).coerceAtLeast(0L),
                    enabled = value.optBoolean("isRuleEnabled", true),
                    mode = value.optString("accessMode", "allowed"),
                    autoBlocked = value.optBoolean("autoBlocked", false),
                )
            }
            result
        } catch (_: Exception) {
            emptyMap()
        }
    }

    private fun readLimitRuleEnabled(encoded: String?): Boolean {
        if (encoded.isNullOrBlank()) return true
        return try {
            val rows = JSONArray(encoded)
            for (index in 0 until rows.length()) {
                val row = rows.optJSONObject(index) ?: continue
                if (row.optString("id") == "limit") return row.optBoolean("enabled", true)
            }
            true
        } catch (_: Exception) {
            true
        }
    }

    private fun hasUsageAccess(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager ?: return false
        return appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName) == AppOpsManager.MODE_ALLOWED
    }

    private fun publishNotification(text: String) {
        getSystemService(NotificationManager::class.java)?.notify(NOTIFICATION_ID, buildNotification(text))
    }

    private fun publishLimitAlert(count: Int) {
        val notification = NotificationCompat.Builder(this, ALERT_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("الأدريسي — تجاوز حد الاستهلاك")
            .setContentText("تم حجب $count تطبيق تلقائيًا بعد تجاوز الحصة المحددة")
            .setAutoCancel(true)
            .setTimeoutAfter(10_000L)
            .setCategory(NotificationCompat.CATEGORY_EVENT)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()
        getSystemService(NotificationManager::class.java)?.notify(ALERT_NOTIFICATION_ID, notification)
    }

    private fun smartNotificationsEnabled(): Boolean = getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE).getBoolean(KEY_NOTIFICATIONS, true)

    private fun buildNotification(text: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_manage)
            .setContentTitle("الأدريسي — مراقبة حدود التطبيقات")
            .setContentText(text)
            .setSubText("يُراجع الاستهلاك الحقيقي من Android")
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun startForegroundCompat(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "مراقبة حدود التطبيقات", NotificationManager.IMPORTANCE_LOW).apply {
                description = "تطبيق حدود الاستهلاك على التطبيقات التي تجاوزت حصتها"
                setShowBadge(false)
            }
            val alertChannel = NotificationChannel(ALERT_CHANNEL_ID, "تنبيهات حدود التطبيقات", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "تنبيه عند حجب تطبيق بسبب تجاوز حد الاستهلاك"
            }
            getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)
            getSystemService(NotificationManager::class.java)?.createNotificationChannel(alertChannel)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        running = false
        isRunning = false
        handler.removeCallbacksAndMessages(null)
        executor.shutdownNow()
        getSystemService(NotificationManager::class.java)?.cancel(NOTIFICATION_ID)
        getSystemService(NotificationManager::class.java)?.cancel(ALERT_NOTIFICATION_ID)
        if (instance === this) instance = null
        super.onDestroy()
    }

    private data class Policy(val limitBytes: Long, val enabled: Boolean, val mode: String, val autoBlocked: Boolean)
    private data class Evaluation(val autoBlocked: Set<String>, val error: String?)

    companion object {
        const val ACTION_START = "com.manus.internet_manager.LIMIT_MONITOR_START"
        const val ACTION_STOP = "com.manus.internet_manager.LIMIT_MONITOR_STOP"
        const val CHANNEL_ID = "internet_limit_monitor"
        const val ALERT_CHANNEL_ID = "internet_limit_alerts"
        const val NOTIFICATION_ID = 3103
        const val ALERT_NOTIFICATION_ID = 3104
        private const val CHECK_INTERVAL_MS = 15_000L
        private const val FLUTTER_PREFS = "FlutterSharedPreferences"
        private const val KEY_POLICIES = "flutter.app_policies"
        private const val KEY_RULES = "flutter.rules"
        private const val KEY_NOTIFICATIONS = "flutter.notifications"
        private const val KEY_TODAY_RESET = "flutter.today_reset_millis"
        private const val KEY_TODAY_BASELINE = "flutter.today_reset_baseline"
        @Volatile var instance: InternetLimitMonitorService? = null
        @Volatile var isRunning: Boolean = false
        @Volatile var lastError: String? = null

        private fun asLong(value: Any?): Long = when (value) {
            is Number -> value.toLong()
            else -> value?.toString()?.toLongOrNull() ?: 0L
        }

        private fun asInt(value: Any?): Int = asLong(value).toInt()
    }
}
