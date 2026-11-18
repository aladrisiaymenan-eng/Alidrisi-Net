package com.example.internet_manager_app

import android.app.usage.NetworkStats
import android.app.usage.NetworkStatsManager
import android.content.Context
import android.net.ConnectivityManager
import android.os.Build
import android.util.Log

/** Reads real device traffic counters exposed by Android's NetworkStatsManager. */
class NetworkStatsReader(private val context: Context) {
    private val manager: NetworkStatsManager? = context.getSystemService(NetworkStatsManager::class.java)

    /**
     * Returns one row per UID. The Flutter side deliberately joins these rows to
     * PackageManager applications by uid; a UID is the stable native key here.
     */
    fun readPerUid(startMillis: Long, endMillis: Long): ArrayList<HashMap<String, Any>> {
        lastError = null
        val byUid = mutableMapOf<Int, Usage>()
        collectSummary(ConnectivityManager.TYPE_WIFI, startMillis, endMillis, byUid) { usage, bucket ->
            usage.wifiBytes += bucket.rxBytes.coerceAtLeast(0L) + bucket.txBytes.coerceAtLeast(0L)
        }
        collectSummary(ConnectivityManager.TYPE_MOBILE, startMillis, endMillis, byUid) { usage, bucket ->
            usage.mobileBytes += bucket.rxBytes.coerceAtLeast(0L) + bucket.txBytes.coerceAtLeast(0L)
        }
        return ArrayList(byUid.map { (uid, usage) ->
            hashMapOf(
                "uid" to uid,
                "totalBytes" to usage.totalBytes,
                "wifiBytes" to usage.wifiBytes,
                "mobileBytes" to usage.mobileBytes,
            )
        })
    }

    fun readDaily(startMillis: Long, endMillis: Long): ArrayList<HashMap<String, Any>> {
        lastError = null
        val byDay = sortedMapOf<Long, Usage>()
        val byDayUid = sortedMapOf<Long, MutableMap<Int, Usage>>()
        collectHistory(
            ConnectivityManager.TYPE_WIFI,
            startMillis,
            endMillis,
            byDay,
            byDayUid,
        ) { usage, bucket ->
            usage.wifiBytes += bucket.rxBytes.coerceAtLeast(0L) + bucket.txBytes.coerceAtLeast(0L)
        }
        collectHistory(
            ConnectivityManager.TYPE_MOBILE,
            startMillis,
            endMillis,
            byDay,
            byDayUid,
        ) { usage, bucket ->
            usage.mobileBytes += bucket.rxBytes.coerceAtLeast(0L) + bucket.txBytes.coerceAtLeast(0L)
        }
        return ArrayList(byDay.map { (dayStart, usage) ->
            val uidRows = ArrayList<HashMap<String, Any>>()
            byDayUid[dayStart].orEmpty().forEach { (uid, uidUsage) ->
                uidRows.add(hashMapOf(
                    "uid" to uid,
                    "totalBytes" to uidUsage.totalBytes,
                    "wifiBytes" to uidUsage.wifiBytes,
                    "mobileBytes" to uidUsage.mobileBytes,
                ))
            }
            hashMapOf(
                "dayStartMillis" to dayStart,
                "mobileBytes" to usage.mobileBytes,
                "wifiBytes" to usage.wifiBytes,
                "uidUsage" to uidRows,
            )
        })
    }

    private fun collectSummary(
        networkType: Int,
        startMillis: Long,
        endMillis: Long,
        destination: MutableMap<Int, Usage>,
        consumer: (Usage, NetworkStats.Bucket) -> Unit,
    ) {
        if (manager == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        var stats: NetworkStats? = null
        try {
            // querySummary can return UID_ALL (-1) on Android. Details is the
            // official per-UID query needed by application counters and limits.
            stats = manager.queryDetails(networkType, null, startMillis, endMillis)
            val bucket = NetworkStats.Bucket()
            while (stats.hasNextBucket()) {
                stats.getNextBucket(bucket)
                if (bucket.uid < 0) continue
                val usage = destination.getOrPut(bucket.uid) { Usage() }
                consumer(usage, bucket)
            }
        } catch (error: SecurityException) {
            recordError("NetworkStats summary permission denied: ${error.message ?: "PACKAGE_USAGE_STATS"}")
        } catch (error: Exception) {
            recordError("NetworkStats summary failed for type $networkType: ${error.message ?: error.javaClass.simpleName}")
        } finally {
            stats?.close()
        }
    }

    private fun collectHistory(
        networkType: Int,
        startMillis: Long,
        endMillis: Long,
        destination: MutableMap<Long, Usage>,
        byDayUid: MutableMap<Long, MutableMap<Int, Usage>>,
        consumer: (Usage, NetworkStats.Bucket) -> Unit,
    ) {
        if (manager == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        var stats: NetworkStats? = null
        try {
            stats = manager.queryDetails(networkType, null, startMillis, endMillis)
            val bucket = NetworkStats.Bucket()
            while (stats.hasNextBucket()) {
                stats.getNextBucket(bucket)
                if (bucket.uid < 0) continue
                val dayStart = startOfDay(bucket.startTimeStamp)
                val usage = destination.getOrPut(dayStart) { Usage() }
                val uidUsage = byDayUid.getOrPut(dayStart) { mutableMapOf() }
                    .getOrPut(bucket.uid) { Usage() }
                consumer(usage, bucket)
                consumer(uidUsage, bucket)
            }
        } catch (error: SecurityException) {
            recordError("NetworkStats history permission denied: ${error.message ?: "PACKAGE_USAGE_STATS"}")
        } catch (error: Exception) {
            recordError("NetworkStats history failed for type $networkType: ${error.message ?: error.javaClass.simpleName}")
        } finally {
            stats?.close()
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

    private fun recordError(message: String) {
        lastError = message
        Log.w(TAG, message)
    }

    private class Usage {
        var wifiBytes: Long = 0
        var mobileBytes: Long = 0
        val totalBytes: Long get() = wifiBytes + mobileBytes
    }

    companion object {
        private const val TAG = "InternetManagerStats"
        @Volatile var lastError: String? = null
    }
}
