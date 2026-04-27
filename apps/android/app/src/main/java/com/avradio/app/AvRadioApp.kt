package com.avradio.app

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.Image
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Logout
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.FastForward
import androidx.compose.material.icons.filled.FastRewind
import androidx.compose.material3.AssistChip
import androidx.compose.material3.AssistChipDefaults
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledIconButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TextButton
import androidx.compose.material3.ListItem
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.platform.LocalUriHandler
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import coil3.compose.AsyncImage
import coil3.compose.SubcomposeAsyncImage
import com.clerk.api.Clerk
import com.clerk.ui.auth.AuthView
import com.avradio.R
import com.avradio.core.access.AccessMode
import com.avradio.core.access.AccessRepository
import com.avradio.core.access.AccessState
import com.avradio.core.database.LibraryRepository
import com.avradio.core.database.LibraryState
import com.avradio.core.model.Station
import com.avradio.core.model.displayArtworkUrl
import com.avradio.core.model.initials
import com.avradio.core.network.HomeUiState
import com.avradio.core.network.SearchUiState
import com.avradio.core.network.StationRepository
import com.avradio.core.network.StationSearchFilters
import com.avradio.core.network.StationsViewModel
import com.avradio.core.player.PlaybackController
import com.avradio.core.player.PlayerState
import kotlinx.coroutines.launch

private enum class ShellTab {
    HOME,
    SEARCH,
    LIBRARY,
    PROFILE
}

@Composable
private fun rememberClerkInitializedState(): Boolean {
    return if (AppConfig.isClerkAuthAvailable) {
        val initialized by Clerk.isInitialized.collectAsStateWithLifecycle(initialValue = false)
        initialized
    } else {
        false
    }
}

