package com.example.internet_manager_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.TrafficStats
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.content.pm.ServiceInfo
import androidx.core.app.NotificationCompat
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import org.json.JSONObject

class InternetSpeedService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private val usageExecutor = Executors.newSingleThreadExecutor()
    private val usageRefreshing = AtomicBoolean(false)
    private var previousRx = TrafficStats.getTotalRxBytes()
    private var previousTx = TrafficStats.getTotalTxBytes()
    private var previousAt = System.currentTimeMillis()
    private var running = false
    private var lastError: String? = null
    private var dailyWifiBytes = 0L
    private var dailyMobileBytes = 0L
    private var lastDailyUsageAt = 0L

    private val sampler = object : Runnable {
        override fun run() {
            sample()
            if (running) handler.postDelayed(this, SAMPLE_INTERVAL_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        running = true
        try {
            startForegroundCompat(buildNotification(0.0, 0.0))
        } catch (error: Exception) {
            lastError = error.message ?: error.javaClass.simpleName
            running = false
            latest = hashMapOf("supported" to true, "trafficSupported" to false, "serviceRunning" to false, "downloadKbps" to 0.0, "uploadKbps" to 0.0, "networkType" to networkType(this), "vpnActive" to InternetManagerVpnService.isActive, "lastError" to lastError!!)
            stopSelf()
            return
        }
        handler.post(sampler)
        instance = this
        isRunning = true
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        if (!running) {
            running = true
            handler.post(sampler)
        }
        return START_STICKY
    }

    private fun sample() {
        val now = System.currentTimeMillis()
        val rx = TrafficStats.getTotalRxBytes()
        val tx = TrafficStats.getTotalTxBytes()
        val seconds = ((now - previousAt).coerceAtLeast(1L)).toDouble() / 1000.0
        val trafficSupported = rx >= 0L && tx >= 0L && previousRx >= 0L && previousTx >= 0L
        val downloadKbps = if (trafficSupported) ((rx - previousRx).coerceAtLeast(0L) / 1024.0) / seconds else 0.0
        val uploadKbps = if (trafficSupported) ((tx - previousTx).coerceAtLeast(0L) / 1024.0) / seconds else 0.0
        if (!trafficSupported) lastError = "عدادات حركة الشبكة غير مدعومة على هذا الجهاز"
        refreshTodayUsage(now)
        previousRx = rx
        previousTx = tx
        previousAt = now
        latest = hashMapOf(
            "supported" to true,
            "trafficSupported" to trafficSupported,
            "serviceRunning" to running,
            "downloadKbps" to downloadKbps,
            "uploadKbps" to uploadKbps,
            "networkType" to networkType(this),
            "sampledAt" to now,
            "vpnActive" to InternetManagerVpnService.isActive,
            "dailyWifiBytes" to dailyWifiBytes,
            "dailyMobileBytes" to dailyMobileBytes,
            "dailyTotalBytes" to (dailyWifiBytes + dailyMobileBytes),
            "lastError" to (lastError ?: ""),
        )
        val manager = getSystemService(NotificationManager::class.java)
        manager?.notify(NOTIFICATION_ID, buildNotification(downloadKbps, uploadKbps))
    }

    private fun startForegroundCompat(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun buildNotification(downloadKbps: Double, uploadKbps: Double): Notification {
        val openIntent = PendingIntent.getActivity(
            this,
            1001,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or pendingIntentImmutableFlag(),
        )
        val stopIntent = PendingIntent.getService(
            this,
            1002,
            Intent(this, InternetSpeedService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or pendingIntentImmutableFlag(),
        )
        val network = networkType(this)
        val todayTotal = bytesText(dailyWifiBytes + dailyMobileBytes)
        val compactLine = "تنزيل  ${rateText(downloadKbps)}   •   رفع  ${rateText(uploadKbps)}"
        val usageLine = "اليوم  $todayTotal   •   Wi‑Fi ${bytesText(dailyWifiBytes)}   •   الجوال ${bytesText(dailyMobileBytes)}"
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle("الأدريسي | Internet Manager")
            .setContentText(compactLine)
            .setStyle(NotificationCompat.BigTextStyle().setBigContentTitle("عداد السرعة • $network").bigText(
                "$compactLine\n$usageLine"
            ))
            .setSubText("مراقبة حقيقية لحركة الجهاز • $network")
            .setContentIntent(openIntent)
            .addAction(android.R.drawable.ic_media_pause, "إيقاف", stopIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun rateText(kbps: Double): String = if (kbps < 1024) "${kbps.toInt()} KB/s" else "${"%.2f".format(java.util.Locale.US, kbps / 1024)} MB/s"

    private fun bytesText(bytes: Long): String = when {
        bytes < 1024L -> "$bytes B"
        bytes < 1024L * 1024L -> "${"%.1f".format(java.util.Locale.US, bytes / 1024.0)} KB"
        bytes < 1024L * 1024L * 1024L -> "${"%.1f".format(java.util.Locale.US, bytes / (1024.0 * 1024.0))} MB"
        else -> "${"%.2f".format(java.util.Locale.US, bytes / (1024.0 * 1024.0 * 1024.0))} GB"
    }

    private fun refreshTodayUsage(now: Long) {
        if (now - lastDailyUsageAt < DAILY_USAGE_REFRESH_MS ||
            !usageRefreshing.compareAndSet(false, true)
        ) return
        lastDailyUsageAt = now
        usageExecutor.execute {
            var wifi = 0L
            var mobile = 0L
            try {
                val calendar = java.util.Calendar.getInstance().apply {
                    timeInMillis = now
                    set(java.util.Calendar.HOUR_OF_DAY, 0)
                    set(java.util.Calendar.MINUTE, 0)
                    set(java.util.Calendar.SECOND, 0)
                    set(java.util.Calendar.MILLISECOND, 0)
                }
                val todayStart = calendar.timeInMillis
                val prefs = getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
                val savedUsageStart = (prefs.all[KEY_USAGE_START] as? Number)?.toLong()
                val queryStart = if (savedUsageStart != null &&
                    savedUsageStart in todayStart..now
                ) savedUsageStart else todayStart
                val rows = NetworkStatsReader(this).readPerUid(queryStart, now)
                wifi = rows.sumOf { (it["wifiBytes"] as? Number)?.toLong()?.coerceAtLeast(0L) ?: 0L }
                mobile = rows.sumOf { (it["mobileBytes"] as? Number)?.toLong()?.coerceAtLeast(0L) ?: 0L }
                val resetAt = (prefs.all[KEY_TODAY_RESET] as? Number)?.toLong()
                if (resetAt != null && sameDay(resetAt, now)) {
                    val baseline = prefs.getString(KEY_TODAY_BASELINE, null)
                        ?.let { JSONObject(it) }
                    wifi = (wifi - (baseline?.optLong("wifiBytes", 0L) ?: 0L))
                        .coerceAtLeast(0L)
                    mobile = (mobile - (baseline?.optLong("mobileBytes", 0L) ?: 0L))
                        .coerceAtLeast(0L)
                }
            } catch (_: Exception) {
                // The Flutter side exposes NetworkStats diagnostics separately.
            }
            handler.post {
                dailyWifiBytes = wifi
                dailyMobileBytes = mobile
                usageRefreshing.set(false)
                latest["dailyWifiBytes"] = dailyWifiBytes
                latest["dailyMobileBytes"] = dailyMobileBytes
                latest["dailyTotalBytes"] = dailyWifiBytes + dailyMobileBytes
                if (running) {
                    getSystemService(NotificationManager::class.java)?.notify(
                        NOTIFICATION_ID,
                        buildNotification(
                            (latest["downloadKbps"] as? Number)?.toDouble() ?: 0.0,
                            (latest["uploadKbps"] as? Number)?.toDouble() ?: 0.0,
                        ),
                    )
                }
            }
        }
    }

    private fun sameDay(firstMillis: Long, secondMillis: Long): Boolean {
        val first = java.util.Calendar.getInstance().apply { timeInMillis = firstMillis }
        val second = java.util.Calendar.getInstance().apply { timeInMillis = secondMillis }
        return first.get(java.util.Calendar.YEAR) == second.get(java.util.Calendar.YEAR) &&
            first.get(java.util.Calendar.DAY_OF_YEAR) == second.get(java.util.Calendar.DAY_OF_YEAR)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "عداد سرعة الإنترنت", NotificationManager.IMPORTANCE_LOW).apply {
                description = "يعرض سرعة التنزيل والرفع الحقيقية في شريط الإشعارات"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)
        }
    }

    private fun pendingIntentImmutableFlag(): Int = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        running = false
        isRunning = false
        handler.removeCallbacksAndMessages(null)
        usageExecutor.shutdownNow()
        latest = hashMapOf("supported" to true, "trafficSupported" to false, "serviceRunning" to false, "downloadKbps" to 0.0, "uploadKbps" to 0.0, "networkType" to networkType(this), "vpnActive" to InternetManagerVpnService.isActive, "dailyWifiBytes" to dailyWifiBytes, "dailyMobileBytes" to dailyMobileBytes, "dailyTotalBytes" to (dailyWifiBytes + dailyMobileBytes), "lastError" to (lastError ?: ""))
        if (instance === this) instance = null
        super.onDestroy()
    }

    companion object {
        const val ACTION_START = "com.manus.internet_manager.SPEED_START"
        const val ACTION_STOP = "com.manus.internet_manager.SPEED_STOP"
        const val CHANNEL_ID = "internet_speed"
        const val NOTIFICATION_ID = 3101
        private const val FLUTTER_PREFS = "FlutterSharedPreferences"
        private const val KEY_USAGE_START = "flutter.usage_start_millis"
        private const val KEY_TODAY_RESET = "flutter.today_reset_millis"
        private const val KEY_TODAY_BASELINE = "flutter.today_reset_baseline"
        private const val SAMPLE_INTERVAL_MS = 1000L
        private const val DAILY_USAGE_REFRESH_MS = 2000L
        @Volatile private var instance: InternetSpeedService? = null
        @Volatile var isRunning: Boolean = false
        @Volatile private var latest: HashMap<String, Any> = hashMapOf("supported" to true, "trafficSupported" to true, "serviceRunning" to false, "downloadKbps" to 0.0, "uploadKbps" to 0.0, "networkType" to "غير متصل", "vpnActive" to false, "dailyWifiBytes" to 0L, "dailyMobileBytes" to 0L, "dailyTotalBytes" to 0L, "lastError" to "")

        fun snapshot(context: Context): HashMap<String, Any> {
            val current = HashMap(latest)
            current["serviceRunning"] = isRunning
            current["networkType"] = networkType(context)
            current["vpnActive"] = InternetManagerVpnService.isActive
            current["lastError"] = instance?.lastError ?: current["lastError"] ?: ""
            return current
        }

        private fun networkType(context: Context): String {
            val connectivity = context.getSystemService(ConnectivityManager::class.java) ?: return "غير متصل"
            val network = connectivity.activeNetwork ?: return "غير متصل"
            val capabilities = connectivity.getNetworkCapabilities(network) ?: return "غير متصل"
            return when {
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "Wi‑Fi"
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "بيانات الجوال"
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "Ethernet"
                else -> "متصل"
            }
        }
    }
}
