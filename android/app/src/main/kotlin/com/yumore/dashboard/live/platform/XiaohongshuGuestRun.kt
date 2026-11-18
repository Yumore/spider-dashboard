package com.yumore.dashboard.live.platform

import android.webkit.WebView
import io.flutter.plugin.common.MethodChannel

internal class XiaohongshuGuestRun(
    val id: String,
    val view: WebView,
    val result: MethodChannel.Result,
) {
    var stage = "created"
    var timeout: Runnable? = null
    val waiters = mutableListOf<MethodChannel.Result>()
}
