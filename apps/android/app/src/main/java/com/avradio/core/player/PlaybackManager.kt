package com.avradio.core.player

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.MediaSession
import com.avradio.core.model.Station
import com.avradio.core.model.displayArtworkUrl
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.SupervisorJob
import okhttp3.OkHttpClient

object PlaybackManager {
    private lateinit var appContext: Context
    private var initialized = false
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val artworkResolver = TrackArtworkResolver(OkHttpClient())
    private var sleepTimerJob: Job? = null

    private val _state = MutableStateFlow(PlayerState())
    val state: StateFlow<PlayerState> = _state.asStateFlow()

    lateinit var player: ExoPlayer
        private set

    lateinit var mediaSession: MediaSession
        private set

    val controller = PlaybackController()

    fun initialize(context: Context) {
        if (initialized) return
        initialized = true
        appContext = context.applicationContext

        player = ExoPlayer.Builder(appContext).build().apply {
            addListener(object : Player.Listener {
                override fun onIsPlayingChanged(isPlaying: Boolean) {
                    _state.value = _state.value.copy(
                        isPlaying = isPlaying,
                        isBuffering = false
                    )
                }

                override fun onPlaybackStateChanged(playbackState: Int) {
                    _state.value = _state.value.copy(
                        isBuffering = playbackState == Player.STATE_BUFFERING
                    )
                }

                override fun onMediaMetadataChanged(mediaMetadata: MediaMetadata) {
                    val parsed = PlaybackLogic.parseMetadata(mediaMetadata)
                    val station = _state.value.currentStation
                    val fallbackArtwork = station?.displayArtworkUrl

                    _state.value = _state.value.copy(
                        currentTrackTitle = parsed.title,
                        currentTrackArtist = parsed.artist,
                        currentArtworkUrl = _state.value.currentArtworkUrl ?: fallbackArtwork
                    )

                    if (parsed.artist != null && parsed.title != null) {
                        resolveArtworkAsync(parsed.artist, parsed.title, fallbackArtwork)
                    }
                }

                override fun onPlayerError(error: PlaybackException) {
                    _state.value = _state.value.copy(
                        isPlaying = false,
                        isBuffering = false,
                        errorMessage = error.errorCodeName
                    )
                }
            })
        }

        mediaSession = MediaSession.Builder(appContext, player)
            .setId("avradio-playback-session")
            .build()
    }

    fun play(station: Station, queue: List<Station> = listOf(station)) {
        ensureInitialized()
        startPlaybackService()

        val sameStation = _state.value.currentStation?.id == station.id
        if (sameStation && player.isPlaying) {
            pause()
            return
        }

        val mediaItem = MediaItem.Builder()
            .setUri(station.streamUrl)
            .setMediaId(station.id)
            .setMediaMetadata(
                MediaMetadata.Builder()
                    .setTitle(station.name)
                    .setArtist(station.primaryDetail())
                    .setStation(station.name)
                    .build()
            )
            .build()

        val sanitizedQueue = PlaybackLogic.sanitizeQueue(queue, station)
        _state.value = _state.value.copy(
            currentStation = station,
            isPlaying = false,
            isBuffering = true,
            errorMessage = null,
            currentTrackTitle = null,
            currentTrackArtist = null,
            currentTrackAlbumTitle = null,
            currentArtworkUrl = station.displayArtworkUrl,
            queue = sanitizedQueue,
            canCycleQueue = sanitizedQueue.size > 1
        )
        player.setMediaItem(mediaItem)
        player.prepare()
        player.playWhenReady = true
    }

    fun togglePlayback() {
        ensureInitialized()
        if (player.isPlaying) {
            pause()
        } else if (_state.value.currentStation != null) {
            startPlaybackService()
            player.play()
            _state.value = _state.value.copy(isPlaying = true, errorMessage = null)
        }
    }

    fun pause() {
        ensureInitialized()
        player.pause()
        _state.value = _state.value.copy(isPlaying = false, isBuffering = false)
    }

    fun playNextInQueue() {
        val state = _state.value
        val currentStation = state.currentStation ?: return
        val nextStation = PlaybackLogic.nextStation(state.queue, currentStation) ?: return
        play(nextStation, state.queue)
    }

    fun playPreviousInQueue() {
        val state = _state.value
        val currentStation = state.currentStation ?: return
        val previousStation = PlaybackLogic.previousStation(state.queue, currentStation) ?: return
        play(previousStation, state.queue)
    }

    fun setSleepTimer(minutes: Int?) {
        sleepTimerJob?.cancel()
        _state.value = _state.value.copy(
            sleepTimerDescription = minutes?.let { "Sleep in ${it}m" }
        )
        if (minutes == null) return

        sleepTimerJob = scope.launch {
            delay(minutes * 60L * 1000L)
            stop()
            _state.value = _state.value.copy(sleepTimerDescription = "Sleep timer ended")
        }
    }

    fun stop() {
        ensureInitialized()
        player.pause()
        player.clearMediaItems()
        sleepTimerJob?.cancel()
        _state.value = PlayerState()
    }

    fun release() {
        if (!initialized) return
        sleepTimerJob?.cancel()
        mediaSession.release()
        player.release()
    }

    private fun startPlaybackService() {
        val intent = Intent(appContext, PlaybackService::class.java)
        ContextCompat.startForegroundService(appContext, intent)
    }

    private fun resolveArtworkAsync(artist: String, title: String, fallbackArtwork: String?) {
        scope.launch(Dispatchers.IO) {
            val artwork = artworkResolver.resolveArtwork(artist, title)
            launch(Dispatchers.Main.immediate) {
                _state.value = _state.value.copy(
                    currentTrackAlbumTitle = artwork?.albumTitle,
                    currentArtworkUrl = artwork?.artworkUrl ?: fallbackArtwork ?: _state.value.currentArtworkUrl
                )
            }
        }
    }

    private fun ensureInitialized() {
        check(initialized) { "PlaybackManager must be initialized from Application" }
    }
}

class PlaybackController internal constructor() {
    val state: StateFlow<PlayerState> = PlaybackManager.state

    fun play(station: Station, queue: List<Station> = listOf(station)) {
        PlaybackManager.play(station, queue)
    }

    fun togglePlayback() {
        PlaybackManager.togglePlayback()
    }

    fun playNextInQueue() {
        PlaybackManager.playNextInQueue()
    }

    fun playPreviousInQueue() {
        PlaybackManager.playPreviousInQueue()
    }

    fun setSleepTimer(minutes: Int?) {
        PlaybackManager.setSleepTimer(minutes)
    }
}

internal fun Station.primaryDetail(): String {
    val pieces = listOfNotNull(
        state?.takeIf { it.isNotBlank() },
        country.takeIf { it.isNotBlank() },
        language.takeIf { it.isNotBlank() }
    )
    return pieces.joinToString(" · ").ifBlank { "Live radio" }
}
