package com.yumore.dashboard.app.platform

import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.content.pm.ActivityInfo
import com.yumore.dashboard.shortdrama.platform.bridge.ShortDramaPlatformChannelRouter
import com.yumore.dashboard.shortdrama.platform.device.ShortDramaDisplayController
import com.yumore.dashboard.shortdrama.platform.device.ShortDramaPictureInPictureController
import com.yumore.dashboard.shortdrama.platform.device.ShortDramaPlaybackEnvironment
import com.yumore.dashboard.shortdrama.platform.media.ShortDramaFfmpegRunner
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class DashboardActivity : FlutterActivity() {
    private lateinit var displayController: ShortDramaDisplayController
    private lateinit var pictureInPictureController: ShortDramaPictureInPictureController
    private lateinit var playbackEnvironment: ShortDramaPlaybackEnvironment
    private lateinit var ffmpegRunner: ShortDramaFfmpegRunner
    private var channelRouter: ShortDramaPlatformChannelRouter? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        displayController = ShortDramaDisplayController(this)
        displayController.restore(savedInstanceState)
        pictureInPictureController = ShortDramaPictureInPictureController(this)
        playbackEnvironment = ShortDramaPlaybackEnvironment(this)
        ffmpegRunner = ShortDramaFfmpegRunner(this)
        super.onCreate(savedInstanceState)
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
        displayController.applyCurrentOrientation()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        displayController.save(outState)
        super.onSaveInstanceState(outState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channelRouter = ShortDramaPlatformChannelRouter(
            activity = this,
            displayController = displayController,
            pictureInPictureController = pictureInPictureController,
            playbackEnvironment = playbackEnvironment,
            ffmpegRunner = ffmpegRunner,
        ).also { it.attach(flutterEngine) }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        channelRouter?.notifyPictureInPictureMode(isInPictureInPictureMode)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        channelRouter?.detach()
        channelRouter = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
