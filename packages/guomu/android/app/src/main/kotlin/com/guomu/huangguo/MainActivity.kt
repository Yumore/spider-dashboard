package com.guomu.huangguo

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var deepLinkChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        deepLinkChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.guomu.huangguo/deeplink",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method == "getInitialLink") {
                    result.success(intent?.data?.toString())
                } else {
                    result.notImplemented()
                }
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.guomu.huangguo/share",
        ).setMethodCallHandler { call, result ->
            if (call.method != "share") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val title = call.argument<String>("title").orEmpty()
            val text = call.argument<String>("text").orEmpty()
            val url = call.argument<String>("url").orEmpty()
            val shareText = listOf(title, text, url)
                .filter { it.isNotBlank() }
                .joinToString("\n")

            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TITLE, title)
                putExtra(Intent.EXTRA_TEXT, shareText)
            }
            startActivity(Intent.createChooser(intent, "分享到"))
            result.success(true)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.data?.toString()?.let { link ->
            deepLinkChannel?.invokeMethod("link", link)
        }
    }
}
