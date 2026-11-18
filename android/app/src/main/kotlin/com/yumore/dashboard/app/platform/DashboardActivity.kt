package com.yumore.dashboard.app.platform

import android.content.Intent
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.content.pm.ActivityInfo
import android.view.KeyEvent
import com.yumore.dashboard.novelsound.platform.AiRequestPlugin
import com.yumore.dashboard.novelsound.platform.DownloadsPlugin
import com.yumore.dashboard.novelsound.platform.EinkRefreshPlugin
import com.yumore.dashboard.novelsound.platform.FairMemoryPlugin
import com.yumore.dashboard.novelsound.platform.FanqieAccountPlugin
import com.yumore.dashboard.novelsound.platform.LibraryBackupPlugin
import com.yumore.dashboard.novelsound.platform.LocalBookPickerPlugin
import com.yumore.dashboard.novelsound.platform.NativePlayerPlugin
import com.yumore.dashboard.novelsound.platform.PlayerSystemUiPlugin
import com.yumore.dashboard.novelsound.platform.ReaderDevicePlugin
import com.yumore.dashboard.novelsound.platform.RendererCompatibility
import com.yumore.dashboard.novelsound.platform.SecureKeyPlugin
import com.yumore.dashboard.novelsound.platform.SharePlugin
import com.yumore.dashboard.novelsound.platform.SystemTtsPlugin
import com.yumore.dashboard.novelsound.platform.cloudsync.CloudLoginPlugin
import com.yumore.dashboard.novelsound.platform.cloudsync.CloudStoragePlugin
import com.yumore.dashboard.novelsound.platform.cloudsync.SyncStoragePlugin
import com.yumore.dashboard.live.platform.XiaohongshuGuestChannel
import com.yumore.dashboard.shortdrama.platform.bridge.ShortDramaPlatformChannelRouter
import com.yumore.dashboard.shortdrama.platform.device.ShortDramaDisplayController
import com.yumore.dashboard.shortdrama.platform.device.ShortDramaPictureInPictureController
import com.yumore.dashboard.shortdrama.platform.device.ShortDramaPlaybackEnvironment
import com.yumore.dashboard.shortdrama.platform.media.ShortDramaFfmpegRunner
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterShellArgs
import io.flutter.plugin.common.MethodChannel

class DashboardActivity : FlutterActivity() {
    private lateinit var displayController: ShortDramaDisplayController
    private lateinit var pictureInPictureController: ShortDramaPictureInPictureController
    private lateinit var playbackEnvironment: ShortDramaPlaybackEnvironment
    private lateinit var ffmpegRunner: ShortDramaFfmpegRunner
    private var channelRouter: ShortDramaPlatformChannelRouter? = null
    private var volumeKeyEnabled = false
    private var volumeChannel: MethodChannel? = null
    private var hapticsChannel: MethodChannel? = null
    private var guomuDeepLinkChannel: MethodChannel? = null
    private var guomuEntryChannel: MethodChannel? = null
    private var xiaohongshuGuestMethodChannel: MethodChannel? = null
    private var xiaohongshuGuestHandler: XiaohongshuGuestChannel? = null
    private var pendingGuomuDeepLink: String? = null
    internal var isResumed = false

    override fun getFlutterShellArgs(): FlutterShellArgs =
        super.getFlutterShellArgs().also(RendererCompatibility::configure)