@Composable
fun AvRadioApp(
    accessRepository: AccessRepository,
    stationRepository: StationRepository,
    libraryRepository: LibraryRepository,
    playerController: PlaybackController
) {
    val uriHandler = LocalUriHandler.current
    val viewModel: StationsViewModel = viewModel(
        factory = StationsViewModel.factory(stationRepository)
    )
    val accessState by accessRepository.state.collectAsStateWithLifecycle()
    val homeState by viewModel.homeState.collectAsStateWithLifecycle()
    val searchState by viewModel.searchState.collectAsStateWithLifecycle()
    val playerState by playerController.state.collectAsStateWithLifecycle()
    val libraryState by libraryRepository.state.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()
    val clerkIsInitialized = rememberClerkInitializedState()

    var selectedTab by rememberSaveable { mutableStateOf(ShellTab.HOME) }
    var searchQuery by rememberSaveable { mutableStateOf("") }
    var activeTag by rememberSaveable { mutableStateOf<String?>(null) }
    var isShowingNowPlaying by rememberSaveable { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        viewModel.loadHome()
    }

    LaunchedEffect(searchQuery, activeTag) {
        viewModel.search(
            StationSearchFilters(
                query = searchQuery,
                tag = activeTag,
                allowsEmptySearch = true
            )
        )
    }

    if (!accessState.onboardingSeen) {
        OnboardingScreen(
            authProvider = AppConfig.authProvider,
            isClerkAuthAvailable = AppConfig.isClerkAuthAvailable,
            isClerkInitialized = clerkIsInitialized,
            onContinueGuest = {
                scope.launch { accessRepository.continueAsGuest() }
            },
            onConnectDemo = {
                scope.launch {
                    accessRepository.completeOnboarding()
                    accessRepository.signInDemo()
                }
            },
            onOpenWebAuth = {
                AppConfig.authWebUrl?.let(uriHandler::openUri)
            },
            onOpenTerms = {
                AppConfig.termsUrl?.let(uriHandler::openUri)
            },
            onOpenPrivacy = {
                AppConfig.privacyUrl?.let(uriHandler::openUri)
            }
        )
        return
    }

    Scaffold(
        containerColor = Color.Transparent,
        topBar = {
            ShellTopBar(selectedTab = selectedTab)
        },
        bottomBar = {
            Column {
                PlayerStrip(
                    state = playerState,
                    onPlayPause = { playerController.togglePlayback() },
                    onNext = { playerController.playNextInQueue() },
                    onPrevious = { playerController.playPreviousInQueue() },
                    onOpen = { if (playerState.currentStation != null) isShowingNowPlaying = true }
                )
                ShellBottomBar(
                    selectedTab = selectedTab,
                    onSelect = { selectedTab = it }
                )
            }
        }
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        colors = listOf(
                            MaterialTheme.colorScheme.background,
                            MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.55f)
                        )
                    )
                )
                .padding(innerPadding)
        ) {
            when (selectedTab) {
                ShellTab.HOME -> HomeScreen(
                    state = homeState,
                    libraryState = libraryState,
                    onTagSelected = {
                        activeTag = it
                        selectedTab = ShellTab.SEARCH
                    },
                    onStationPlay = { station, queue ->
                        playerController.play(station, queue)
                        scope.launch { libraryRepository.recordPlayback(station) }
                    },
                    onToggleFavorite = { station ->
                        scope.launch { libraryRepository.toggleFavorite(station) }
                    }
                )

                ShellTab.SEARCH -> SearchScreen(
                    query = searchQuery,
                    activeTag = activeTag,
                    state = searchState,
                    libraryState = libraryState,
                    onQueryChange = { searchQuery = it },
                    onTagSelected = { activeTag = if (activeTag == it) null else it },
                    onStationPlay = { station, queue ->
                        playerController.play(station, queue)
                        scope.launch { libraryRepository.recordPlayback(station) }
                    },
                    onToggleFavorite = { station ->
                        scope.launch { libraryRepository.toggleFavorite(station) }
                    }
                )

                ShellTab.LIBRARY -> LibraryScreen(
                    libraryState = libraryState,
                    onStationPlay = { station, queue ->
                        playerController.play(station, queue)
                        scope.launch { libraryRepository.recordPlayback(station) }
                    },
                    onToggleFavorite = { station ->
                        scope.launch { libraryRepository.toggleFavorite(station) }
                    }
                )
                ShellTab.PROFILE -> ProfileScreen(
                    authProvider = AppConfig.authProvider,
                    isClerkAuthAvailable = AppConfig.isClerkAuthAvailable,
                    isClerkInitialized = clerkIsInitialized,
                    isWebAuthAvailable = AppConfig.isWebAuthAvailable,
                    accessState = accessState,
                    libraryState = libraryState,
                    onConnectDemo = {
                        scope.launch { accessRepository.signInDemo() }
                    },
                    onOpenWebAuth = {
                        AppConfig.authWebUrl?.let(uriHandler::openUri)
                    },
                    onOpenStationDataSource = {
                        uriHandler.openUri("https://www.radio-browser.info/")
                    },
                    onOpenManageAccount = {
                        AppConfig.accountManagementUrl?.let(uriHandler::openUri)
                    },
                    onOpenSupport = {
                        AppConfig.supportUrl?.let(uriHandler::openUri)
                    },
                    onOpenTerms = {
                        AppConfig.termsUrl?.let(uriHandler::openUri)
                    },
                    onOpenPrivacy = {
                        AppConfig.privacyUrl?.let(uriHandler::openUri)
                    },
                    onEnablePro = {
                        scope.launch { accessRepository.enableProDemo() }
                    },
                    onDisablePro = {
                        scope.launch { accessRepository.disableProDemo() }
                    },
                    onSignOut = {
                        scope.launch { accessRepository.signOut() }
                    },
                    onClearLocalData = {
                        scope.launch { libraryRepository.clear() }
                    },
                    onSetSleepTimer = { minutes ->
                        scope.launch { libraryRepository.setSleepTimerMinutes(minutes) }
                        playerController.setSleepTimer(minutes)
                    }
                )
            }

            if (isShowingNowPlaying && playerState.currentStation != null) {
                NowPlayingScreen(
                    state = playerState,
                    libraryState = libraryState,
                    onClose = { isShowingNowPlaying = false },
                    onPlayPause = { playerController.togglePlayback() },
                    onNext = { playerController.playNextInQueue() },
                    onPrevious = { playerController.playPreviousInQueue() },
                    onPlayFromQueue = { station ->
                        playerController.play(station, playerState.queue.ifEmpty { listOf(station) })
                        scope.launch { libraryRepository.recordPlayback(station) }
                    },
                    onToggleFavorite = { station ->
                        scope.launch { libraryRepository.toggleFavorite(station) }
                    },
                    onSetSleepTimer = { minutes ->
                        scope.launch { libraryRepository.setSleepTimerMinutes(minutes) }
                        playerController.setSleepTimer(minutes)
                    }
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ShellTopBar(selectedTab: ShellTab) {
    TopAppBar(
        title = {
            Column {
                Text(
                    text = "AV Radio",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = when (selectedTab) {
                        ShellTab.HOME -> "Android home"
                        ShellTab.SEARCH -> "Live search"
                        ShellTab.LIBRARY -> "Saved stations"
                        ShellTab.PROFILE -> "Account"
                    },
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    )
}

@Composable
private fun ShellBottomBar(
    selectedTab: ShellTab,
    onSelect: (ShellTab) -> Unit
) {
    NavigationBar {
        NavigationBarItem(
            selected = selectedTab == ShellTab.HOME,
            onClick = { onSelect(ShellTab.HOME) },
            icon = { Icon(Icons.Filled.Home, contentDescription = null) },
            label = { Text(text = "Home") }
        )
        NavigationBarItem(
            selected = selectedTab == ShellTab.SEARCH,
            onClick = { onSelect(ShellTab.SEARCH) },
            icon = { Icon(Icons.Filled.Search, contentDescription = null) },
            label = { Text(text = "Search") }
        )
        NavigationBarItem(
            selected = selectedTab == ShellTab.LIBRARY,
            onClick = { onSelect(ShellTab.LIBRARY) },
            icon = { Icon(Icons.Filled.Star, contentDescription = null) },
            label = { Text(text = "Library") }
        )
        NavigationBarItem(
            selected = selectedTab == ShellTab.PROFILE,
            onClick = { onSelect(ShellTab.PROFILE) },
            icon = { Icon(Icons.Filled.Person, contentDescription = null) },
            label = { Text(text = "Profile") }
        )
    }
}

@Composable
private fun HomeScreen(
    state: HomeUiState,
    libraryState: LibraryState,
    onTagSelected: (String) -> Unit,
    onStationPlay: (Station, List<Station>) -> Unit,
    onToggleFavorite: (Station) -> Unit
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = "Discover live radio",
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = "Popular stations and quick genre jumps for the Android build.",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        item {
            GenreSection(onTagSelected = onTagSelected)
        }

        if (libraryState.recents.isNotEmpty()) {
            item {
                SectionHeader(
                    title = "Recently played",
                    detail = "Quick return to the stations you opened most recently."
                )
            }
            items(libraryState.recents.take(6), key = { it.id }) { station ->
                StationCard(
                    station = station,
                    isFavorite = libraryState.isFavorite(station),
                    onPlay = { onStationPlay(station, libraryState.recents.take(6)) },
                    onToggleFavorite = { onToggleFavorite(station) }
                )
            }
        }

        if (libraryState.favorites.isNotEmpty()) {
            item {
                SectionHeader(
                    title = "Favorites",
                    detail = "Saved stations stay here on device."
                )
            }
            items(libraryState.favorites.take(6), key = { "favorite-${it.id}" }) { station ->
                StationCard(
                    station = station,
                    isFavorite = true,
                    onPlay = { onStationPlay(station, libraryState.favorites.take(6)) },
                    onToggleFavorite = { onToggleFavorite(station) }
                )
            }
        }

        if (state.isLoading && state.stations.isEmpty()) {
            item {
                LoadingCard()
            }
        }

        state.errorMessage?.let { error ->
            item {
                MessageCard(title = "Could not load stations", detail = error)
            }
        }

        items(state.stations, key = { it.id }) { station ->
            StationCard(
                station = station,
                isFavorite = libraryState.isFavorite(station),
                onPlay = { onStationPlay(station, state.stations) },
                onToggleFavorite = { onToggleFavorite(station) }
            )
        }
    }
}

@Composable
private fun SearchScreen(
    query: String,
    activeTag: String?,
    state: SearchUiState,
    libraryState: LibraryState,
    onQueryChange: (String) -> Unit,
    onTagSelected: (String) -> Unit,
    onStationPlay: (Station, List<Station>) -> Unit,
    onToggleFavorite: (Station) -> Unit
) {
    val scope = rememberCoroutineScope()
    val listState = rememberLazyListState()

    LaunchedEffect(state.stations.size) {
        if (state.stations.isNotEmpty()) {
            scope.launch {
                listState.animateScrollToItem(0)
            }
        }
    }

    LazyColumn(
        state = listState,
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = "Search stations",
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = "Search by name, genre, or browse a popular tag.",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        item {
            OutlinedTextField(
                value = query,
                onValueChange = onQueryChange,
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                shape = RoundedCornerShape(20.dp),
                label = { Text("Search for a station") }
            )
        }

        item {
            GenreSection(
                activeTag = activeTag,
                onTagSelected = onTagSelected
            )
        }

        if (state.isLoading && state.stations.isEmpty()) {
            item {
                LoadingCard()
            }
        }

        state.errorMessage?.let { error ->
            item {
                MessageCard(title = "Could not load stations", detail = error)
            }
        }

        if (!state.isLoading && state.stations.isEmpty() && state.errorMessage == null) {
            item {
                MessageCard(
                    title = "No stations yet",
                    detail = "Try a different term or browse by one of the featured tags."
                )
            }
        }

        items(state.stations, key = { it.id }) { station ->
            StationCard(
                station = station,
                isFavorite = libraryState.isFavorite(station),
                onPlay = { onStationPlay(station, state.stations) },
                onToggleFavorite = { onToggleFavorite(station) }
            )
        }
    }
}

@Composable
private fun LibraryScreen(
    libraryState: LibraryState,
    onStationPlay: (Station, List<Station>) -> Unit,
    onToggleFavorite: (Station) -> Unit
) {
    var query by rememberSaveable { mutableStateOf("") }
    val trimmedQuery = query.trim()
    val favorites = libraryState.favorites.filter { it.matchesQuery(trimmedQuery) }
    val recents = libraryState.recents.filter { it.matchesQuery(trimmedQuery) }

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = "Your library",
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = "Favorites and recently played stations are stored on this device.",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        item {
            OutlinedTextField(
                value = query,
                onValueChange = { query = it },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                shape = RoundedCornerShape(20.dp),
                label = { Text("Filter your library") }
            )
        }

        item {
            SectionHeader(
                title = "Favorites",
                detail = if (libraryState.favorites.isEmpty()) {
                    "Nothing saved yet."
                } else {
                    "${libraryState.favorites.size} saved station(s)"
                }
            )
        }

        if (favorites.isEmpty()) {
            item {
                MessageCard(
                    title = if (libraryState.favorites.isEmpty()) "No favorites yet" else "No matching favorites",
                    detail = if (libraryState.favorites.isEmpty()) {
                        "Use the star button on Home or Search to save stations."
                    } else {
                        "Try a different filter term."
                    }
                )
            }
        } else {
            items(favorites, key = { "library-favorite-${it.id}" }) { station ->
                StationCard(
                    station = station,
                    isFavorite = true,
                    onPlay = { onStationPlay(station, favorites) },
                    onToggleFavorite = { onToggleFavorite(station) }
                )
            }
        }

        if (libraryState.recents.isNotEmpty()) {
            item {
                SectionHeader(
                    title = "Recently played",
                    detail = "The latest 20 stations you opened."
                )
            }
            items(recents, key = { "library-recent-${it.id}" }) { station ->
                StationCard(
                    station = station,
                    isFavorite = libraryState.isFavorite(station),
                    onPlay = { onStationPlay(station, recents) },
                    onToggleFavorite = { onToggleFavorite(station) }
                )
            }
        }
    }
}

@Composable
private fun GenreSection(
    activeTag: String? = null,
    onTagSelected: (String) -> Unit
) {
    val tags = remember {
        listOf("rock", "pop", "jazz", "news", "electronic", "ambient")
    }

    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(
            text = "Browse by genre",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold
        )
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            tags.forEach { tag ->
                AssistChip(
                    onClick = { onTagSelected(tag) },
                    label = { Text(tag.replaceFirstChar { it.uppercase() }) },
                    colors = if (tag == activeTag) {
                        AssistChipDefaults.assistChipColors(
                            containerColor = MaterialTheme.colorScheme.primary,
                            labelColor = MaterialTheme.colorScheme.onPrimary
                        )
                    } else {
                        AssistChipDefaults.assistChipColors()
                    }
                )
            }
        }
    }
}

@Composable
private fun StationCard(
    station: Station,
    isFavorite: Boolean,
    onPlay: () -> Unit,
    onToggleFavorite: () -> Unit
) {
    Card(
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.95f)
        ),
        shape = RoundedCornerShape(24.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(18.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            StationArtwork(station = station, modifier = Modifier.size(56.dp))
            Spacer(modifier = Modifier.size(14.dp))
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Text(
                    text = station.name,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Text(
                    text = station.primaryDetail(),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                station.displayTags()?.let { tags ->
                    Text(
                        text = tags,
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.primary,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }
            IconButton(onClick = onToggleFavorite) {
                Icon(
                    imageVector = Icons.Filled.Star,
                    contentDescription = if (isFavorite) "Remove favorite" else "Save favorite",
                    tint = if (isFavorite) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outline
                )
            }
            FilledIconButton(onClick = onPlay) {
                Icon(Icons.Filled.PlayArrow, contentDescription = "Play")
            }
        }
    }
}

@Composable
private fun StationArtwork(
    station: Station,
    modifier: Modifier = Modifier,
    cornerRadius: Dp = 18.dp,
    artworkPadding: Dp = 8.dp
) {
    ArtworkTile(
        artworkUrl = station.displayArtworkUrl,
        fallbackLabel = station.initials,
        modifier = modifier,
        cornerRadius = cornerRadius,
        artworkPadding = artworkPadding
    )
}

@Composable
private fun ArtworkTile(
    artworkUrl: String?,
    fallbackLabel: String,
    modifier: Modifier = Modifier,
    cornerRadius: Dp = 18.dp,
    artworkPadding: Dp = 8.dp
) {
    val shape = RoundedCornerShape(cornerRadius)

    Box(
        modifier = modifier
            .shadow(10.dp, shape, clip = false)
            .clip(shape)
            .background(
                Brush.linearGradient(
                    colors = listOf(
                        Color.White,
                        MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.72f)
                    )
                )
            ),
        contentAlignment = Alignment.Center
    ) {
        Box(
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .sizeIn(minWidth = 24.dp, minHeight = 24.dp)
                .offset(x = 12.dp, y = 12.dp)
                .clip(CircleShape)
                .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.08f))
        )

        if (artworkUrl.isNullOrBlank()) {
            ArtworkFallback(fallbackLabel = fallbackLabel)
        } else {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(artworkPadding)
                    .clip(RoundedCornerShape(cornerRadius * 0.75f))
                    .background(Color.White.copy(alpha = 0.92f)),
                contentAlignment = Alignment.Center
            ) {
                SubcomposeAsyncImage(
                    model = artworkUrl,
                    contentDescription = null,
                    loading = { ArtworkFallback(fallbackLabel = fallbackLabel) },
                    error = { ArtworkFallback(fallbackLabel = fallbackLabel) },
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Fit
                )
            }
        }
    }
}

