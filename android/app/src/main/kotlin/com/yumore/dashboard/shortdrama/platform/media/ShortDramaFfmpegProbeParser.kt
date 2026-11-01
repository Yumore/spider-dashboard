package com.yumore.dashboard.shortdrama.platform.media

class ShortDramaFfmpegProbeParser {
    fun parse(text: String): Map<String, Any> {
        val streams = mutableListOf<Map<String, Any>>()
        val duration = parseDuration(text)
        Regex("""Stream #\S+[^\n]*""").findAll(text).forEach { match ->
            parseStream(match.value)?.let(streams::add)
        }
        return mapOf(
            "streams" to streams,
            "format" to mapOf("duration" to duration.toString()),
        )
    }

    private fun parseDuration(text: String): Double {
        val match = Regex("""Duration:\s*(\d+):(\d+):(\d+(?:\.\d+)?)""").find(text)
            ?: return 0.0
        return match.groupValues[1].toDouble() * 3600 +
            match.groupValues[2].toDouble() * 60 +
            match.groupValues[3].toDouble()
    }

    private fun parseStream(line: String): Map<String, Any>? = when {
        line.contains(": Video:") -> parseVideoStream(line)
        line.contains(": Audio:") -> parseAudioStream(line)
        else -> null
    }

    private fun parseVideoStream(line: String): Map<String, Any>? {
        val codec = Regex("""Video:\s*(\w+)""").find(line)?.groupValues?.get(1).orEmpty()
        if (codec.isEmpty()) return null
        val pixel = Regex("""Video:\s*\w+(?:\s*\([^)]*\))*,\s*(\w+)(?:\(([^)]*)\))?""")
            .find(line)
        val size = Regex("""(\d{2,5})x(\d{2,5})""").find(line)
        val sampleAspectRatio = Regex("""SAR\s+([0-9]+:[0-9]+)""").find(line)
            ?.groupValues?.get(1) ?: "1:1"
        var colorTransfer = "unknown"
        var colorPrimaries = "unknown"
        pixel?.groupValues?.get(2)?.let { colors ->
            val parts = colors.split(',', '/').map(String::trim).filter(String::isNotEmpty)
            if (parts.isNotEmpty()) {
                colorPrimaries = when (parts[0]) {
                    "tv", "pc" -> parts.getOrNull(1) ?: "unknown"
                    else -> parts[0]
                }
                colorTransfer = when {
                    parts.size >= 3 -> parts[2]
                    parts.size >= 2 && parts[0] != "tv" && parts[0] != "pc" -> parts[1]
                    parts.size >= 2 -> parts[1]
                    else -> "unknown"
                }
            }
        }
        return mapOf(
            "codec_type" to "video",
            "codec_name" to codec,
            "width" to (size?.groupValues?.get(1)?.toIntOrNull() ?: 0),
            "height" to (size?.groupValues?.get(2)?.toIntOrNull() ?: 0),
            "pix_fmt" to pixel?.groupValues?.get(1).orEmpty(),
            "sample_aspect_ratio" to sampleAspectRatio,
            "color_transfer" to colorTransfer,
            "color_primaries" to colorPrimaries,
            "extradata_hash" to "unknown",
        )
    }

    private fun parseAudioStream(line: String): Map<String, Any>? {
        val codec = Regex("""Audio:\s*(\w+)""").find(line)?.groupValues?.get(1).orEmpty()
        if (codec.isEmpty()) return null
        val tags = Regex("""Audio:\s*\w+((?:\s*\([^)]*\))+)""")
            .find(line)?.groupValues?.get(1).orEmpty()
        val firstTag = Regex("""\(([^)]*)\)""").find(tags)?.groupValues?.get(1)
        val profile = if (firstTag != null && !firstTag.contains('/')) firstTag else "unknown"
        val sampleRate = Regex("""(\d+)\s*Hz""").find(line)?.groupValues?.get(1) ?: "0"
        val layout = Regex("""Hz,\s*([a-zA-Z0-9.()]+?)\s*,""").find(line)
            ?.groupValues?.get(1) ?: "stereo"
        val channels = when {
            layout.startsWith("mono") -> 1
            layout.startsWith("stereo") -> 2
            layout.startsWith("1.") -> 2
            layout.startsWith("2.") -> 3
            layout.startsWith("5.1") || layout.startsWith("5.0") -> 6
            layout.startsWith("7.1") -> 8
            else -> 2
        }
        return mapOf(
            "codec_type" to "audio",
            "codec_name" to codec,
            "profile" to profile,
            "sample_rate" to sampleRate,
            "channels" to channels,
            "channel_layout" to layout,
            "extradata_hash" to "unknown",
        )
    }
}
