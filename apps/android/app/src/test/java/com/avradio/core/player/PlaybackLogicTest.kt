package com.avradio.core.player

import androidx.media3.common.MediaMetadata
import com.avradio.core.model.Station
import kotlin.test.assertEquals
import kotlin.test.assertNull
import org.junit.Test

class PlaybackLogicTest {
    private val a = station("a", "Alpha")
    private val b = station("b", "Beta")
    private val c = station("c", "Gamma")

    @Test
    fun sanitizeQueuePutsCurrentFirstAndDeduplicates() {
        val queue = PlaybackLogic.sanitizeQueue(listOf(b, a, b, c), a)

        assertEquals(listOf(a, b, c), queue)
    }

    @Test
    fun nextStationWrapsAround() {
        val next = PlaybackLogic.nextStation(listOf(a, b, c), c)

        assertEquals(a, next)
    }

    @Test
    fun previousStationWrapsAround() {
        val previous = PlaybackLogic.previousStation(listOf(a, b, c), a)

        assertEquals(c, previous)
    }

    @Test
    fun nextStationReturnsNullForShortQueue() {
        assertNull(PlaybackLogic.nextStation(listOf(a), a))
    }

    @Test
    fun parseMetadataPrefersExplicitArtistAndTitle() {
        val parsed = PlaybackLogic.parseMetadata(
            MediaMetadata.Builder()
                .setTitle("Song")
                .setArtist("Artist")
                .build()
        )

        assertEquals("Song", parsed.title)
        assertEquals("Artist", parsed.artist)
    }

    @Test
    fun parseMetadataFallsBackToDisplayTitleSplit() {
        val parsed = PlaybackLogic.parseMetadata(
            MediaMetadata.Builder()
                .setDisplayTitle("Artist - Song")
                .build()
        )

        assertEquals("Song", parsed.title)
        assertEquals("Artist", parsed.artist)
    }

    private fun station(id: String, name: String) = Station(
        id = id,
        name = name,
        country = "Spain",
        language = "Spanish",
        tags = "pop",
        streamUrl = "https://example.com/$id.mp3"
    )
}
