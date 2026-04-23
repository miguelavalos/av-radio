package com.avradio.core.player

import com.avradio.core.model.Station

data class PlayerState(
    val currentStation: Station? = null,
    val isPlaying: Boolean = false,
    val isBuffering: Boolean = false,
    val errorMessage: String? = null,
    val currentTrackTitle: String? = null,
    val currentTrackArtist: String? = null,
    val currentTrackAlbumTitle: String? = null,
    val currentArtworkUrl: String? = null,
    val queue: List<Station> = emptyList(),
    val canCycleQueue: Boolean = false,
    val sleepTimerDescription: String? = null
)
