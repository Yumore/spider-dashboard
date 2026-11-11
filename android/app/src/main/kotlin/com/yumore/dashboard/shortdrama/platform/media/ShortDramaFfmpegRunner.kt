package com.yumore.dashboard.shortdrama.platform.media

import android.app.Activity
import com.antonkarpenko.ffmpegkit.FFmpegKit
import java.util.concurrent.ConcurrentHashMap

class ShortDramaFfmpegRunner(private val activity: Activity) {
    private val jobs = ConcurrentHashMap<String, ShortDramaFfmpegJob>()
    private val probeParser = ShortDramaFfmpegProbeParser()

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
            job.sessionId?.let(FFmpegKit::cancel)
        }
    }

    private fun start(
        job: ShortDramaFfmpegJob,
        arguments: List<String>,
        onComplete: (ShortDramaFfmpegJob, Int) -> Unit,
    ) {
        jobs[job.id] = job
        runCatching {
            FFmpegKit.executeWithArgumentsAsync(
                arguments.toTypedArray(),
                { session ->
                    val exitCode = session.returnCode?.value ?: -1
                    job.running = false
                    jobs.remove(job.id, job)
                    activity.runOnUiThread { onComplete(job, exitCode) }
                },
                { log ->
                    synchronized(job.log) { job.log.append(log.message).append('\n') }
                },
                { statistics -> job.timeMs = statistics.time.toLong() },
            )
        }.onSuccess { session ->
            job.sessionId = session.sessionId
            if (job.cancelled) {
                FFmpegKit.cancel(session.sessionId)
            }
        }.onFailure {
            job.running = false
            jobs.remove(job.id, job)
            activity.runOnUiThread { onComplete(job, -1) }
        }
    }
}
