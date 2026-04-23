package com.avradio.core.database

import android.content.Context
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.emptyPreferences
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStoreFile
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import com.avradio.core.model.Station
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import kotlinx.serialization.encodeToString
import java.io.IOException

class DataStoreLibraryRepository(
    context: Context,
    private val json: Json = Json { ignoreUnknownKeys = true }
) : LibraryRepository {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val dataStore = PreferenceDataStoreFactory.create(
        scope = scope,
        produceFile = { context.preferencesDataStoreFile("avradio_library.preferences_pb") }
    )

    private val _state = MutableStateFlow(LibraryState())
    override val state: StateFlow<LibraryState> = _state.asStateFlow()

    init {
        scope.launch {
            dataStore.data
                .catch { error ->
                    if (error is IOException) {
                        emit(emptyPreferences())
                    } else {
                        throw error
                    }
                }
                .map(::preferencesToState)
                .collect { _state.value = it }
        }
    }

    override suspend fun toggleFavorite(station: Station) {
        val current = state.value
        val updatedFavorites = if (current.isFavorite(station)) {
            current.favorites.filterNot { it.id == station.id }
        } else {
            listOf(station) + current.favorites.filterNot { it.id == station.id }
        }

        persist(
            current.copy(favorites = updatedFavorites)
        )
    }

    override suspend fun recordPlayback(station: Station) {
        val current = state.value
        val updatedRecents = buildList {
            add(station)
            addAll(current.recents.filterNot { it.id == station.id }.take(19))
        }

        persist(
            current.copy(
                recents = updatedRecents,
                lastPlayedStationId = station.id
            )
        )
    }

    override suspend fun clear() {
        persist(LibraryState())
    }

    override suspend fun setSleepTimerMinutes(minutes: Int?) {
        persist(state.value.copy(sleepTimerMinutes = minutes))
    }

    private suspend fun persist(next: LibraryState) {
        dataStore.edit { prefs ->
            prefs[FAVORITES_KEY] = json.encodeToString(next.favorites)
            prefs[RECENTS_KEY] = json.encodeToString(next.recents)
            prefs[LAST_PLAYED_KEY] = next.lastPlayedStationId.orEmpty()
            prefs[SLEEP_TIMER_KEY] = next.sleepTimerMinutes?.toString().orEmpty()
        }
    }

    private fun preferencesToState(preferences: Preferences): LibraryState {
        val favorites = decodeStations(preferences[FAVORITES_KEY])
        val recents = decodeStations(preferences[RECENTS_KEY])
        val lastPlayed = preferences[LAST_PLAYED_KEY]?.ifBlank { null }
        return LibraryState(
            favorites = favorites,
            recents = recents,
            lastPlayedStationId = lastPlayed,
            sleepTimerMinutes = preferences[SLEEP_TIMER_KEY]?.toIntOrNull()
        )
    }

    private fun decodeStations(raw: String?): List<Station> {
        if (raw.isNullOrBlank()) return emptyList()
        return runCatching {
            json.decodeFromString<List<Station>>(raw)
        }.getOrDefault(emptyList())
    }

    companion object {
        private val FAVORITES_KEY = stringPreferencesKey("favorites")
        private val RECENTS_KEY = stringPreferencesKey("recents")
        private val LAST_PLAYED_KEY = stringPreferencesKey("last_played_station_id")
        private val SLEEP_TIMER_KEY = stringPreferencesKey("sleep_timer_minutes")
    }
}