    override fun onCreate(savedInstanceState: Bundle?) {
        displayController = ShortDramaDisplayController(this)
        displayController.restore(savedInstanceState)
        pictureInPictureController = ShortDramaPictureInPictureController(this)
        playbackEnvironment = ShortDramaPlaybackEnvironment(this)
        ffmpegRunner = ShortDramaFfmpegRunner(this)
        super.onCreate(savedInstanceState)
        pendingGuomuDeepLink = intent?.dataString?.takeIf {
            Uri.parse(it).scheme == "guomu"
        }
        displayController.applyCurrentOrientation()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isNavigationBarContrastEnforced = false
            window.isStatusBarContrastEnforced = false
        }
    }

    override fun setRequestedOrientation(requestedOrientation: Int) {
        val orientation = if (::displayController.isInitialized) {
            displayController.orientationFor(requestedOrientation)
        } else requestedOrientation
        super.setRequestedOrientation(orientation)
    }

    override fun onResume() {
        super.onResume()
        isResumed = true
        displayController.applyCurrentOrientation()
    }

    override fun onPause() {
        isResumed = false
        super.onPause()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        displayController.save(outState)
        super.onSaveInstanceState(outState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(NativePlayerPlugin())
        flutterEngine.plugins.add(ReaderDevicePlugin())
        flutterEngine.plugins.add(PlayerSystemUiPlugin())
        flutterEngine.plugins.add(SystemTtsPlugin())
        flutterEngine.plugins.add(SecureKeyPlugin())
        flutterEngine.plugins.add(LocalBookPickerPlugin())
        flutterEngine.plugins.add(LibraryBackupPlugin())
        flutterEngine.plugins.add(SyncStoragePlugin())
        flutterEngine.plugins.add(CloudLoginPlugin())
        flutterEngine.plugins.add(CloudStoragePlugin())
        flutterEngine.plugins.add(FanqieAccountPlugin())
        flutterEngine.plugins.add(SharePlugin())
        flutterEngine.plugins.add(DownloadsPlugin())
        flutterEngine.plugins.add(EinkRefreshPlugin())
        flutterEngine.plugins.add(FairMemoryPlugin())
        flutterEngine.plugins.add(AiRequestPlugin())

        val xiaohongshuGuestHandler = XiaohongshuGuestChannel { this }
        this.xiaohongshuGuestHandler = xiaohongshuGuestHandler
        xiaohongshuGuestMethodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "pure_live/xiaohongshu_guest",
        ).also { channel ->
            channel.setMethodCallHandler(xiaohongshuGuestHandler::handle)
        }

        hapticsChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "fqapp/haptics",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method != "setEnabled") {
                    result.notImplemented()
                } else if (call.arguments !is Boolean) {
                    result.error("BAD_ARGUMENT", "Expected a boolean", null)
                } else {
                    window.decorView.isHapticFeedbackEnabled = call.arguments as Boolean
                    result.success(true)
                }
            }
        }
        volumeChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "fqapp/volume-key",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method == "setEnabled") {
                    volumeKeyEnabled = call.arguments as? Boolean ?: false
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
        }
        guomuDeepLinkChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.guomu.huangguo/deeplink",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialLink" -> {
                        result.success(pendingGuomuDeepLink)
                        pendingGuomuDeepLink = null
                    }
                    "consumeInitialLink" -> {
                        pendingGuomuDeepLink = null
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        guomuEntryChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.yumore.dashboard/guomu-entry",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method != "getInitialLink") {
                    result.notImplemented()
                } else {
                    result.success(pendingGuomuDeepLink)
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
            val sendIntent = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TITLE, title)
                putExtra(Intent.EXTRA_TEXT, shareText)
            }
            startActivity(Intent.createChooser(sendIntent, "分享到"))
            result.success(true)
        }
        channelRouter = ShortDramaPlatformChannelRouter(
            activity = this,
            displayController = displayController,
            pictureInPictureController = pictureInPictureController,
            playbackEnvironment = playbackEnvironment,
            ffmpegRunner = ffmpegRunner,
        ).also { it.attach(flutterEngine) }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val link = intent.data?.takeIf { it.scheme == "guomu" }?.toString()
            ?: return
        pendingGuomuDeepLink = link
        guomuDeepLinkChannel?.invokeMethod("link", link)
        guomuEntryChannel?.invokeMethod("open", link)
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        channelRouter?.notifyPictureInPictureMode(isInPictureInPictureMode)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        hapticsChannel?.setMethodCallHandler(null)
        hapticsChannel = null
        volumeChannel?.setMethodCallHandler(null)
        volumeChannel = null
        guomuDeepLinkChannel?.setMethodCallHandler(null)
        guomuDeepLinkChannel = null
        guomuEntryChannel?.setMethodCallHandler(null)
        guomuEntryChannel = null
        xiaohongshuGuestMethodChannel?.setMethodCallHandler(null)
        xiaohongshuGuestMethodChannel = null
        xiaohongshuGuestHandler?.dispose()
        xiaohongshuGuestHandler = null
        channelRouter?.detach()
        channelRouter = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun dispatchKeyEvent(event: KeyEvent?): Boolean {
        if (volumeKeyEnabled && event != null) {
            val key = event.keyCode
            if (key == KeyEvent.KEYCODE_VOLUME_DOWN || key == KeyEvent.KEYCODE_VOLUME_UP) {
                if (event.action == KeyEvent.ACTION_DOWN && event.repeatCount == 0) {
                    val direction = if (key == KeyEvent.KEYCODE_VOLUME_DOWN) 1 else -1
                    volumeChannel?.invokeMethod("volumeKey", direction)
                }
                return true
            }
        }
        return super.dispatchKeyEvent(event)
    }
}
