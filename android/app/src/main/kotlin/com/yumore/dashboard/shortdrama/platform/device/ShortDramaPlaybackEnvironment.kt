package com.yumore.dashboard.shortdrama.platform.device

import android.app.Activity
import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import android.os.SystemClock

class ShortDramaPlaybackEnvironment(private val activity: Activity) {
    private var headroomReadAt = 0L
    private var thermalHeadroom: Double? = null

    fun playbackPower(): Map<String, Any?> {
        val power = activity.getSystemService(Context.POWER_SERVICE) as? PowerManager
        val manager = activity.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
        val battery = activity.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val now = SystemClock.elapsedRealtime()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
            (headroomReadAt == 0L || now - headroomReadAt >= 10000L)) {
            headroomReadAt = now
            thermalHeadroom = runCatching {
                power?.getThermalHeadroom(0)?.toDouble()?.takeIf { it.isFinite() }
            }.getOrNull()
        }
        val thermalStatus = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            power?.currentThermalStatus ?: PowerManager.THERMAL_STATUS_NONE
        } else {
            0
        }
        return mapOf(
            "batterySaver" to (power?.isPowerSaveMode ?: false),
            "onBattery" to ((battery?.getIntExtra(BatteryManager.EXTRA_PLUGGED, -1) ?: -1) <= 0),
            "thermalStatus" to thermalStatus,
            "headroom" to thermalHeadroom,
            "lowMemory" to (manager?.isLowRamDevice ?: true),
            "gles" to (manager?.deviceConfigurationInfo?.reqGlEsVersion ?: 0),
        )
    }

    fun systemProxy(): Map<String, Any> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            return mapOf(
                "http" to "",
                "https" to "",
                "bypass" to emptyList<String>(),
                "pac" to false,
            )
        }
        val connection = activity.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val proxy = connection.defaultProxy
        val host = proxy?.host.orEmpty()
        val address = if (host.isNotEmpty() && (proxy?.port ?: 0) > 0) {
            "http://${if (host.contains(':')) "[$host]" else host}:${proxy!!.port}"
        } else {
            ""
        }
        return mapOf(
            "http" to address,
            "https" to address,
            "bypass" to (proxy?.exclusionList?.toList() ?: emptyList<String>()),
            "pac" to (proxy != null && proxy.pacFileUrl != Uri.EMPTY),
        )
    }
}
