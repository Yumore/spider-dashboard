package com.yumore.dashboard.shortdrama.platform.device

import android.app.Activity
import android.app.UiModeManager
import android.content.Context
import android.content.pm.ActivityInfo
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Bundle
import android.view.InputDevice

private const val STATE_TELEVISION_MODE = "duanju.televisionMode"

class ShortDramaDisplayController(private val activity: Activity) {
    var televisionMode: Boolean = false
        private set

    fun restore(savedInstanceState: Bundle?) {
        televisionMode = if (savedInstanceState?.containsKey(STATE_TELEVISION_MODE) == true) {
            savedInstanceState.getBoolean(STATE_TELEVISION_MODE)
        } else {
            isTelevisionDevice()
        }
    }

    fun save(outState: Bundle) {
        outState.putBoolean(STATE_TELEVISION_MODE, televisionMode)
    }

    fun orientationFor(requestedOrientation: Int): Int = if (televisionMode) {
        ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
    } else {
        requestedOrientation
    }

    fun applyCurrentOrientation() {
        if (televisionMode) {
            activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
        }
    }

    fun setTelevisionMode(enabled: Boolean) {
        val changed = televisionMode != enabled
        televisionMode = enabled
        if (enabled || changed) {
            activity.requestedOrientation = if (enabled) {
                ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
            } else {
                ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
            }
        }
    }

    @Suppress("DEPRECATION")
    fun isTelevisionDevice(): Boolean {
        val configuration = activity.resources.configuration
        val mode = (activity.getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager)?.currentModeType
            ?: (configuration.uiMode and Configuration.UI_MODE_TYPE_MASK)
        val packageManager = activity.packageManager
        if (mode == Configuration.UI_MODE_TYPE_TELEVISION ||
            packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK) ||
            packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK_ONLY) ||
            packageManager.hasSystemFeature(PackageManager.FEATURE_TELEVISION) ||
            packageManager.hasSystemFeature("amazon.hardware.fire_tv")) {
            return true
        }
        if (mode == Configuration.UI_MODE_TYPE_CAR ||
            mode == Configuration.UI_MODE_TYPE_WATCH ||
            mode == Configuration.UI_MODE_TYPE_VR_HEADSET ||
            configuration.touchscreen != Configuration.TOUCHSCREEN_NOTOUCH ||
            packageManager.hasSystemFeature(PackageManager.FEATURE_TOUCHSCREEN) ||
            packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY) ||
            packageManager.hasSystemFeature(PackageManager.FEATURE_SENSOR_ACCELEROMETER) ||
            packageManager.hasSystemFeature(PackageManager.FEATURE_AUTOMOTIVE) ||
            packageManager.hasSystemFeature(PackageManager.FEATURE_WATCH) ||
            packageManager.hasSystemFeature(PackageManager.FEATURE_PC)) {
            return false
        }
        val remoteNavigation = configuration.navigation == Configuration.NAVIGATION_DPAD ||
            InputDevice.getDeviceIds().any { id ->
                val device = InputDevice.getDevice(id)
                device != null && !device.isVirtual && device.supportsSource(InputDevice.SOURCE_DPAD)
            }
        return remoteNavigation || packageManager.hasSystemFeature(PackageManager.FEATURE_LIVE_TV)
    }

}