@Composable
private fun ArtworkFallback(fallbackLabel: String) {
    Box(contentAlignment = Alignment.Center) {
        Box(
            modifier = Modifier
                .size(34.dp)
                .clip(CircleShape)
                .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.16f))
        )
        Image(
            painter = painterResource(id = R.drawable.brand_mark),
            contentDescription = fallbackLabel,
            modifier = Modifier.size(54.dp),
            contentScale = ContentScale.Fit
        )
    }
}

@Composable
private fun PlayerStrip(
    state: PlayerState,
    onPlayPause: () -> Unit,
    onNext: () -> Unit,
    onPrevious: () -> Unit,
    onOpen: () -> Unit
) {
    Surface(
        tonalElevation = 8.dp,
        color = MaterialTheme.colorScheme.surface.copy(alpha = 0.98f)
    ) {
        if (state.currentStation == null) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    modifier = Modifier
                        .size(12.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.outlineVariant)
                )
                Spacer(modifier = Modifier.size(12.dp))
                Column {
                    Text(
                        text = "Playback idle",
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = FontWeight.SemiBold
                    )
                    Text(
                        text = "Pick a station from Home or Search.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        } else {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable(onClick = onOpen)
                    .padding(horizontal = 20.dp, vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                PlayerArtwork(state = state)
                Spacer(modifier = Modifier.size(12.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = state.currentTrackTitle ?: state.currentStation.name,
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = FontWeight.Bold,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    Text(
                        text = when {
                            state.isBuffering -> "Buffering stream..."
                            state.errorMessage != null -> state.errorMessage
                            state.sleepTimerDescription != null -> state.sleepTimerDescription
                            state.currentTrackArtist != null -> buildString {
                                append(state.currentTrackArtist)
                                state.currentTrackAlbumTitle?.takeIf { it.isNotBlank() }?.let {
                                    append(" · ")
                                    append(it)
                                }
                            }
                            state.isPlaying -> "Now playing"
                            else -> state.currentStation.primaryDetail()
                        },
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
                if (state.canCycleQueue) {
                    IconButton(onClick = onPrevious) {
                        Icon(Icons.Filled.FastRewind, contentDescription = "Previous")
                    }
                }
                IconButton(onClick = onPlayPause) {
                    Icon(
                        imageVector = if (state.isPlaying) Icons.Filled.Pause else Icons.Filled.PlayArrow,
                        contentDescription = if (state.isPlaying) "Pause" else "Play"
                    )
                }
                if (state.canCycleQueue) {
                    IconButton(onClick = onNext) {
                        Icon(Icons.Filled.FastForward, contentDescription = "Next")
                    }
                }
            }
        }
    }
}

@Composable
private fun PlayerArtwork(state: PlayerState) {
    val station = state.currentStation
    if (station != null) {
        ArtworkTile(
            artworkUrl = state.currentArtworkUrl ?: station.displayArtworkUrl,
            fallbackLabel = station.initials,
            modifier = Modifier.size(52.dp),
            cornerRadius = 16.dp,
            artworkPadding = 7.dp
        )
    }
}

@Composable
private fun NowPlayingScreen(
    state: PlayerState,
    libraryState: LibraryState,
    onClose: () -> Unit,
    onPlayPause: () -> Unit,
    onNext: () -> Unit,
    onPrevious: () -> Unit,
    onPlayFromQueue: (Station) -> Unit,
    onToggleFavorite: (Station) -> Unit,
    onSetSleepTimer: (Int?) -> Unit
) {
    val currentStation = state.currentStation ?: return

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background.copy(alpha = 0.98f))
    ) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(24.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    TextButton(onClick = onClose) {
                        Text("Close")
                    }
                    Text(
                        text = "Now Playing",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold
                    )
                    Spacer(modifier = Modifier.size(56.dp))
                }
            }

            item {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    contentAlignment = Alignment.Center
                ) {
                    ArtworkTile(
                        artworkUrl = state.currentArtworkUrl ?: currentStation.displayArtworkUrl,
                        fallbackLabel = currentStation.initials,
                        modifier = Modifier
                            .fillMaxWidth(0.72f)
                            .aspectRatio(1f),
                        cornerRadius = 30.dp,
                        artworkPadding = 20.dp
                    )
                }
            }

            item {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        text = state.currentTrackTitle ?: currentStation.name,
                        style = MaterialTheme.typography.headlineMedium,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        text = when {
                            state.currentTrackArtist != null && state.currentTrackAlbumTitle != null ->
                                "${state.currentTrackArtist} · ${state.currentTrackAlbumTitle}"
                            state.currentTrackArtist != null -> state.currentTrackArtist
                            else -> currentStation.primaryDetail()
                        },
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        text = currentStation.displayTags() ?: "Live radio",
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.primary
                    )
                }
            }

            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceEvenly,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    IconButton(
                        onClick = onPrevious,
                        enabled = state.canCycleQueue
                    ) {
                        Icon(Icons.Filled.FastRewind, contentDescription = "Previous")
                    }
                    FilledIconButton(
                        onClick = onPlayPause,
                        modifier = Modifier.size(72.dp)
                    ) {
                        Icon(
                            imageVector = if (state.isPlaying) Icons.Filled.Pause else Icons.Filled.PlayArrow,
                            contentDescription = if (state.isPlaying) "Pause" else "Play"
                        )
                    }
                    IconButton(
                        onClick = onNext,
                        enabled = state.canCycleQueue
                    ) {
                        Icon(Icons.Filled.FastForward, contentDescription = "Next")
                    }
                }
            }

            item {
                ProfileCard(
                    title = "Playback",
                    detail = state.sleepTimerDescription ?: if (state.isBuffering) "Buffering stream..." else "Live stream ready"
                ) {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        CapabilityRow("Queue items", state.queue.isNotEmpty())
                        CapabilityRow("Can cycle queue", state.canCycleQueue)
                        CapabilityRow("Favorite", libraryState.isFavorite(currentStation))
                        OutlinedButton(onClick = { onToggleFavorite(currentStation) }, modifier = Modifier.fillMaxWidth()) {
                            Text(if (libraryState.isFavorite(currentStation)) "Remove favorite" else "Save favorite")
                        }
                        SleepTimerButtons(
                            selectedMinutes = libraryState.sleepTimerMinutes,
                            onSelect = onSetSleepTimer
                        )
                    }
                }
            }

            if (state.queue.isNotEmpty()) {
                item {
                    SectionHeader(
                        title = "Queue",
                        detail = "Tap any station to jump within the current playback queue."
                    )
                }
                items(state.queue, key = { "queue-${it.id}" }) { station ->
                    StationCard(
                        station = station,
                        isFavorite = libraryState.isFavorite(station),
                        onPlay = { onPlayFromQueue(station) },
                        onToggleFavorite = { onToggleFavorite(station) }
                    )
                }
            }
        }
    }
}

