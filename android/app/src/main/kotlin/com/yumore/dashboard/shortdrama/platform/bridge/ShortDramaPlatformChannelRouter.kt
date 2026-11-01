package com.yumore.dashboard.shortdrama.platform.bridge

import android.app.Activity
import android.os.Build
import com.yumore.dashboard.shortdrama.platform.device.ShortDramaDisplayController
import com.yumore.dashboard.shortdrama.platform.device.ShortDramaPictureInPictureController
import com.yumore.dashboard.shortdrama.platform.device.ShortDramaPlaybackEnvironment
import com.yumore.dashboard.shortdrama.platform.media.ShortDramaFfmpegRunner
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

private const val CHANNEL_NAME = "duanju/device"

class ShortDramaPlatformChannelRouter(
    private val activity: Activity,
    private val displayController: ShortDramaDisplayController,
    private val pictureInPictureController: ShortDramaPictureInPictureController,
    private val playbackEnvironment: ShortDramaPlaybackEnvironment,
    private val ffmpegRunner: ShortDramaFfmpegRunner,
) : MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null

    fun attach(engine: FlutterEngine) {
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_NAME).also {
            it.setMethodCallHandler(this)
        }
    }

    fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    fun notifyPictureInPictureMode(active: Boolean) {
        channel?.invokeMethod("pictureInPictureChanged", mapOf("active" to active))
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "deviceInfo" -> result.success(deviceInfo())
            "setTelevisionMode" -> setTelevisionMode(call, result)
            "playbackPower" -> result.success(runCatching { playbackEnvironment.playbackPower() }.getOrNull())
            "systemProxy" -> result.success(playbackEnvironment.systemProxy())
            "pictureInPictureStatus" -> result.success(pictureInPictureController.status())
            "enterPictureInPicture" -> enterPictureInPicture(call, result)
            "ffmpegRun" -> runFfmpeg(call, result)
            "ffmpegProbe" -> probeFfmpeg(call, result)
            "ffmpegProgress" -> result.success(ffmpegRunner.progress(call.argument<String>("id").orEmpty()))
            "ffmpegCancel" -> cancelFfmpeg(call, result)
            else -> result.notImplemented()
        }
    }

    private fun deviceInfo(): Map<String, Any?> {
        @Suppress("DEPRECATION")
        val version = activity.packageManager.getPackageInfo(activity.packageName, 0).versionName
        return mapOf(
            "television" to displayController.isTelevisionDevice(),
            "version" to version,
            "sdkInt" to Build.VERSION.SDK_INT,
        )
    }

    private fun setTelevisionMode(call: MethodCall, result: MethodChannel.Result) {
        val enabled = call.argument<Boolean>("enabled")
        if (enabled == null) {
            result.error("invalid_display_mode", "缺少电视模式状态", null)
            return
        }
        displayController.setTelevisionMode(enabled)
        result.success(null)
    }

    private fun enterPictureInPicture(call: MethodCall, result: MethodChannel.Result) {
        result.success(
            pictureInPictureController.enter(
                width = call.argument<Int>("width") ?: 16,
                height = call.argument<Int>("height") ?: 9,
                left = call.argument("left"),
                top = call.argument("top"),
                right = call.argument("right"),
                bottom = call.argument("bottom"),
            ),
        )
    }

    private fun runFfmpeg(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id").orEmpty()
        val arguments = call.argument<List<String>>("arguments").orEmpty()
        if (id.isEmpty() || arguments.isEmpty()) {
            result.error("invalid_args", "缺少媒体处理参数", null)
            return
        }
        ffmpegRunner.run(id, arguments) { code, cancelled ->
            result.success(mapOf("code" to code, "cancelled" to cancelled))
        }
    }

    private fun probeFfmpeg(call: MethodCall, result: MethodChannel.Result) {
        val file = call.argument<String>("file").orEmpty()
        if (file.isEmpty()) {
            result.error("invalid_args", "缺少媒体路径", null)
            return
        }
        ffmpegRunner.probe(file, result::success)
    }

    private fun cancelFfmpeg(call: MethodCall, result: MethodChannel.Result) {
        ffmpegRunner.cancel(call.argument<String>("id").orEmpty())
        result.success(null)
    }
}
