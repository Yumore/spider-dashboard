package com.yumore.dashboard.shortdrama.platform.media

import android.app.Activity
import com.arthenica.mobileffmpeg.Config
import com.mobile.ffmpeg.FFmpeg
import com.mobile.ffmpeg.Statistics
import com.mobile.ffmpeg.StatisticsCallback
import java.util.concurrent.ConcurrentHashMap

class ShortDramaFfmpegRunner(private val activity: Activity) {
    private val jobs = ConcurrentHashMap<String, ShortDramaFfmpegJob>()
    private val activeJob = ThreadLocal<ShortDramaFfmpegJob?>()
    private val probeParser = ShortDramaFfmpegProbeParser()

    @Volatile
    private var callbacksReady = false

    fun run(id: String, arguments: List<String>, onComplete: (Int, Boolean) -> Unit) {
        val job = ShortDramaFfmpegJob(id)
        start(job, arguments) { finished, code -> onComplete(code, finished.cancelled) }
    }

    fun probe(file: String, onComplete: (Map<String, Any>) -> Unit) {
        val job = ShortDramaFfmpegJob("probe-${System.nanoTime()}")
        start(job, listOf("-hide_banner", "-i", file)) { finished, _ ->
            val log = synchronized(finished.log) { finished.log.toString() }
            onComplete(probeParser.parse(log))
        }
    }

    fun progress(id: String): Long = jobs[id]?.timeMs ?: 0L

    fun cancel(id: String) {
        val job = jobs[id] ?: return
        if (job.running) {
            job.cancelled = true
            FFmpeg.cancel()
        }
    }

    private fun start(
        job: ShortDramaFfmpegJob,
        arguments: List<String>,
        onComplete: (ShortDramaFfmpegJob, Int) -> Unit,
    ) {
        jobs[job.id] = job
        Thread {
            val exitCode = runCatching {
                ensureCallbacks()
                activeJob.set(job)
                try {
                    FFmpeg.execute(arguments.toTypedArray())
                } finally {
                    activeJob.remove()
                }
            }.getOrElse { -1 }
            job.running = false
            jobs.remove(job.id, job)
            activity.runOnUiThread { onComplete(job, exitCode) }
        }.start()
    }

    private fun ensureCallbacks() {
        if (callbacksReady) return
        synchronized(this) {
            if (callbacksReady) return
            Config.enableLogCallback { message ->
                val job = activeJob.get()
                if (job != null) {
                    synchronized(job.log) { job.log.append(message.text).append('\n') }
                }
            }
            Config.enableStatisticsCallback(object : StatisticsCallback {
                override fun apply(statistics: Statistics) {
                    activeJob.get()?.timeMs = statistics.time.toLong()
                }

                override fun onCancel() = Unit
            })
            callbacksReady = true
        }
    }
}
