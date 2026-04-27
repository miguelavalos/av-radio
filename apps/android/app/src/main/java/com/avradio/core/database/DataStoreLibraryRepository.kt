package com.avradio.core.database

import android.content.Context
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.emptyPreferences
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStoreFile
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import com.avradio.core.access.AccessRepository
import com.avradio.core.model.Station
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.IOException

class DataStoreLibraryRepository(
    context: Context,
    accessRepository: AccessRepository? = null,
    private val appDataService: AVRadioAppDataService? = null,
    private val json: Json = Json { ignoreUnknownKeys = true }
) : LibraryRepository {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val dataStore = PreferenceDataStoreFactory.create(
        scope = scope,
        produceFile = { context.preferencesDataStoreFile("avradio_library.preferences_pb") }
    )
    private var canUseCloudSync = false
    private var isApplyingRemoteSnapshot = false
    private var pushJob: Job? = null

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
                .map(::preferencesToSnapshot)
                .map { snapshot -> snapshot.toLibraryState() }
                .collect { _state.value = it }
        }

        if (accessRepository != null && appDataService != null) {
            scope.launch {
                accessRepository.state
                    .map { it.capabilities.canUseCloudSync }
                    .distinctUntilChanged()
                    .collect { enabled ->
                        canUseCloudSync = enabled
                        if (enabled) {
                            refreshCloudLibraryIfNeeded()
                        }
                    }
            }
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
        val currentSnapshot = preferencesToSnapshot(dataStore.data.first())
        val now = AVRadioAppDataService.isoString(AVRadioAppDataService.nowMillis())

        persistSnapshot(
            AVRadioLibrarySnapshot(
                favorites = currentSnapshot.favorites,
                recents = updatedRecents.map { recent ->
                    RecentStationRecord(
                        station = recent.appDataRecord,
                        lastPlayedAt = if (recent.id == station.id) {
                            now
                        } else {
                            currentSnapshot.recents
                                .firstOrNull { it.station.id == recent.id }
                                ?.lastPlayedAt
                                ?: now
                        }
                    )
                },
                settings = currentSnapshot.settings.copy(
                    lastPlayedStationID = station.id,
                    sleepTimerMinutes = current.sleepTimerMinutes,
                    updatedAt = now
                )
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
        val snapshot = stateToSnapshot(next, preferencesToSnapshot(dataStore.data.first()))
        persistSnapshot(snapshot)
    }

    private suspend fun persistSnapshot(snapshot: AVRadioLibrarySnapshot) {
        dataStore.edit { prefs ->
            prefs[LIBRARY_SNAPSHOT_KEY] = json.encodeToString(snapshot)
            prefs[FAVORITES_KEY] = json.encodeToString(snapshot.favorites.map { Station(it.station) })
            prefs[RECENTS_KEY] = json.encodeToString(snapshot.recents.map { Station(it.station) })
            prefs[LAST_PLAYED_KEY] = snapshot.settings.lastPlayedStationID.orEmpty()
            prefs[SLEEP_TIMER_KEY] = snapshot.settings.sleepTimerMinutes?.toString().orEmpty()
        }
        scheduleCloudPushIfNeeded(snapshot)
    }

    private fun preferencesToSnapshot(preferences: Preferences): AVRadioLibrarySnapshot {
        preferences[LIBRARY_SNAPSHOT_KEY]?.let { raw ->
            runCatching { json.decodeFromString<AVRadioLibrarySnapshot>(raw) }
                .getOrNull()
                ?.let { return it }
        }

        val favorites = decodeStations(preferences[FAVORITES_KEY])
        val recents = decodeStations(preferences[RECENTS_KEY])
        val lastPlayed = preferences[LAST_PLAYED_KEY]?.ifBlank { null }
        val fallbackTimestamp = AVRadioAppDataService.isoString(AVRadioAppDataService.nowMillis())

        return AVRadioLibrarySnapshot(
            favorites = favorites.map {
                FavoriteStationRecord(
                    station = it.appDataRecord,
                    createdAt = fallbackTimestamp
                )
            },
            recents = recents.map {
                RecentStationRecord(
                    station = it.appDataRecord,
                    lastPlayedAt = fallbackTimestamp
                )
            },
            settings = AppSettingsRecord(
                preferredCountry = "",
                preferredLanguage = "",
                preferredTag = "",
                lastPlayedStationID = lastPlayed,
                sleepTimerMinutes = preferences[SLEEP_TIMER_KEY]?.toIntOrNull(),
                updatedAt = fallbackTimestamp
            )
        )
    }

    private fun decodeStations(raw: String?): List<Station> {
        if (raw.isNullOrBlank()) return emptyList()
        return runCatching {
            json.decodeFromString<List<Station>>(raw)
        }.getOrDefault(emptyList())
    }

    private fun AVRadioLibrarySnapshot.toLibraryState(): LibraryState = LibraryState(
        favorites = favorites.map { Station(it.station) },
        recents = recents.map { Station(it.station) },
        lastPlayedStationId = settings.lastPlayedStationID,
        sleepTimerMinutes = settings.sleepTimerMinutes
    )

    private fun stateToSnapshot(
        state: LibraryState,
        currentSnapshot: AVRadioLibrarySnapshot
    ): AVRadioLibrarySnapshot {
        val favoriteCreatedAt = currentSnapshot.favorites.associateBy({ it.station.id }, { it.createdAt })
        val recentPlayedAt = currentSnapshot.recents.associateBy({ it.station.id }, { it.lastPlayedAt })
        val now = AVRadioAppDataService.isoString(AVRadioAppDataService.nowMillis())

        return AVRadioLibrarySnapshot(
            favorites = state.favorites.map { station ->
                FavoriteStationRecord(
                    station = station.appDataRecord,
                    createdAt = favoriteCreatedAt[station.id] ?: now
                )
            },
            recents = state.recents.map { station ->
                RecentStationRecord(
                    station = station.appDataRecord,
                    lastPlayedAt = recentPlayedAt[station.id] ?: now
                )
            },
            settings = AppSettingsRecord(
                preferredCountry = currentSnapshot.settings.preferredCountry,
                preferredLanguage = currentSnapshot.settings.preferredLanguage,
                preferredTag = currentSnapshot.settings.preferredTag,
                lastPlayedStationID = state.lastPlayedStationId,
                sleepTimerMinutes = state.sleepTimerMinutes,
                updatedAt = now
            )
        )
    }

    private suspend fun refreshCloudLibraryIfNeeded() {
        val service = appDataService ?: return
        if (!canUseCloudSync || !service.isConfigured()) return

        val remoteDocument = service.pullLibrary() ?: return
        val localSnapshot = preferencesToSnapshot(dataStore.data.first())
        val localHasContent = localSnapshot.hasMeaningfulContent
        val localUpdatedAt = latestLocalUpdateAt(localSnapshot)

        val remoteSnapshot = remoteDocument.snapshot
        if (remoteSnapshot == null || !remoteSnapshot.hasMeaningfulContent) {
            if (localHasContent) {
                service.pushLibrary(localSnapshot)
            }
            return
        }

        val remoteUpdatedAt = AVRadioAppDataService.epochMillis(remoteDocument.updatedAt)
        if (!localHasContent || remoteUpdatedAt > localUpdatedAt) {
            applyRemoteSnapshot(remoteSnapshot)
            return
        }

        if (localUpdatedAt > remoteUpdatedAt) {
            service.pushLibrary(localSnapshot)
        }
    }

    private fun latestLocalUpdateAt(snapshot: AVRadioLibrarySnapshot): Long {
        val timestamps = buildList {
            add(AVRadioAppDataService.epochMillis(snapshot.settings.updatedAt))
            addAll(snapshot.favorites.map { AVRadioAppDataService.epochMillis(it.createdAt) })
            addAll(snapshot.recents.map { AVRadioAppDataService.epochMillis(it.lastPlayedAt) })
        }

        return timestamps.maxOrNull() ?: 0L
    }

    private suspend fun applyRemoteSnapshot(snapshot: AVRadioLibrarySnapshot) {
        isApplyingRemoteSnapshot = true
        try {
            persistSnapshot(snapshot)
        } finally {
            isApplyingRemoteSnapshot = false
        }
    }

    private fun scheduleCloudPushIfNeeded(snapshot: AVRadioLibrarySnapshot) {
        val service = appDataService ?: return
        if (isApplyingRemoteSnapshot || !canUseCloudSync || !service.isConfigured()) {
            return
        }

        pushJob?.cancel()
        pushJob = scope.launch {
            service.pushLibrary(snapshot)
        }
    }

    companion object {
        private val LIBRARY_SNAPSHOT_KEY = stringPreferencesKey("library_snapshot")
        private val FAVORITES_KEY = stringPreferencesKey("favorites")
        private val RECENTS_KEY = stringPreferencesKey("recents")
        private val LAST_PLAYED_KEY = stringPreferencesKey("last_played_station_id")
        private val SLEEP_TIMER_KEY = stringPreferencesKey("sleep_timer_minutes")
    }
}