@Composable
private fun LoadingCard() {
    Card(shape = RoundedCornerShape(24.dp)) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            CircularProgressIndicator(modifier = Modifier.size(22.dp), strokeWidth = 2.5.dp)
            Spacer(modifier = Modifier.size(14.dp))
            Text(
                text = "Loading stations...",
                style = MaterialTheme.typography.bodyLarge
            )
        }
    }
}

@Composable
private fun MessageCard(title: String, detail: String) {
    Card(shape = RoundedCornerShape(24.dp)) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(text = title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            HorizontalDivider()
            Text(
                text = detail,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun SectionHeader(title: String, detail: String) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold
        )
        Text(
            text = detail,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun PlaceholderScreen(title: String, detail: String) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .padding(20.dp),
        contentAlignment = Alignment.Center
    ) {
        MessageCard(title = title, detail = detail)
    }
}

@Composable
private fun OnboardingScreen(
    authProvider: AppConfig.AuthProvider,
    isClerkAuthAvailable: Boolean,
    isClerkInitialized: Boolean,
    onContinueGuest: () -> Unit,
    onConnectDemo: () -> Unit,
    onOpenWebAuth: () -> Unit,
    onOpenTerms: () -> Unit,
    onOpenPrivacy: () -> Unit
) {
    var isShowingClerkAuth by rememberSaveable { mutableStateOf(false) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    colors = listOf(
                        MaterialTheme.colorScheme.background,
                        MaterialTheme.colorScheme.primary.copy(alpha = 0.18f),
                        MaterialTheme.colorScheme.secondary.copy(alpha = 0.12f)
                    )
                )
            )
            .padding(24.dp)
    ) {
        Card(
            modifier = Modifier.align(Alignment.Center),
            shape = RoundedCornerShape(32.dp),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.96f)
            )
        ) {
            Column(
                modifier = Modifier.padding(24.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Text(
                    text = "AV Radio for Android",
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = when (authProvider) {
                        AppConfig.AuthProvider.CLERK ->
                            if (isClerkAuthAvailable) {
                                "Sign in with AV Apps Account using Clerk, like the iOS app. Apple, Google, and other enabled methods come from the Clerk dashboard."
                            } else {
                                "This build is set to use Clerk, but the publishable key is not configured yet. You can still use AV Radio locally on this device."
                            }
                        AppConfig.AuthProvider.DEMO ->
                            "Local-first radio listening with optional account state. This Android build uses a local demo account until the real backend flow is wired."
                        AppConfig.AuthProvider.WEB ->
                            "Local-first radio listening with external account handoff enabled. This build can open a web sign-in flow when configured."
                        AppConfig.AuthProvider.NONE ->
                            "Local-first radio listening with no account provider configured in this build."
                    },
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                FeatureLine("Browse live stations and stream immediately")
                FeatureLine("Save favorites and recent stations on device")
                FeatureLine(
                    when (authProvider) {
                        AppConfig.AuthProvider.CLERK ->
                            if (isClerkAuthAvailable) {
                                "Use the same AV Apps Account login stack as iOS"
                            } else {
                                "Clerk is selected for this build, but no publishable key is configured yet"
                            }
                        AppConfig.AuthProvider.DEMO -> "Try signed-in free and pro states with local demo data"
                        AppConfig.AuthProvider.WEB -> "Open the configured account sign-in page from Android"
                        AppConfig.AuthProvider.NONE -> "Use guest mode until an account provider is configured"
                    }
                )
                when (authProvider) {
                    AppConfig.AuthProvider.CLERK -> {
                        if (isClerkAuthAvailable) {
                            Button(
                                onClick = { isShowingClerkAuth = !isShowingClerkAuth },
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Text(if (isShowingClerkAuth) "Hide AV Apps Account" else "Use AV Apps Account")
                            }

                            if (isShowingClerkAuth) {
                                ClerkAuthCard(isInitialized = isClerkInitialized)
                            }
                        } else {
                            OutlinedButton(
                                onClick = {},
                                enabled = false,
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Text("Clerk not configured in this build")
                            }
                        }
                    }

                    AppConfig.AuthProvider.DEMO -> Button(
                        onClick = onConnectDemo,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Enter with demo account")
                    }

                    AppConfig.AuthProvider.WEB -> Button(
                        onClick = onOpenWebAuth,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Open sign-in page")
                    }

                    AppConfig.AuthProvider.NONE -> OutlinedButton(
                        onClick = {},
                        enabled = false,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("No account provider in this build")
                    }
                }
                OutlinedButton(
                    onClick = onContinueGuest,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text("Continue in local mode")
                }
                LegalNotice(
                    legalText = legalConsentText(),
                    onOpenTerms = onOpenTerms,
                    onOpenPrivacy = onOpenPrivacy
                )
            }
        }
    }
}

