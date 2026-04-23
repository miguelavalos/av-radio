package com.avradio.core.database

import com.avradio.core.model.Station
import kotlinx.coroutines.flow.StateFlow

data class LibraryState(
    val favorites: List<Station> = emptyList(),
    val recents: List<Station> = emptyList(),
    val lastPlayedStationId: String? = null,
    val sleepTimerMinutes: Int? = null
) {
    fun isFavorite(station: Station): Boolean = favorites.any { it.id == station.id }
}

interface LibraryRepository {
    val state: StateFlow<LibraryState>

    suspend fun toggleFavorite(station: Station)
    suspend fun recordPlayback(station: Station)
    suspend fun setSleepTimerMinutes(minutes: Int?)
    suspend fun clear()
}
