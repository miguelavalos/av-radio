package com.avradio.core.player

import androidx.media3.common.MediaMetadata
import com.avradio.core.model.Station

internal data class ParsedMetadata(
    val title: String?,
    val artist: String?
)

internal object PlaybackLogic {
    fun sanitizeQueue(queue: List<Station>, currentStation: Station): List<Station> {
        val result = mutableListOf<Station>()
        val seen = mutableSetOf<String>()
        if (seen.add(currentStation.id)) result.add(currentStation)
        queue.forEach { station ->
            if (seen.add(station.id)) result.add(station)
        }
        return result
    }

    fun nextStation(queue: List<Station>, currentStation: Station): Station? {
        if (queue.size < 2) return null
        val currentIndex = queue.indexOfFirst { it.id == currentStation.id }
        if (currentIndex == -1) return null
        val nextIndex = if (currentIndex == queue.lastIndex) 0 else currentIndex + 1
        return queue[nextIndex]
    }

    fun previousStation(queue: List<Station>, currentStation: Station): Station? {
        if (queue.size < 2) return null
        val currentIndex = queue.indexOfFirst { it.id == currentStation.id }
        if (currentIndex == -1) return null
        val previousIndex = if (currentIndex == 0) queue.lastIndex else currentIndex - 1
        return queue[previousIndex]
    }

    fun parseMetadata(mediaMetadata: MediaMetadata): ParsedMetadata {
        val title = mediaMetadata.title?.toString()?.trim().takeUnless { it.isNullOrBlank() }
        val artist = mediaMetadata.artist?.toString()?.trim().takeUnless { it.isNullOrBlank() }

        if (artist != null || title != null) {
            return ParsedMetadata(title = title, artist = artist)
        }

        val displayTitle = mediaMetadata.displayTitle?.toString()?.trim().takeUnless { it.isNullOrBlank() }
        if (displayTitle != null && " - " in displayTitle) {
            val parts = displayTitle.split(" - ", limit = 2)
            return ParsedMetadata(
                title = parts.getOrNull(1)?.trim().takeUnless { it.isNullOrBlank() },
                artist = parts.getOrNull(0)?.trim().takeUnless { it.isNullOrBlank() }
            )
        }

        return ParsedMetadata(title = displayTitle, artist = null)
    }
}