@Composable
private fun LegalNotice(
    legalText: AnnotatedString,
    onOpenTerms: () -> Unit,
    onOpenPrivacy: () -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            text = legalText,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            TextButton(onClick = onOpenTerms, enabled = AppConfig.termsUrl != null) {
                Text("Terms")
            }
            TextButton(onClick = onOpenPrivacy, enabled = AppConfig.privacyUrl != null) {
                Text("Privacy")
            }
        }
    }
}

private fun legalConsentText(): AnnotatedString = buildAnnotatedString {
    append("By continuing, you agree to the ")
    withStyle(SpanStyle(textDecoration = TextDecoration.Underline)) {
        append("Terms")
    }
    append(" and ")
    withStyle(SpanStyle(textDecoration = TextDecoration.Underline)) {
        append("Privacy Policy")
    }
    append(" of AV Radio.")
}

@Composable
private fun FeatureLine(text: String) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = Icons.Filled.CheckCircle,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.primary
        )
        Text(
            text = text,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface
        )
    }
}

@Composable
private fun ClerkAuthCard(isInitialized: Boolean) {
    Card(
        shape = RoundedCornerShape(24.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.45f)
        )
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            if (isInitialized) {
                AuthView()
            } else {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                    Text(
                        text = "Preparing AV Apps Account…",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }
}

@Composable
private fun ProfileScreen(
    authProvider: AppConfig.AuthProvider,
    isClerkAuthAvailable: Boolean,
    isClerkInitialized: Boolean,
    isWebAuthAvailable: Boolean,
    accessState: AccessState,
    libraryState: LibraryState,
    onConnectDemo: () -> Unit,
    onOpenWebAuth: () -> Unit,
    onOpenStationDataSource: () -> Unit,
    onOpenManageAccount: () -> Unit,
    onOpenSupport: () -> Unit,
    onOpenTerms: () -> Unit,
    onOpenPrivacy: () -> Unit,
    onEnablePro: () -> Unit,
    onDisablePro: () -> Unit,
    onSignOut: () -> Unit,
    onClearLocalData: () -> Unit,
    onSetSleepTimer: (Int?) -> Unit
) {
    var isShowingClerkAuth by rememberSaveable { mutableStateOf(false) }

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = "Profile",
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = "Account, plan state, and local storage controls for the Android build.",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        item {
            ProfileCard(
                title = accessState.user?.displayName ?: "Local listener",
                detail = when (accessState.mode) {
                    AccessMode.GUEST -> "Guest mode"
                    AccessMode.SIGNED_IN_FREE -> accessState.user?.emailAddress ?: "Signed in"
                    AccessMode.SIGNED_IN_PRO -> accessState.user?.emailAddress ?: "Premium"
                }
            ) {
                Text(
                    text = when (accessState.mode) {
                        AccessMode.GUEST -> "Guest"
                        AccessMode.SIGNED_IN_FREE -> "Free"
                        AccessMode.SIGNED_IN_PRO -> "Pro"
                    },
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.primary,
                    fontWeight = FontWeight.Bold
                )
            }
        }

        item {
            ProfileCard(
                title = "Auth provider",
                detail = when (authProvider) {
                    AppConfig.AuthProvider.CLERK ->
                        if (isClerkAuthAvailable) {
                            "This build uses Clerk for AV Apps Account, matching the iOS app."
                        } else {
                            "This build is configured for Clerk, but the publishable key is missing."
                        }
                    AppConfig.AuthProvider.DEMO -> "This build uses the local demo account provider."
                    AppConfig.AuthProvider.WEB -> "This build can hand off account sign-in to a configured web URL."
                    AppConfig.AuthProvider.NONE -> "No external account provider is configured in this build."
                }
            ) {
                when (authProvider) {
                    AppConfig.AuthProvider.CLERK -> Text(
                        text = if (isClerkAuthAvailable) "Provider: Clerk" else "Provider: Clerk (unavailable)",
                        style = MaterialTheme.typography.bodyMedium
                    )

                    AppConfig.AuthProvider.DEMO -> Text(
                        text = "Provider: demo",
                        style = MaterialTheme.typography.bodyMedium
                    )

                    AppConfig.AuthProvider.WEB -> OutlinedButton(
                        onClick = onOpenWebAuth,
                        enabled = isWebAuthAvailable,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Open sign-in page")
                    }

                    AppConfig.AuthProvider.NONE -> Text(
                        text = "Provider: none",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }

        item {
            ProfileCard(
                title = "Capabilities",
                detail = if (accessState.capabilities.canAccessPremiumFeatures) {
                    "Premium and cloud-backed capabilities are active for this account."
                } else if (accessState.capabilities.canUseBackend) {
                    "Backend-backed account access is active, but premium features remain off for this account."
                } else if (authProvider == AppConfig.AuthProvider.CLERK && AppConfig.isAvAppsBackendConfigured && accessState.isSignedIn) {
                    "Account login is real through Clerk and access is resolved by AV Apps. This free state still stays local-first."
                } else if (!AppConfig.isPremiumSubscriptionAvailable) {
                    "Add AVRADIO_PREMIUM_PRODUCT_IDS to the Android config to enable store subscriptions in this build."
                } else if (authProvider == AppConfig.AuthProvider.CLERK && accessState.isSignedIn) {
                    "Account login is real through Clerk. Configure AVRADIO_AVAPPS_API_BASE_URL to resolve access from the shared backend."
                } else {
                    "Local-first mode with no backend dependency."
                }
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    CapabilityRow("Local only", accessState.capabilities.isLocalOnly)
                    CapabilityRow("Backend access", accessState.capabilities.canUseBackend)
                    CapabilityRow("Premium features", accessState.capabilities.canAccessPremiumFeatures)
                    CapabilityRow("Cloud sync", accessState.capabilities.canUseCloudSync)
                    CapabilityRow("Account management", accessState.capabilities.canManageAccount)
                    CapabilityRow("Subscriptions configured", AppConfig.isPremiumSubscriptionAvailable)
                }
            }
        }

        item {
            ProfileCard(
                title = "Local data",
                detail = "What this Android build currently stores on device."
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Favorites: ${libraryState.favorites.size}", style = MaterialTheme.typography.bodyMedium)
                    Text("Recents: ${libraryState.recents.size}", style = MaterialTheme.typography.bodyMedium)
                    Text(
                        "Sleep timer: ${libraryState.sleepTimerMinutes?.let { "${it} minutes" } ?: "Off"}",
                        style = MaterialTheme.typography.bodyMedium
                    )
                    Text(
                        "Last played: ${libraryState.lastPlayedStationId ?: "None"}",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }

        item {
            ProfileCard(
                title = "Help and legal",
                detail = "Open project, data-source, account, support, privacy, and terms references from the Android app."
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    LinkListItem(
                        title = "Station data source",
                        detail = "Station discovery relies on Radio Browser, with some artwork or icon lookups resolved through third-party metadata endpoints.",
                        onClick = onOpenStationDataSource
                    )
                    if (AppConfig.accountManagementUrl != null && accessState.capabilities.canManageAccount) {
                        LinkListItem(
                            title = "Manage account",
                            detail = "Open the AV Apps account management page.",
                            onClick = onOpenManageAccount
                        )
                    }
                    if (AppConfig.supportUrl != null) {
                        LinkListItem(
                            title = "Contact support",
                            detail = "Email AV Radio support.",
                            onClick = onOpenSupport
                        )
                    }
                    if (AppConfig.termsUrl != null) {
                        LinkListItem(
                            title = "Terms of service",
                            detail = "Review the terms that apply to AV Radio.",
                            onClick = onOpenTerms
                        )
                    }
                    if (AppConfig.privacyUrl != null) {
                        LinkListItem(
                            title = "Privacy policy",
                            detail = "See how AV Radio handles your data.",
                            onClick = onOpenPrivacy
                        )
                    }
                    if (
                        AppConfig.accountManagementUrl == null &&
                        AppConfig.supportUrl == null &&
                        AppConfig.termsUrl == null &&
                        AppConfig.privacyUrl == null
                    ) {
                        Text(
                            text = "No help or legal links are configured in this build.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        }

        item {
            ProfileCard(
                title = "Actions",
                detail = when (authProvider) {
                    AppConfig.AuthProvider.CLERK ->
                        if (accessState.isSignedIn) {
                            "Signed in with Clerk. Android now resolves account access through AV Apps when configured, while billing and app-data sync are still pending."
                        } else {
                            "Sign in with the same Clerk-powered AV Apps Account flow used by iOS."
                        }
                    else -> "Local account simulation until backend auth is wired."
                }
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    if (accessState.mode == AccessMode.GUEST) {
                        when (authProvider) {
                            AppConfig.AuthProvider.CLERK -> {
                                if (isClerkAuthAvailable) {
                                    Button(
                                        onClick = { isShowingClerkAuth = !isShowingClerkAuth },
                                        modifier = Modifier.fillMaxWidth()
                                    ) {
                                        Text(if (isShowingClerkAuth) "Hide AV Apps Account" else "Use AV Apps Account")
                                    }

                                    if (isShowingClerkAuth) {
                                        ClerkAuthCard(isInitialized = isClerkInitialized)
                                    }
                                } else {
                                    OutlinedButton(
                                        onClick = {},
                                        enabled = false,
                                        modifier = Modifier.fillMaxWidth()
                                    ) {
                                        Text("Clerk not configured in this build")
                                    }
                                }
                            }

                            AppConfig.AuthProvider.DEMO -> Button(
                                onClick = onConnectDemo,
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Text("Connect demo account")
                            }

                            AppConfig.AuthProvider.WEB -> Button(
                                onClick = onOpenWebAuth,
                                enabled = isWebAuthAvailable,
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Text("Open sign-in page")
                            }

                            AppConfig.AuthProvider.NONE -> OutlinedButton(
                                onClick = {},
                                enabled = false,
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Text("No account provider configured")
                            }
                        }
                    } else {
                        if (accessState.capabilities.canManageAccount && AppConfig.accountManagementUrl != null) {
                            OutlinedButton(onClick = onOpenManageAccount, modifier = Modifier.fillMaxWidth()) {
                                Text("Manage account")
                            }
                        }
                        if (authProvider == AppConfig.AuthProvider.DEMO && accessState.mode == AccessMode.SIGNED_IN_FREE) {
                            Button(onClick = onEnablePro, modifier = Modifier.fillMaxWidth()) {
                                Text("Enable pro demo")
                            }
                        } else if (authProvider == AppConfig.AuthProvider.DEMO) {
                            OutlinedButton(onClick = onDisablePro, modifier = Modifier.fillMaxWidth()) {
                                Text("Return to free plan")
                            }
                        }
                        OutlinedButton(onClick = onSignOut, modifier = Modifier.fillMaxWidth()) {
                            Icon(Icons.AutoMirrored.Filled.Logout, contentDescription = null)
                            Spacer(modifier = Modifier.size(8.dp))
                            Text("Sign out")
                        }
                    }
                    OutlinedButton(onClick = onClearLocalData, modifier = Modifier.fillMaxWidth()) {
                        Text("Clear local favorites and recents")
                    }
                    SleepTimerButtons(
                        selectedMinutes = libraryState.sleepTimerMinutes,
                        onSelect = onSetSleepTimer
                    )
                }
            }
        }
    }
}

@Composable
private fun LinkListItem(
    title: String,
    detail: String,
    onClick: () -> Unit
) {
    Surface(
        shape = RoundedCornerShape(20.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f),
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
    ) {
        ListItem(
            headlineContent = {
                Text(title, fontWeight = FontWeight.SemiBold)
            },
            supportingContent = {
                Text(detail)
            }
        )
    }
}

@Composable
private fun ProfileCard(
    title: String,
    detail: String,
    content: @Composable () -> Unit
) {
    Card(
        shape = RoundedCornerShape(28.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.96f)
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text(text = title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            Text(
                text = detail,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            HorizontalDivider()
            content()
        }
    }
}

@Composable
private fun CapabilityRow(title: String, enabled: Boolean) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(title, style = MaterialTheme.typography.bodyMedium)
        Text(
            text = if (enabled) "Enabled" else "Disabled",
            style = MaterialTheme.typography.labelMedium,
            color = if (enabled) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun SleepTimerButtons(
    selectedMinutes: Int?,
    onSelect: (Int?) -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            text = "Sleep timer",
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.Bold
        )
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf(15, 30, 60).forEach { minutes ->
                AssistChip(
                    onClick = { onSelect(minutes) },
                    label = { Text("${minutes}m") },
                    colors = if (selectedMinutes == minutes) {
                        AssistChipDefaults.assistChipColors(
                            containerColor = MaterialTheme.colorScheme.primary,
                            labelColor = MaterialTheme.colorScheme.onPrimary
                        )
                    } else {
                        AssistChipDefaults.assistChipColors()
                    }
                )
            }
            AssistChip(
                onClick = { onSelect(null) },
                label = { Text("Off") },
                colors = if (selectedMinutes == null) {
                    AssistChipDefaults.assistChipColors(
                        containerColor = MaterialTheme.colorScheme.secondary,
                        labelColor = MaterialTheme.colorScheme.onPrimary
                    )
                } else {
                    AssistChipDefaults.assistChipColors()
                }
            )
        }
    }
}

private fun Station.primaryDetail(): String {
    val pieces = listOfNotNull(
        country.takeIf { it.isNotBlank() && !it.equals("Unknown country", ignoreCase = true) },
        language.takeIf { it.isNotBlank() && !it.equals("Unknown language", ignoreCase = true) },
        bitrate?.takeIf { it > 0 }?.let { "${it} kbps" },
        codec?.takeIf { it.isNotBlank() }?.uppercase()
    )
    return pieces.joinToString(" · ").ifBlank { "Live radio" }
}

private fun Station.displayTags(): String? =
    tags.split(',')
        .map { it.trim() }
        .filter { it.isNotEmpty() && !it.equals("live", ignoreCase = true) }
        .distinctBy { it.lowercase() }
        .take(3)
        .takeIf { it.isNotEmpty() }
        ?.joinToString(" • ")

private fun Station.matchesQuery(query: String): Boolean {
    if (query.isBlank()) return true
    return name.contains(query, ignoreCase = true) ||
        country.contains(query, ignoreCase = true) ||
        tags.contains(query, ignoreCase = true)
}
