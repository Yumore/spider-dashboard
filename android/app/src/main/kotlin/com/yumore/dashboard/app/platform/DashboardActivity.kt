package com.yumore.dashboard.app.platform

import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.content.pm.ActivityInfo
import android.provider.Settings
import android.view.KeyEvent
import androidx.core.content.FileProvider
import java.io.File
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
    private var guomuUpdateChannel: MethodChannel? = null
    private var xiaohongshuGuestMethodChannel: MethodChannel? = null
    private var xiaohongshuGuestHandler: XiaohongshuGuestChannel? = null
    private var pendingGuomuDeepLink: String? = null
    private var pendingGuomuUpdatePath: String? = null
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
        resumePendingGuomuUpdate()
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
        guomuUpdateChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.guomu.huangguo/update",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method != "installApk") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    val file = File(call.argument<String>("path").orEmpty()).canonicalFile
                    val allowedDirectory = File(cacheDir, "guomu-updates").canonicalFile
                    if (file.parentFile != allowedDirectory || !file.isFile || file.extension != "apk") {
                        result.error("invalid_apk", "安装包不存在，请重新下载", null)
                    } else if (!hasMatchingGuomuUpdateSignature(file)) {
                        result.error(
                            "signature_mismatch",
                            "新版安装签名与当前版本不兼容。请保留需要的数据后卸载旧版，再手动安装新版；后续版本可直接更新。",
                            null,
                        )
                    } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                        !packageManager.canRequestPackageInstalls()
                    ) {
                        pendingGuomuUpdatePath = file.path
                        startActivity(
                            Intent(
                                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:$packageName"),
                            ),
                        )
                        result.success(true)
                    } else {
                        openGuomuUpdateInstaller(file)
                        result.success(true)
                    }
                } catch (_: Exception) {
                    result.error("install_failed", "无法打开安装程序", null)
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

    private fun resumePendingGuomuUpdate() {
        val path = pendingGuomuUpdatePath ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            pendingGuomuUpdatePath = null
            return
        }
        pendingGuomuUpdatePath = null
        try {
            openGuomuUpdateInstaller(File(path))
        } catch (_: Exception) {
            // A user may revoke the permission or remove the cached package while
            // Settings is open. The next update check can offer the package again.
        }
    }

    private fun openGuomuUpdateInstaller(file: File) {
        val uri = FileProvider.getUriForFile(this, "$packageName.updates", file)
        startActivity(Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        })
    }

    @Suppress("DEPRECATION")
    private fun hasMatchingGuomuUpdateSignature(file: File): Boolean {
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            PackageManager.GET_SIGNATURES
        }
        val current = packageManager.getPackageInfo(packageName, flags)
        val update = packageManager.getPackageArchiveInfo(file.path, flags) ?: return false
        if (update.packageName != packageName) return false
        val currentSigners = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            current.signingInfo?.apkContentsSigners
        } else {
            current.signatures
        }
        val updateSigners = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            update.signingInfo?.apkContentsSigners
        } else {
            update.signatures
        }
        return currentSigners != null && updateSigners != null &&
            currentSigners.isNotEmpty() && updateSigners.isNotEmpty() &&
            currentSigners.all { signer ->
                updateSigners.any { candidate ->
                    signer.toByteArray().contentEquals(candidate.toByteArray())
                }
            }
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
        guomuUpdateChannel?.setMethodCallHandler(null)
        guomuUpdateChannel = null
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
