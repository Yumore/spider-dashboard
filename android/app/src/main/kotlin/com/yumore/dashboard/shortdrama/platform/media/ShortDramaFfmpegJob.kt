package com.yumore.dashboard.shortdrama.platform.media

class ShortDramaFfmpegJob(val id: String) {
    val log = StringBuilder()

    @Volatile
    var timeMs = 0L

    @Volatile
    var running = true

    @Volatile
    var cancelled = false
}
