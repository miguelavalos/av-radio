import SwiftUI

struct AppShellView: View {
    let launchContext: LaunchContext
    let startSignInFlow: (Bool) -> Void

    @EnvironmentObject private var accessController: AccessController
    @EnvironmentObject private var audioPlayer: AudioPlayerService
    @EnvironmentObject private var libraryStore: LibraryStore

    @State private var selectedTab: AppShellTab
    @State private var isShowingNowPlaying = false
    @State private var searchQuery: String
    @State private var searchTag: String?
    @State private var searchCountryCode: String?
    @State private var searchFocusRequest = 0
    @State private var searchResults: [Station] = []
    @State private var searchIsLoading = false
    @State private var searchErrorMessage: String?
    @State private var homeStations: [Station] = []
    @State private var homeIsLoading = false
    @State private var homeErrorMessage: String?
    @State private var homeFeedContext: HomeFeedContext = .popularWorldwide
    @State private var homeSnapshot = HomeSnapshot()
    @State private var selectedStationDetail: SelectedStationDetail?
    @State private var stationNowPlayingTracks: [String: NowPlayingTrack] = [:]
    @State private var stationNowPlayingCache: [String: CachedStationNowPlaying] = [:]
    @State private var didBootstrap = false

    private let stationService = StationService()
    private let stationNowPlayingService = NowPlayingService()
    private let genreTags = ["rock", "pop", "jazz", "news", "electronic", "ambient"]

    init(
        launchContext: LaunchContext = .current,
        startSignInFlow: @escaping (Bool) -> Void = { _ in }
    ) {
        self.launchContext = launchContext
        self.startSignInFlow = startSignInFlow
        _selectedTab = State(initialValue: AppShellTab(launchContext.preferredTab, preferredSearchQuery: launchContext.preferredSearchQuery))
        _searchQuery = State(initialValue: launchContext.preferredSearchQuery ?? "")
    }

    var body: some View {
        AppShellScaffold(
            selectedTab: selectedTab,
            hasFooterPlayer: audioPlayer.currentStation != nil,
            searchAction: {
                selectedTab = .search
                searchFocusRequest += 1
            },
            selectTab: { tab in
                selectedTab = tab
            },
            content: {
                NavigationStack {
                    currentScreen
                }
            },
            footerPlayer: {
                if let station = audioPlayer.currentStation {
                    MiniPlayerView(station: station) {
                        isShowingNowPlaying = true
                    }
                }
            }
        )
        .sheet(isPresented: $isShowingNowPlaying) {
            NowPlayingView()
                .environmentObject(accessController)
                .environmentObject(audioPlayer)
                .environmentObject(libraryStore)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedStationDetail) { detail in
            StationDetailSheet(
                station: detail.station,
                isFavorite: favoriteStationIDs.contains(detail.station.id),
                isPlaying: audioPlayer.isCurrent(detail.station) && audioPlayer.isPlaying,
                playAction: {
                    playStation(
                        detail.station,
                        queueSource: detail.queueSource,
                        queue: detail.queueStations
                    )
                },
                toggleFavorite: { toggleFavorite(detail.station) }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: Binding(
            get: { isShowingNowPlaying ? nil : accessController.upgradePrompt },
            set: { accessController.upgradePrompt = $0 }
        )) { prompt in
            UpgradeRecommendationSheet(
                prompt: prompt,
                isGuest: accessController.accessMode == .guest,
                accountIsAvailable: accessController.accountIsAvailable,
                onPrimaryAction: {
                    accessController.upgradePrompt = nil
                    if accessController.accessMode == .guest {
                        startSignInFlow(true)
                    }
                },
                onDismiss: {
                    accessController.upgradePrompt = nil
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .task {
            await bootstrapIfNeeded()
        }
        .task {
            refreshHomePresentation()
        }
        .task {
            await refreshHomeFeed()
        }
        .task(id: searchRequestKey) {
            await loadSearchResults()
        }
        .task(id: stationNowPlayingRequestKey) {
            await loadStationNowPlayingPreviews()
        }
        .onChange(of: selectedTab) { _, newValue in
            guard newValue == .home else { return }
            refreshHomePresentation()
        }
        .onChange(of: audioPlayer.currentStation?.id) { _, stationID in
            guard stationID != nil, let station = audioPlayer.currentStation else { return }
            libraryStore.recordPlayback(of: station, recentLimit: accessController.limits.recentStations)
        }
        .onChange(of: currentTrackDiscoveryKey) { _, _ in
            recordCurrentTrackDiscovery()
        }
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch selectedTab {
        case .home:
            HomeScreen(
                stations: homeSnapshot.stations,
                isLoading: homeIsLoading,
                errorMessage: homeErrorMessage,
                recentStations: homeSnapshot.recentStations,
                favoriteStations: homeSnapshot.favoriteStations,
                discoveries: libraryStore.discoveries,
                feedContext: homeSnapshot.feedContext,
                bottomContentPadding: shellScrollBottomPadding,
                favoriteStationIDs: favoriteStationIDs,
                nowPlayingTracks: stationNowPlayingTracks,
                refreshHome: refreshHomePresentationAndFeed,
                playStation: playStation,
                toggleFavorite: toggleFavorite(_:),
                showStationDetails: showStationDetails
            )
        case .search:
            SearchScreen(
                query: $searchQuery,
                activeTag: $searchTag,
                selectedCountryCode: $searchCountryCode,
                results: searchResults,
                isLoading: searchIsLoading,
                errorMessage: searchErrorMessage,
                tags: genreTags,
                focusRequest: searchFocusRequest,
                bottomContentPadding: shellScrollBottomPadding,
                favoriteStationIDs: favoriteStationIDs,
                nowPlayingTracks: stationNowPlayingTracks,
                playStation: playStation,
                toggleFavorite: toggleFavorite(_:),
                showStationDetails: showStationDetails
            )
        case .library:
            LibraryScreen(
                favorites: favoriteStations,
                recents: recentStations,
                bottomContentPadding: shellScrollBottomPadding,
                favoriteStationIDs: favoriteStationIDs,
                nowPlayingTracks: stationNowPlayingTracks,
                playStation: playStation,
                toggleFavorite: toggleFavorite(_:),
                showStationDetails: showStationDetails
            )
        case .music:
            MusicScreen(
                discoveries: libraryStore.discoveries,
                bottomContentPadding: shellScrollBottomPadding,
                openDiscoveryStation: openDiscoveryStation(_:),
                stationArtworkURL: { discovery in libraryStore.station(for: discovery.stationID)?.displayArtworkURL },
                toggleDiscoverySaved: toggleDiscoverySaved(_:),
                hideDiscovery: libraryStore.hideDiscovery(_:),
                restoreDiscovery: libraryStore.restoreDiscovery(_:),
                removeDiscovery: libraryStore.removeDiscovery(_:),
                clearDiscoveries: libraryStore.clearDiscoveries
            )
        case .profile:
            ProfileScreen(
                startSignInFlow: startSignInFlow,
                bottomContentPadding: shellScrollBottomPadding
            )
        }
    }

    private var favoriteStations: [Station] {
        libraryStore.favoriteStations()
    }

    private var recentStations: [Station] {
        libraryStore.recentStations()
    }

    private var favoriteStationIDs: Set<String> {
        Set(libraryStore.favorites.map(\.stationID))
    }

    private var searchRequestKey: String {
        "\(searchQuery.trimmingCharacters(in: .whitespacesAndNewlines))|\(searchTag ?? "")|\(searchCountryCode ?? "")"
    }

    private var shellScrollBottomPadding: CGFloat {
        // The footer is visually detached and floats above scroll content,
        // so scrollable screens need extra trailing space to bring the last row above it.
        audioPlayer.currentStation == nil ? 96 : 168
    }

    private var stationNowPlayingRequestKey: String {
        let ids = stationNowPlayingCandidates.map(\.id).joined(separator: "|")
        return "\(selectedTab)|\(ids)"
    }

    private var currentTrackDiscoveryKey: String {
        [
            audioPlayer.currentStation?.id ?? "",
            audioPlayer.currentTrackArtist ?? "",
            audioPlayer.currentTrackTitle ?? "",
            audioPlayer.currentTrackArtworkURL?.absoluteString ?? ""
        ].joined(separator: "|")
    }

    private var stationNowPlayingCandidates: [Station] {
        guard isProNowPlayingEnabled else { return [] }

        switch selectedTab {
        case .home:
            return uniqueStations(
                homeSnapshot.recentStations.prefix(6) +
                homeSnapshot.favoriteStations.prefix(6) +
                homeSnapshot.stations.prefix(8)
            )
        case .search:
            return uniqueStations(searchResults.prefix(9))
        case .library:
            return uniqueStations(favoriteStations.prefix(9) + recentStations.prefix(6))
        case .music:
            return []
        case .profile:
            return []
        }
    }

    private func uniqueStations<S: Sequence>(_ stations: S) -> [Station] where S.Element == Station {
        var seenIDs = Set<String>()
        var result: [Station] = []

        for station in stations where !seenIDs.contains(station.id) {
            seenIDs.insert(station.id)
            result.append(station)
        }

        return result
    }

    private func loadStationNowPlayingPreviews() async {
        guard isProNowPlayingEnabled else { return }
        guard !launchContext.isUITesting else { return }

        let supportedStations = stationNowPlayingCandidates
            .filter { stationNowPlayingService.supports($0) }
            .prefix(6)

        guard !supportedStations.isEmpty else { return }

        for station in supportedStations {
            if Task.isCancelled { return }

            if let cached = stationNowPlayingCache[station.id], cached.isFresh {
                stationNowPlayingTracks[station.id] = cached.track
                continue
            }

            guard let track = await stationNowPlayingService.fetchTrack(for: station) else { continue }
            stationNowPlayingTracks[station.id] = track
            stationNowPlayingCache[station.id] = CachedStationNowPlaying(track: track, fetchedAt: Date())
        }
    }

    private var isProNowPlayingEnabled: Bool {
        accessController.capabilities.canAccessPremiumFeatures
    }

    private func recordCurrentTrackDiscovery() {
        guard
            let station = audioPlayer.currentStation,
            normalizedTrackValue(audioPlayer.currentTrackTitle) != nil,
            normalizedTrackValue(audioPlayer.currentTrackArtist) != nil
        else {
            return
        }

        libraryStore.recordDiscoveredTrack(
            title: audioPlayer.currentTrackTitle,
            artist: audioPlayer.currentTrackArtist,
            station: station,
            artworkURL: audioPlayer.currentTrackArtworkURL,
            discoveryLimit: accessController.limits.discoveredTracks
        )
    }

    private func applyUITestTrackMetadataIfNeeded() {
        guard launchContext.isUITesting else { return }
        guard launchContext.uiTestTrackTitle != nil || launchContext.uiTestTrackArtist != nil else { return }
        audioPlayer.applyUITestTrackMetadata(
            title: launchContext.uiTestTrackTitle,
            artist: launchContext.uiTestTrackArtist
        )
    }

    private func normalizedTrackValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func bootstrapIfNeeded() async {
        guard !didBootstrap else { return }
        didBootstrap = true

        audioPlayer.setSleepTimer(minutes: libraryStore.settings.sleepTimerMinutes)
        seedUITestDataIfNeeded()

        if let preferredTab = launchContext.preferredTab {
            switch preferredTab {
            case .search:
                selectedTab = .search
            case .library:
                selectedTab = .library
            case .music:
                selectedTab = .music
            case .player:
                if let lastStation = libraryStore.station(for: libraryStore.settings.lastPlayedStationID) {
                    playStation(lastStation)
                } else if let demoStation = launchContext.demoStation {
                    playStation(demoStation)
                }
                isShowingNowPlaying = audioPlayer.currentStation != nil
            case .settings:
                selectedTab = .profile
            }
        } else if launchContext.preferredSearchQuery != nil {
            selectedTab = .search
        }

        if let demoStation = launchContext.demoStation {
            libraryStore.ensureSeededStation(demoStation, favorite: launchContext.seedFavorite)
            if audioPlayer.currentStation?.id != demoStation.id {
                playStation(demoStation)
            }
            applyUITestTrackMetadataIfNeeded()
        }

        if launchContext.isUITesting, let feature = launchContext.uiTestUpgradePromptFeature {
            accessController.presentUpgradePrompt(for: feature)
        }
    }

    private func seedUITestDataIfNeeded() {
        guard launchContext.isUITesting else { return }
        guard launchContext.shouldSeedUITestLibrary else { return }
        guard libraryStore.favorites.isEmpty, libraryStore.recents.isEmpty else { return }

        let samples = Array(Station.samples.prefix(3))
        guard !samples.isEmpty else { return }

        for station in samples.prefix(2) {
            libraryStore.toggleFavorite(for: station)
        }

        for station in samples {
            libraryStore.recordPlayback(of: station, recentLimit: accessController.limits.recentStations)
        }

        if launchContext.shouldUseLocalUITestDiscovery {
            libraryStore.recordDiscoveredTrack(
                title: "Midnight City",
                artist: "M83",
                station: samples[0],
                artworkURL: nil
            )
            libraryStore.markTrackInteresting(
                title: "Sweet Disposition",
                artist: "The Temper Trap",
                station: samples[1],
                artworkURL: nil
            )
        }
    }

    private func playStation(
        _ station: Station,
        queueSource: AudioPlayerService.PlaybackQueue.Source = .singleStation,
        queue: [Station]? = nil
    ) {
        let playbackQueue = AudioPlayerService.PlaybackQueue(
            source: queueSource,
            stations: queue ?? [station]
        )
        audioPlayer.play(station: station, queue: playbackQueue)
        libraryStore.recordPlayback(of: station, recentLimit: accessController.limits.recentStations)
    }

    private func toggleFavorite(_ station: Station) {
        if libraryStore.isFavorite(station) {
            libraryStore.toggleFavorite(for: station)
            return
        }

        let state = accessController.limitState(
            for: .favoriteStations,
            currentUsage: libraryStore.favorites.count
        )
        guard state.isAllowed else {
            accessController.presentUpgradePrompt(for: .favoriteStations, currentUsage: state.currentUsage)
            return
        }

        libraryStore.toggleFavorite(for: station)
    }

    private func toggleDiscoverySaved(_ discovery: DiscoveredTrack) {
        if discovery.isMarkedInteresting {
            _ = libraryStore.toggleDiscoverySaved(discovery)
            return
        }

        let state = accessController.limitState(
            for: .savedTracks,
            currentUsage: libraryStore.savedDiscoveriesCount
        )
        guard state.isAllowed else {
            accessController.presentUpgradePrompt(for: .savedTracks, currentUsage: state.currentUsage)
            return
        }

        _ = libraryStore.toggleDiscoverySaved(discovery, savedLimit: state.limit)
    }

    private func showStationDetails(
        _ station: Station,
        queueSource: AudioPlayerService.PlaybackQueue.Source = .singleStation,
        queue: [Station]? = nil
    ) {
        selectedStationDetail = SelectedStationDetail(
            station: station,
            queueSource: queueSource,
            queueStations: queue ?? [station]
        )
    }

    private func openDiscoveryStation(_ discovery: DiscoveredTrack) {
        guard let station = libraryStore.station(for: discovery.stationID) else { return }

        playStation(station, queueSource: .libraryRecents, queue: recentStations)
    }

    private func refreshHomeFeed() async {
        homeIsLoading = true
        homeErrorMessage = nil

        if launchContext.isUITesting && launchContext.shouldUseLocalUITestDiscovery {
            homeStations = Array(Station.samples.prefix(8))
            homeFeedContext = .popularWorldwide
            refreshHomePresentation()
            homeIsLoading = false
            return
        }

        do {
            let regionCode = resolvedDeviceCountryCode()
            let regionalStations = try await stationService.searchStations(
                filters: .init(query: "", countryCode: regionCode ?? "", limit: 8, allowsEmptySearch: regionCode == nil ? false : true)
            )
            let globalStations = try await stationService.searchStations(
                filters: .init(query: "", limit: 8, allowsEmptySearch: true)
            )

            homeStations = mergeUniqueStations(primary: regionalStations, secondary: globalStations, limit: 8)
            if let regionCode, !regionalStations.isEmpty {
                homeFeedContext = .popularInCountry(localizedCountryName(for: regionCode))
            } else {
                homeFeedContext = .popularWorldwide
            }
            refreshHomePresentation()
            homeIsLoading = false
        } catch is CancellationError {
            homeIsLoading = false
        } catch {
            homeStations = defaultEditorialStations
            homeFeedContext = .popularWorldwide
            homeErrorMessage = defaultEditorialStations.isEmpty ? L10n.string("shell.error.home") : nil
            refreshHomePresentation()
            homeIsLoading = false
        }
    }

    private func refreshHomePresentation() {
        homeSnapshot = HomeSnapshot(
            stations: homeStations,
            recentStations: recentStations,
            favoriteStations: favoriteStations,
            feedContext: homeFeedContext
        )
    }

    private func refreshHomePresentationAndFeed() async {
        refreshHomePresentation()
        await refreshHomeFeed()
    }

    private func loadSearchResults() async {
        let queryText = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let tagText = searchTag?.trimmingCharacters(in: .whitespacesAndNewlines)
        let countryCode = searchCountryCode?.trimmingCharacters(in: .whitespacesAndNewlines)
        let requestKey = "\(queryText)|\(tagText ?? "")|\(countryCode ?? "")"

        searchIsLoading = true
        searchErrorMessage = nil

        if launchContext.isUITesting && launchContext.shouldUseLocalUITestSearch {
            let results = localUITestSearchResults(
                queryText: queryText,
                tagText: tagText,
                countryCode: countryCode
            )
            searchResults = results
            searchErrorMessage = nil
            searchIsLoading = false
            return
        }

        do {
            try await Task.sleep(for: .milliseconds(300))
            try Task.checkCancellation()

            let results: [Station]

            if queryText.isEmpty && (countryCode?.isEmpty != false) {
                results = try await loadWorldwideDiscoveryStations(limit: 12, tag: tagText)
            } else {
                results = try await stationService.searchStations(
                    filters: .init(
                        query: queryText,
                        countryCode: countryCode ?? "",
                        tag: tagText ?? "",
                        limit: queryText.isEmpty ? 12 : 24,
                        allowsEmptySearch: queryText.isEmpty
                    )
                )
            }
            guard requestKey == searchRequestKey else { return }

            searchResults = results
            searchErrorMessage = nil
            searchIsLoading = false
        } catch is CancellationError {
            guard requestKey == searchRequestKey else { return }
            searchIsLoading = false
        } catch {
            guard requestKey == searchRequestKey else { return }
            searchResults = []
            searchErrorMessage = L10n.string("shell.error.search")
            searchIsLoading = false
        }
    }

    private func localUITestSearchResults(
        queryText: String,
        tagText: String?,
        countryCode: String?
    ) -> [Station] {
        Station.samples.filter { station in
            let matchesQuery =
                queryText.isEmpty
                || station.name.localizedCaseInsensitiveContains(queryText)
                || station.country.localizedCaseInsensitiveContains(queryText)
                || station.tags.localizedCaseInsensitiveContains(queryText)

            let matchesTag =
                tagText?.isEmpty != false
                || station.tags.localizedCaseInsensitiveContains(tagText ?? "")

            let matchesCountry =
                countryCode?.isEmpty != false
                || station.countryCode?.caseInsensitiveCompare(countryCode ?? "") == .orderedSame

            return matchesQuery && matchesTag && matchesCountry
        }
    }

    private var defaultEditorialStations: [Station] {
        var seen = Set<String>()
        let candidates =
            [audioPlayer.currentStation].compactMap { $0 } +
            recentStations +
            favoriteStations +
            Station.samples

        return candidates.filter { station in
            seen.insert(station.id).inserted
        }
    }

    private func resolvedDeviceCountryCode() -> String? {
        let code = Locale.autoupdatingCurrent.region?.identifier ?? Locale.current.region?.identifier
        guard let code, !code.isEmpty else { return nil }
        return code.uppercased()
    }

    private func localizedCountryName(for countryCode: String) -> String {
        L10n.countryName(for: countryCode)
    }

    private func mergeUniqueStations(primary: [Station], secondary: [Station], limit: Int) -> [Station] {
        var seen = Set<String>()
        var merged: [Station] = []

        for station in primary + secondary {
            guard seen.insert(station.id).inserted else { continue }
            merged.append(station)
            if merged.count == limit {
                break
            }
        }

        return merged
    }

    private func loadWorldwideDiscoveryStations(limit: Int, tag: String? = nil) async throws -> [Station] {
        let seedCountryCodes =
            [resolvedDeviceCountryCode()] +
            recentStations.compactMap(\.countryCode) +
            favoriteStations.compactMap(\.countryCode) +
            ["US", "GB", "DE", "FR", "IT", "ES", "NL", "CA", "AU", "BR", "MX", "AR"]

        var orderedCodes: [String] = []
        var seenCodes = Set<String>()
        for code in seedCountryCodes.compactMap(CountryOption.sanitizedCode) where seenCodes.insert(code).inserted {
            orderedCodes.append(code)
        }

        var merged: [Station] = []
        for code in orderedCodes {
            let stations = try await stationService.searchStations(
                filters: .init(
                    query: "",
                    countryCode: code,
                    tag: tag ?? "",
                    limit: tag == nil ? 4 : 6,
                    allowsEmptySearch: true
                )
            )
            merged = mergeUniqueStations(
                primary: merged,
                secondary: stations.filter(hasResolvedCountry),
                limit: limit
            )

            if merged.count >= limit {
                break
            }
        }

        return Array(merged.prefix(limit))
    }

    private func hasResolvedCountry(_ station: Station) -> Bool {
        if CountryOption.sanitizedCode(station.countryCode) != nil {
            return true
        }

        let country = station.country.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !country.isEmpty else { return false }

        let normalizedCountry = country
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
        let unknownCountryTokens = [
            L10n.string("stationService.fallback.unknownCountry"),
            "Unknown country",
            "País desconocido",
            "País desconegut",
            "Pays inconnu",
            "Unbekanntes Land"
        ]
        .map {
            $0
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .lowercased()
        }

        return !unknownCountryTokens.contains(normalizedCountry)
    }
}

private struct HomeSnapshot {
    var stations: [Station] = []
    var recentStations: [Station] = []
    var favoriteStations: [Station] = []
    var feedContext: HomeFeedContext = .popularWorldwide
}

private struct CachedStationNowPlaying {
    let track: NowPlayingTrack
    let fetchedAt: Date

    var isFresh: Bool {
        Date().timeIntervalSince(fetchedAt) < 60
    }
}

private struct SelectedStationDetail: Identifiable {
    let station: Station
    let queueSource: AudioPlayerService.PlaybackQueue.Source
    let queueStations: [Station]

    var id: String {
        station.id
    }
}

private enum HomeFeedContext: Equatable {
    case popularInCountry(String)
    case popularWorldwide
}

private enum AppShellTab: Equatable {
    case home
    case search
    case library
    case music
    case profile

    init(_ preferredTab: LaunchContext.Tab?, preferredSearchQuery: String?) {
        switch preferredTab {
        case .search:
            self = .search
        case .library:
            self = .library
        case .music:
            self = .music
        case .settings:
            self = .profile
        case .player, .none:
            self = preferredSearchQuery == nil ? .home : .search
        }
    }
}

private struct AppShellScaffold<Content: View, FooterPlayer: View>: View {
    let selectedTab: AppShellTab
    let hasFooterPlayer: Bool
    let searchAction: () -> Void
    let selectTab: (AppShellTab) -> Void
    @ViewBuilder let content: () -> Content
    @ViewBuilder let footerPlayer: () -> FooterPlayer

    @Namespace private var footerSelectionAnimation

    var body: some View {
        ZStack {
            AvradioTheme.shellBackground.ignoresSafeArea()

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(alignment: .bottom) {
            footer
        }
    }

    private var footer: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [
                    AvradioTheme.footerBackdrop.opacity(0),
                    AvradioTheme.footerBackdrop.opacity(0.94),
                    AvradioTheme.footerBackdrop
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: hasFooterPlayer ? 210 : 142)
            .allowsHitTesting(false)

            VStack(spacing: 10) {
                footerPlayer()

                HStack(spacing: 18) {
                    HStack {
                        AppShellFooterTabButton(
                            title: L10n.string("tab.home"),
                            systemImage: "house.fill",
                            isSelected: selectedTab == .home,
                            selectionNamespace: footerSelectionAnimation,
                            accessibilityIdentifier: "tab.home"
                        ) {
                            selectTab(.home)
                        }

                        AppShellFooterTabButton(
                            title: L10n.string("tab.library"),
                            systemImage: "heart.fill",
                            isSelected: selectedTab == .library,
                            selectionNamespace: footerSelectionAnimation,
                            accessibilityIdentifier: "tab.library"
                        ) {
                            selectTab(.library)
                        }

                        AppShellFooterTabButton(
                            title: L10n.string("tab.music"),
                            systemImage: "music.note.list",
                            isSelected: selectedTab == .music,
                            selectionNamespace: footerSelectionAnimation,
                            accessibilityIdentifier: "tab.music"
                        ) {
                            selectTab(.music)
                        }

                        AppShellFooterTabButton(
                            title: L10n.string("tab.profile"),
                            systemImage: "person.crop.circle.fill",
                            isSelected: selectedTab == .profile,
                            selectionNamespace: footerSelectionAnimation,
                            accessibilityIdentifier: "tab.profile"
                        ) {
                            selectTab(.profile)
                        }
                    }
                    .padding(.leading, 10)
                    .padding(.trailing, 10)
                    .padding(.vertical, 7)
                    .background {
                        Capsule(style: .continuous)
                            .fill(AvradioTheme.footerGlass)
                            .background(.ultraThinMaterial.opacity(0.95), in: Capsule(style: .continuous))
                            .overlay {
                                Capsule(style: .continuous)
                                    .stroke(AvradioTheme.glassStroke, lineWidth: 1)
                            }
                        }
                    .shadow(color: AvradioTheme.glassShadow, radius: 18, y: 10)

                    AppShellFooterSearchButton(isSelected: selectedTab == .search) {
                        searchAction()
                    }
                    .shadow(color: AvradioTheme.glassShadow, radius: 18, y: 10)
                }
                .frame(maxWidth: 430)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, -8)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

private struct AppShellFooterTabButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let selectionNamespace: Namespace.ID
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AvradioTheme.footerGlassSelected)
                        .matchedGeometryEffect(id: "footerSelection", in: selectionNamespace)
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(AvradioTheme.glassStroke, lineWidth: 0.8)
                        }
                }

                Image(systemName: displayedSystemImage)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .frame(width: 20, height: 20)
                    .symbolRenderingMode(.monochrome)
            }
            .foregroundStyle(isSelected ? AvradioTheme.highlight : AvradioTheme.textSecondary)
            .frame(width: 64, height: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var displayedSystemImage: String {
        guard !isSelected else { return systemImage }
        return systemImage.replacingOccurrences(of: ".fill", with: "")
    }
}

private struct AppShellFooterSearchButton: View {
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(AvradioTheme.footerGlass)
                    .background(.ultraThinMaterial.opacity(0.95), in: Circle())
                    .overlay {
                        Circle()
                            .stroke(AvradioTheme.glassStroke, lineWidth: 1)
                    }

                if isSelected {
                    Circle()
                        .fill(AvradioTheme.footerGlassSelected)
                        .padding(4)
                }

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isSelected ? AvradioTheme.highlight : AvradioTheme.textSecondary)
            }
            .frame(width: 62, height: 62)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.string("tab.search"))
        .accessibilityIdentifier("tab.search")
    }
}

private struct HomeScreen: View {
    @EnvironmentObject private var audioPlayer: AudioPlayerService

    let stations: [Station]
    let isLoading: Bool
    let errorMessage: String?
    let recentStations: [Station]
    let favoriteStations: [Station]
    let discoveries: [DiscoveredTrack]
    let feedContext: HomeFeedContext
    let bottomContentPadding: CGFloat
    let favoriteStationIDs: Set<String>
    let nowPlayingTracks: [String: NowPlayingTrack]
    let refreshHome: () async -> Void
    let playStation: (Station, AudioPlayerService.PlaybackQueue.Source, [Station]?) -> Void
    let toggleFavorite: (Station) -> Void
    let showStationDetails: (Station, AudioPlayerService.PlaybackQueue.Source, [Station]?) -> Void

    private enum FeaturedSource {
        case recent
        case favorite
        case popular
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ShellBrandHeader(statusTitle: isLoading ? L10n.string("shell.status.refreshing") : (audioPlayer.currentStation == nil ? L10n.string("shell.status.live") : audioPlayer.status.label))

                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.string("shell.home.title"))
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(AvradioTheme.textPrimary)

                    Text(L10n.string("shell.home.subtitle"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AvradioTheme.textSecondary)
                }

                if shouldShowLiveNowPanel {
                    LiveNowPanel(currentStation: audioPlayer.currentStation, status: audioPlayer.status.label)
                }

                if !displayedRecentStations.isEmpty {
                    StationSection(title: L10n.string("shell.home.recents.title"), subtitle: L10n.string("shell.home.recents.subtitle"), accessibilityIdentifier: "home.section.recents") {
                        StationCompactCarousel(
                            stations: displayedRecentStations,
                            favoriteStationIDs: favoriteStationIDs,
                            nowPlayingTracks: nowPlayingTracks,
                            queueSource: .homeRecents,
                            queueStations: recentStations,
                            playStation: playStation,
                            toggleFavorite: toggleFavorite,
                            showStationDetails: showStationDetails
                        )
                    }
                }

                if !displayedFavoriteStations.isEmpty {
                    StationSection(title: L10n.string("shell.home.favorites.title"), subtitle: L10n.string("shell.home.favorites.subtitle"), accessibilityIdentifier: "home.section.favorites") {
                        StationCompactCarousel(
                            stations: displayedFavoriteStations,
                            favoriteStationIDs: favoriteStationIDs,
                            nowPlayingTracks: nowPlayingTracks,
                            queueSource: .homeFavorites,
                            queueStations: favoriteStations,
                            playStation: playStation,
                            toggleFavorite: toggleFavorite,
                            showStationDetails: showStationDetails
                        )
                    }
                }

                if isLoading && featuredStation == nil && displayedPopularStations.isEmpty {
                    StationCardSkeletonGroup()
                } else if let errorMessage {
                    EmptyLibraryState(
                        title: L10n.string("shell.home.error.title"),
                        detail: errorMessage
                    )
                } else if let featuredStation {
                    if usesCompactFeaturedSection {
                        StationSection(
                            title: L10n.string("shell.home.featured.frontPage"),
                            subtitle: L10n.string("shell.home.featured.frontPage.subtitle"),
                            accessibilityIdentifier: "home.section.featured"
                        ) {
                            StationCompactCarousel(
                                stations: [featuredStation],
                                favoriteStationIDs: favoriteStationIDs,
                                nowPlayingTracks: nowPlayingTracks,
                                queueSource: featuredQueueSource,
                                queueStations: featuredQueueStations,
                                playStation: playStation,
                                toggleFavorite: toggleFavorite,
                                showStationDetails: showStationDetails
                            )
                        }
                    } else {
                        FeaturedStationCard(
                            station: featuredStation,
                            label: featuredLabel,
                            subtitle: stationDeck(for: featuredStation),
                            isFavorite: favoriteStationIDs.contains(featuredStation.id),
                            playAction: { playStation(featuredStation, featuredQueueSource, featuredQueueStations) },
                            favoriteAction: { toggleFavorite(featuredStation) },
                            detailsAction: { showStationDetails(featuredStation, featuredQueueSource, featuredQueueStations) }
                        )
                    }

                    if !displayedPopularStations.isEmpty {
                        StationSection(
                            title: sectionTitle,
                            subtitle: sectionSubtitle,
                            accessibilityIdentifier: "home.section.discovery"
                        ) {
                            StationCompactCarousel(
                                stations: displayedPopularStations,
                                favoriteStationIDs: favoriteStationIDs,
                                nowPlayingTracks: nowPlayingTracks,
                                queueSource: .homeDiscovery,
                                queueStations: displayedPopularStations,
                                playStation: playStation,
                                toggleFavorite: toggleFavorite,
                                showStationDetails: showStationDetails
                            )
                        }
                    }
                } else {
                    EmptyLibraryState(
                        title: L10n.string("shell.home.empty.title"),
                        detail: L10n.string("shell.home.empty.detail")
                    )
                }
            }
            .padding(24)
            .padding(.bottom, bottomContentPadding)
        }
        .scrollIndicators(.hidden)
        .background(AvradioTheme.shellBackground.ignoresSafeArea())
        .refreshable {
            await refreshHome()
        }
    }

    private func stationDeck(for station: Station) -> String {
        let language = cleanedFeaturedDetail(station.language)
        let country = cleanedFeaturedDetail(station.country)

        switch feedContext {
        case .popularInCountry:
            if let language, let flag = station.flagEmoji {
                return "\(flag) \(language)"
            }
            if let language {
                return language
            }
            if let flag = station.flagEmoji, let country {
                return "\(flag) \(country)"
            }
            if let country {
                return country
            }
            return L10n.string("shell.station.codec.live")
        case .popularWorldwide:
            if let language, let flag = station.flagEmoji {
                return "\(flag) \(language)"
            }
            if let language {
                return language
            }
            if let flag = station.flagEmoji, let country {
                return "\(flag) \(country)"
            }
            if let country {
                return country
            }
            return L10n.string("shell.station.codec.live")
        }
    }

    private func cleanedFeaturedDetail(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized = trimmed
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: L10n.locale)
            .lowercased()

        let blocked = [
            L10n.string("stationService.fallback.unknownCountry"),
            L10n.string("stationService.fallback.unknownLanguage"),
            "Unknown country",
            "Unknown language"
        ]
        .map {
            $0
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: L10n.locale)
                .lowercased()
        }

        return blocked.contains(normalized) ? nil : trimmed
    }

    private var hasPersonalActivity: Bool {
        !recentStations.isEmpty || !favoriteStations.isEmpty
    }

    private var shouldShowLiveNowPanel: Bool {
        audioPlayer.currentStation != nil || !hasPersonalActivity
    }

    private var usesCompactFeaturedSection: Bool {
        hasPersonalActivity
    }

    private var featuredSource: FeaturedSource? {
        if !favoriteStations.isEmpty {
            return .favorite
        }
        if !stations.isEmpty {
            return .popular
        }
        return nil
    }

    private var featuredStation: Station? {
        switch featuredSource {
        case .recent:
            return nil
        case .favorite:
            return favoriteStations.first
        case .popular:
            return stations.first
        case .none:
            return nil
        }
    }

    private var featuredStationID: String? {
        featuredStation?.id
    }

    private var displayedRecentStations: [Station] {
        recentStations
    }

    private var displayedFavoriteStations: [Station] {
        Array(filteredStationsExcludingFeatured(from: favoriteStations).prefix(6))
    }

    private var displayedPopularStations: [Station] {
        let excludedIDs = Set(displayedRecentStations.map(\.id) + displayedFavoriteStations.map(\.id))
        return filteredStationsExcludingFeatured(from: stations)
            .filter { !excludedIDs.contains($0.id) }
            .sorted { first, second in
                let firstScore = discoverySignalScore(for: first)
                let secondScore = discoverySignalScore(for: second)

                if firstScore == secondScore {
                    return first.name.localizedCaseInsensitiveCompare(second.name) == .orderedAscending
                }

                return firstScore > secondScore
            }
    }

    private var featuredQueueSource: AudioPlayerService.PlaybackQueue.Source {
        switch featuredSource {
        case .recent:
            return .homeRecents
        case .favorite:
            return .homeFavorites
        case .popular, .none:
            return .homeDiscovery
        }
    }

    private var featuredQueueStations: [Station] {
        switch featuredSource {
        case .recent:
            return recentStations
        case .favorite:
            return favoriteStations
        case .popular, .none:
            return stations
        }
    }

    private func filteredStationsExcludingFeatured(from stations: [Station]) -> [Station] {
        guard let featuredStationID else { return stations }
        return stations.filter { $0.id != featuredStationID }
    }

    private func discoverySignalScore(for station: Station) -> Int {
        discoveries.reduce(0) { score, discovery in
            guard discovery.stationID == station.id else { return score }

            if discovery.isMarkedInteresting {
                return score + 3
            }

            if discovery.isHidden {
                return score - 2
            }

            return score
        }
    }

    private var featuredLabel: String {
        switch featuredSource {
        case .recent:
            return L10n.string("shell.home.featured.frontPage").uppercased(with: .current)
        case .favorite:
            return L10n.string("shell.home.featured.frontPage").uppercased(with: .current)
        case .popular, .none:
            break
        }

        switch feedContext {
        case .popularInCountry(let countryName):
            return countryName.uppercased(with: .current)
        case .popularWorldwide:
            return L10n.string("shell.home.featured.popular").uppercased(with: .current)
        }
    }

    private var sectionTitle: String {
        switch feedContext {
        case .popularInCountry(let countryName):
            return L10n.string("shell.home.section.popularCountry.title", countryName)
        case .popularWorldwide:
            return L10n.string("shell.home.section.popularWorldwide.title")
        }
    }

    private var sectionSubtitle: String {
        switch feedContext {
        case .popularInCountry(let countryName):
            return L10n.string("shell.home.section.popularCountry.subtitle", countryName)
        case .popularWorldwide:
            return L10n.string("shell.home.section.popularWorldwide.subtitle")
        }
    }
}

private struct SearchScreen: View {
    @Binding var query: String
    @Binding var activeTag: String?
    @Binding var selectedCountryCode: String?

    let results: [Station]
    let isLoading: Bool
    let errorMessage: String?
    let tags: [String]
    let focusRequest: Int
    let bottomContentPadding: CGFloat
    let favoriteStationIDs: Set<String>
    let nowPlayingTracks: [String: NowPlayingTrack]
    let playStation: (Station, AudioPlayerService.PlaybackQueue.Source, [Station]?) -> Void
    let toggleFavorite: (Station) -> Void
    let showStationDetails: (Station, AudioPlayerService.PlaybackQueue.Source, [Station]?) -> Void

    @EnvironmentObject private var libraryStore: LibraryStore
    @State private var isShowingCountryPicker = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ShellBrandHeader(statusTitle: isLoading ? L10n.string("shell.search.status.searching") : L10n.string("shell.search.status.search"))

                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.string("shell.search.title"))
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(AvradioTheme.textPrimary)

                    Text(L10n.string("shell.search.subtitle"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AvradioTheme.textSecondary)
                }

                SearchField(query: $query, focusRequest: focusRequest)
                SearchCountryFilterButton(
                    title: selectedCountryTitle,
                    flag: selectedCountryFlag,
                    isActive: selectedCountryCode != nil,
                    clearAction: clearCountryFilter,
                    openAction: { isShowingCountryPicker = true }
                )
                GenreTagStrip(tags: tags, activeTag: activeTag, toggleTag: toggleTag)

                StationSection(
                    title: queryText.isEmpty && activeTag == nil && selectedCountryCode != nil
                        ? L10n.string("shell.search.section.country.title", selectedCountryTitle)
                        : queryText.isEmpty && activeTag == nil
                            ? L10n.string("shell.search.section.popularWorldwide.title")
                        : queryText.isEmpty
                            ? L10n.string("shell.search.section.browse.title")
                            : L10n.string("shell.search.section.results.title"),
                    subtitle: queryText.isEmpty
                        ? browseSubtitle
                        : L10n.plural(
                            singular: "shell.search.results.count.one",
                            plural: "shell.search.results.count.other",
                            count: results.count,
                            results.count,
                            queryText
                        ),
                    accessibilityIdentifier: "search.section.results"
                ) {
                    if !results.isEmpty {
                        if isLoading {
                            SearchLoadingCard()
                        }

                        if usesSearchGrid {
                            LazyVGrid(columns: searchGridColumns, spacing: 12) {
                                ForEach(results) { station in
                                    StationCompactCard(
                                        station: station,
                                        isFavorite: favoriteStationIDs.contains(station.id),
                                        nowPlayingTrack: nowPlayingTracks[station.id],
                                        toggleFavorite: { toggleFavorite(station) },
                                        playAction: { playStation(station, .searchResults, results) },
                                        detailsAction: { showStationDetails(station, .searchResults, results) }
                                    )
                                }
                            }
                        } else {
                            StationCompactCarousel(
                                stations: results,
                                favoriteStationIDs: favoriteStationIDs,
                                nowPlayingTracks: nowPlayingTracks,
                                queueSource: .searchResults,
                                queueStations: results,
                                playStation: playStation,
                                toggleFavorite: toggleFavorite,
                                showStationDetails: showStationDetails
                            )
                        }
                    } else if isLoading {
                        SearchLoadingCard()
                    } else if let errorMessage {
                        EmptyLibraryState(
                            title: L10n.string("shell.search.error.title"),
                            detail: errorMessage
                        )
                    } else if results.isEmpty {
                        EmptyLibraryState(
                            title: L10n.string("shell.search.empty.title"),
                            detail: queryText.isEmpty && activeTag == nil
                                ? L10n.string("shell.search.empty.detail.initial")
                                : L10n.string("shell.search.empty.detail.retry")
                        )
                    }
                }
            }
            .padding(24)
            .padding(.bottom, bottomContentPadding)
        }
        .scrollIndicators(.hidden)
        .background(AvradioTheme.shellBackground.ignoresSafeArea())
        .sheet(isPresented: $isShowingCountryPicker) {
            SearchCountryPickerSheet(selectedCountryCode: $selectedCountryCode)
                .environmentObject(libraryStore)
        }
        .onChange(of: selectedCountryCode) { _, newValue in
            libraryStore.setPreferredCountry(newValue)
        }
    }

    private var queryText: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var usesSearchGrid: Bool {
        !queryText.isEmpty || activeTag != nil || selectedCountryCode != nil
    }

    private var searchGridColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 104, maximum: 120), spacing: 12)
        ]
    }

    private func toggleTag(_ tag: String) {
        activeTag = activeTag == tag ? nil : tag
    }

    private var selectedCountryTitle: String {
        guard let selectedCountryCode else {
            return L10n.string("shell.search.country.all")
        }

        return L10n.countryName(for: selectedCountryCode)
    }

    private var browseSubtitle: String {
        if selectedCountryCode != nil {
            return L10n.string("shell.search.section.country.subtitle", selectedCountryTitle)
        }

        if activeTag == nil {
            return L10n.string("shell.search.section.popularWorldwide.subtitle")
        }

        return L10n.string("shell.search.section.browse.subtitle")
    }

    private func clearCountryFilter() {
        selectedCountryCode = nil
        libraryStore.setPreferredCountry(nil)
    }

    private var selectedCountryFlag: String? {
        guard let selectedCountryCode else { return nil }
        return CountryOption(code: selectedCountryCode, name: selectedCountryTitle).flag
    }
}

private struct LibraryScreen: View {
    @State private var query = ""

    let favorites: [Station]
    let recents: [Station]
    let bottomContentPadding: CGFloat
    let favoriteStationIDs: Set<String>
    let nowPlayingTracks: [String: NowPlayingTrack]
    let playStation: (Station, AudioPlayerService.PlaybackQueue.Source, [Station]?) -> Void
    let toggleFavorite: (Station) -> Void
    let showStationDetails: (Station, AudioPlayerService.PlaybackQueue.Source, [Station]?) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ShellBrandHeader(
                    statusTitle: favorites.isEmpty
                        ? L10n.string("shell.library.status.empty")
                        : L10n.plural(
                            singular: "shell.library.status.saved.one",
                            plural: "shell.library.status.saved.other",
                            count: favorites.count,
                            favorites.count
                        )
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.string("shell.library.title"))
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(AvradioTheme.textPrimary)

                    Text(L10n.string("shell.library.subtitle"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AvradioTheme.textSecondary)
                }

                SearchField(query: $query, prompt: L10n.string("shell.library.searchPrompt"))

                StationSection(title: L10n.string("shell.library.favorites.title"), subtitle: L10n.string("shell.library.favorites.subtitle"), accessibilityIdentifier: "library.section.favorites") {
                    if filteredFavorites.isEmpty {
                        EmptyLibraryState(
                            title: favorites.isEmpty ? L10n.string("shell.library.favorites.empty") : L10n.string("shell.library.favorites.noMatch"),
                            detail: favorites.isEmpty
                                ? L10n.string("shell.library.favorites.empty.detail")
                                : L10n.string("shell.library.favorites.noMatch.detail")
                        )
                    } else {
                        LazyVGrid(columns: stationGridColumns, spacing: 12) {
                            ForEach(filteredFavorites) { station in
                                StationCompactCard(
                                    station: station,
                                    isFavorite: favoriteStationIDs.contains(station.id),
                                    nowPlayingTrack: nowPlayingTracks[station.id],
                                    toggleFavorite: { toggleFavorite(station) },
                                    playAction: { playStation(station, .libraryFavorites, favorites) },
                                    detailsAction: { showStationDetails(station, .libraryFavorites, favorites) }
                                )
                            }
                        }
                    }
                }

                if !filteredRecents.isEmpty {
                    StationSection(title: L10n.string("shell.library.recents.title"), subtitle: L10n.string("shell.library.recents.subtitle"), accessibilityIdentifier: "library.section.recents") {
                        LazyVGrid(columns: stationGridColumns, spacing: 12) {
                            ForEach(filteredRecents) { station in
                                StationCompactCard(
                                    station: station,
                                    isFavorite: favoriteStationIDs.contains(station.id),
                                    nowPlayingTrack: nowPlayingTracks[station.id],
                                    toggleFavorite: { toggleFavorite(station) },
                                    playAction: { playStation(station, .libraryRecents, recents) },
                                    detailsAction: { showStationDetails(station, .libraryRecents, recents) }
                                )
                            }
                        }
                    }
                }
            }
            .padding(24)
            .padding(.bottom, bottomContentPadding)
        }
        .scrollIndicators(.hidden)
        .background(AvradioTheme.shellBackground.ignoresSafeArea())
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var stationGridColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 104, maximum: 120), spacing: 12)
        ]
    }

    private var filteredFavorites: [Station] {
        filterStations(favorites)
    }

    private var filteredRecents: [Station] {
        filterStations(recents)
    }

    private func filterStations(_ stations: [Station]) -> [Station] {
        guard !trimmedQuery.isEmpty else { return stations }

        return stations.filter { station in
            station.name.localizedCaseInsensitiveContains(trimmedQuery) ||
            station.country.localizedCaseInsensitiveContains(trimmedQuery) ||
            station.tags.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }
}

private struct MusicScreen: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var accessController: AccessController
    @State private var query = ""
    @State private var musicMode: MusicLibraryMode = .songs
    @State private var isConfirmingClearDiscoveries = false
    @State private var isShowingDiscoveriesShare = false
    @State private var browserDestination: BrowserDestination?
    @State private var hiddenDiscovery: DiscoveredTrack?
    @State private var selectedArtistName: String?

    let discoveries: [DiscoveredTrack]
    let bottomContentPadding: CGFloat
    let openDiscoveryStation: (DiscoveredTrack) -> Void
    let stationArtworkURL: (DiscoveredTrack) -> URL?
    let toggleDiscoverySaved: (DiscoveredTrack) -> Void
    let hideDiscovery: (DiscoveredTrack) -> Void
    let restoreDiscovery: (DiscoveredTrack) -> Void
    let removeDiscovery: (DiscoveredTrack) -> Void
    let clearDiscoveries: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ShellBrandHeader(
                        statusTitle: musicStatusTitle
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.string("shell.music.title"))
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(AvradioTheme.textPrimary)

                        Text(L10n.string("shell.music.subtitle"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AvradioTheme.textSecondary)
                    }

                    SearchField(query: $query, prompt: L10n.string("shell.music.searchPrompt"))
                    MusicSignalSummary(
                        savedCount: savedDiscoveries.count,
                        historyCount: visibleDiscoveries.count,
                        artistCount: visibleArtistSummaries.count,
                        selectedMode: musicMode,
                        selectMode: { mode in
                            selectedArtistName = nil
                            musicMode = mode
                        }
                    )

                    discoveryLibrarySection
                }
                .padding(24)
                .padding(.bottom, bottomContentPadding)
            }
            .scrollIndicators(.hidden)

            hiddenDiscoveryUndoBanner
        }
        .background(AvradioTheme.shellBackground.ignoresSafeArea())
        .confirmationDialog(
            L10n.string("shell.library.discoveries.clear.confirmTitle"),
            isPresented: $isConfirmingClearDiscoveries,
            titleVisibility: .visible
        ) {
            Button(L10n.string("shell.library.discoveries.clear.confirmAction"), role: .destructive) {
                clearDiscoveries()
            }

            Button(L10n.string("common.cancel"), role: .cancel) {}
        } message: {
            Text(L10n.string("shell.library.discoveries.clear.confirmMessage"))
        }
        .sheet(item: $browserDestination) { destination in
            InAppBrowserView(destination: destination)
        }
        .sheet(isPresented: $isShowingDiscoveriesShare) {
            ShareSheetView(items: [discoveriesShareText])
        }
        .onAppear(perform: normalizeInitialDiscoveryFilter)
        .onChange(of: query) { _, _ in
            selectedArtistName = nil
        }
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var discoveryLibrarySection: some View {
        StationSection(title: L10n.string("shell.music.discoveries.title"), subtitle: L10n.string("shell.music.discoveries.subtitle"), accessibilityIdentifier: "music.section.discoveries") {
            VStack(alignment: .leading, spacing: 16) {
                if filteredDiscoveries.isEmpty && filteredArtistSummaries.isEmpty {
                    EmptyLibraryState(
                        title: emptyDiscoveryTitle,
                        detail: emptyDiscoveryDetail
                    )
                } else {
                    switch musicMode {
                    case .songs:
                        if !filteredArtistSummaries.isEmpty {
                            discoverySubsectionTitle(L10n.string("shell.library.discoveries.artists.title"))

                            ScrollView(.horizontal) {
                                HStack(spacing: 10) {
                                    ForEach(filteredArtistSummaries) { artist in
                                        DiscoveryArtistCard(
                                            summary: artist,
                                            openArtist: { openArtistSongs(artist.name) },
                                            openYouTube: { openArtistSearch(artist.name, youtube: true) },
                                            openAppleMusic: { openAppleMusicArtistSearch(artist.name) },
                                            openSpotify: { openSpotifyArtistSearch(artist.name) }
                                        )
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                            .scrollIndicators(.hidden)
                        }

                        discoverySongsHeader
                        discoveryTrackList
                    case .artists:
                        discoveryArtistsHeader
                        LazyVGrid(columns: artistGridColumns, spacing: 10) {
                            ForEach(filteredArtistSummaries) { artist in
                                DiscoveryArtistCard(
                                    summary: artist,
                                    openArtist: { openArtistSongs(artist.name) },
                                    openYouTube: { openArtistSearch(artist.name, youtube: true) },
                                    openAppleMusic: { openAppleMusicArtistSearch(artist.name) },
                                    openSpotify: { openSpotifyArtistSearch(artist.name) }
                                )
                            }
                        }
                    case .history:
                        discoverySongsHeader
                        discoveryTrackList
                    }
                }
            }
        }
    }

    private var discoveryTrackList: some View {
        VStack(spacing: 10) {
            ForEach(filteredDiscoveries) { discovery in
                DiscoveryTrackCard(
                    discovery: discovery,
                    stationArtworkURL: stationArtworkURL(discovery),
                    openStation: { openDiscoveryStation(discovery) },
                    toggleSaved: { toggleDiscoverySaved(discovery) },
                    openYouTube: { openDiscoverySearch(discovery, suffix: nil, youtube: true) },
                    openLyrics: { openDiscoverySearch(discovery, suffix: "lyrics", youtube: false) },
                    openAppleMusic: { openAppleMusicSearch(discovery) },
                    openSpotify: { openSpotifySearch(discovery) },
                    hideAction: { hideDiscoveryWithUndo(discovery) },
                    removeAction: { removeDiscovery(discovery) }
                )
            }
        }
    }

    private var discoveryArtistsHeader: some View {
        HStack(spacing: 10) {
            Text(L10n.string("shell.music.artists.title"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AvradioTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            discoveryActions
        }
    }

    private var artistGridColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 156, maximum: 220), spacing: 10)
        ]
    }

    private func openArtistSongs(_ artistName: String) {
        selectedArtistName = artistName
        query = artistName
        musicMode = .songs
    }

    private func openArtistSearch(_ artistName: String, youtube: Bool) {
        let feature: LimitedFeature = youtube ? .youtubeSearch : .lyricsSearch
        guard useDailyFeatureIfAllowed(feature) else { return }

        var components = URLComponents(string: youtube ? "https://www.youtube.com/results" : "https://www.google.com/search")
        components?.queryItems = [
            URLQueryItem(name: youtube ? "search_query" : "q", value: artistName)
        ]

        guard let url = components?.url else { return }
        browserDestination = BrowserDestination(url: url)
    }

    private func openAppleMusicArtistSearch(_ artistName: String) {
        guard useDailyFeatureIfAllowed(.appleMusicSearch) else { return }

        var components = URLComponents(string: "https://music.apple.com/search")
        components?.queryItems = [
            URLQueryItem(name: "term", value: artistName)
        ]

        guard let url = components?.url else { return }
        openURL(url)
    }

    private func openSpotifyArtistSearch(_ artistName: String) {
        guard useDailyFeatureIfAllowed(.spotifySearch) else { return }

        guard
            let encodedQuery = artistName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
            let url = URL(string: "https://open.spotify.com/search/\(encodedQuery)")
        else {
            return
        }

        openURL(url)
    }

    private var discoverySongsHeader: some View {
        HStack(spacing: 10) {
            Text(musicMode.songsTitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AvradioTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            discoveryActions
        }
    }

    private var discoveryActions: some View {
        HStack(spacing: 10) {
            Button {
                guard useDailyFeatureIfAllowed(.discoveryShare) else { return }
                isShowingDiscoveriesShare = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AvradioTheme.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(AvradioTheme.mutedSurface, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.string("shell.library.discoveries.share"))
            .accessibilityIdentifier("discoveries.share")
            .disabled(filteredDiscoveries.isEmpty)

            Button {
                isConfirmingClearDiscoveries = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(red: 1, green: 0.17, blue: 0.38))
                    .frame(width: 36, height: 36)
                    .background(AvradioTheme.mutedSurface, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.string("shell.library.discoveries.clear"))
            .accessibilityIdentifier("discoveries.clear")
        }
    }

    @ViewBuilder
    private var hiddenDiscoveryUndoBanner: some View {
        if let hiddenDiscovery {
            HStack(spacing: 12) {
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AvradioTheme.textSecondary)

                Text(L10n.string("shell.music.discovery.hidden"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AvradioTheme.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    restoreDiscovery(hiddenDiscovery)
                    withAnimation(.snappy(duration: 0.22)) {
                        self.hiddenDiscovery = nil
                    }
                } label: {
                    Text(L10n.string("common.undo"))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AvradioTheme.highlight)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("discoveries.undoHide")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(AvradioTheme.elevatedSurface, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(AvradioTheme.borderSubtle, lineWidth: 1)
            }
            .shadow(color: AvradioTheme.softShadow.opacity(0.22), radius: 12, y: 5)
            .padding(.horizontal, 24)
            .padding(.bottom, max(98, bottomContentPadding - 18))
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("discoveries.hiddenUndo")
        }
    }

    private func discoverySubsectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(AvradioTheme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var savedDiscoveries: [DiscoveredTrack] {
        visibleDiscoveries.filter(\.isMarkedInteresting)
    }

    private var visibleDiscoveries: [DiscoveredTrack] {
        discoveries.filter { !$0.isHidden }
    }

    private var musicStatusTitle: String {
        if !savedDiscoveries.isEmpty {
            return L10n.plural(
                singular: "shell.music.status.saved.one",
                plural: "shell.music.status.saved.other",
                count: savedDiscoveries.count,
                savedDiscoveries.count
            )
        }

        if !visibleDiscoveries.isEmpty {
            return L10n.plural(
                singular: "shell.music.status.history.one",
                plural: "shell.music.status.history.other",
                count: visibleDiscoveries.count,
                visibleDiscoveries.count
            )
        }

        return L10n.string("shell.music.status.empty")
    }

    private var filteredDiscoveries: [DiscoveredTrack] {
        let baseDiscoveries = visibleDiscoveries.filter { discovery in
            switch musicMode {
            case .songs, .artists:
                return discovery.isMarkedInteresting
            case .history:
                return true
            }
        }

        let artistFilteredDiscoveries: [DiscoveredTrack]
        if let selectedArtistName {
            artistFilteredDiscoveries = baseDiscoveries.filter {
                $0.artistDisplayText.compare(selectedArtistName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            }
        } else {
            artistFilteredDiscoveries = baseDiscoveries
        }

        guard !trimmedQuery.isEmpty else { return baseDiscoveries }

        return artistFilteredDiscoveries.filter { discovery in
            discovery.title.localizedCaseInsensitiveContains(trimmedQuery) ||
            discovery.artist?.localizedCaseInsensitiveContains(trimmedQuery) == true ||
            discovery.stationName.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    private var filteredArtistSummaries: [DiscoveryArtistSummary] {
        let savedDiscoveries = visibleDiscoveries.filter { discovery in
            switch musicMode {
            case .songs, .artists:
                return discovery.isMarkedInteresting
            case .history:
                return false
            }
        }
        let matchingDiscoveries = trimmedQuery.isEmpty ? savedDiscoveries : savedDiscoveries.filter { discovery in
            discovery.artist?.localizedCaseInsensitiveContains(trimmedQuery) == true ||
            discovery.title.localizedCaseInsensitiveContains(trimmedQuery)
        }

        let grouped = Dictionary(grouping: matchingDiscoveries) { discovery in
            discovery.artistDisplayText
        }

        return grouped
            .map { artist, discoveries in
                DiscoveryArtistSummary(
                    name: artist,
                    trackCount: discoveries.count,
                    artworkURL: discoveries.compactMap(\.resolvedArtworkURL).first
                )
            }
            .sorted { first, second in
                if first.trackCount == second.trackCount {
                    return first.name.localizedCaseInsensitiveCompare(second.name) == .orderedAscending
                }

                return first.trackCount > second.trackCount
            }
    }

    private var visibleArtistSummaries: [DiscoveryArtistSummary] {
        let grouped = Dictionary(grouping: visibleDiscoveries.filter(\.isMarkedInteresting)) { discovery in
            discovery.artistDisplayText
        }

        return grouped
            .map { artist, discoveries in
                DiscoveryArtistSummary(
                    name: artist,
                    trackCount: discoveries.count,
                    artworkURL: discoveries.compactMap(\.resolvedArtworkURL).first
                )
            }
            .sorted { first, second in
                if first.trackCount == second.trackCount {
                    return first.name.localizedCaseInsensitiveCompare(second.name) == .orderedAscending
                }

                return first.trackCount > second.trackCount
            }
    }

    private var discoveriesShareText: String {
        let lines = filteredDiscoveries.map { discovery in
            [
                discovery.artistDisplayText,
                discovery.title,
                discovery.stationName
            ]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: " - ")
        }

        return ([L10n.string("shell.library.discoveries.shareTitle")] + lines).joined(separator: "\n")
    }

    private var emptyDiscoveryTitle: String {
        if visibleDiscoveries.isEmpty {
            return L10n.string("shell.library.discoveries.empty")
        }

        if !trimmedQuery.isEmpty {
            return L10n.string("shell.library.discoveries.noMatch")
        }

        switch musicMode {
        case .songs:
            return L10n.string("shell.library.discoveries.savedEmpty")
        case .artists:
            return L10n.string("shell.music.artists.empty")
        case .history:
            return L10n.string("shell.library.discoveries.noMatch")
        }
    }

    private var emptyDiscoveryDetail: String {
        if visibleDiscoveries.isEmpty {
            return L10n.string("shell.library.discoveries.empty.detail")
        }

        if !trimmedQuery.isEmpty {
            return L10n.string("shell.library.discoveries.noMatch.detail")
        }

        switch musicMode {
        case .songs:
            return L10n.string("shell.library.discoveries.savedEmpty.detail")
        case .artists:
            return L10n.string("shell.music.artists.empty.detail")
        case .history:
            return L10n.string("shell.library.discoveries.noMatch.detail")
        }
    }

    private func normalizeInitialDiscoveryFilter() {
        guard musicMode == .songs, savedDiscoveries.isEmpty, !visibleDiscoveries.isEmpty else {
            return
        }

        musicMode = .history
    }

    private func hideDiscoveryWithUndo(_ discovery: DiscoveredTrack) {
        withAnimation(.snappy(duration: 0.22)) {
            hiddenDiscovery = discovery
            hideDiscovery(discovery)
        }
    }

    private func openDiscoverySearch(_ discovery: DiscoveredTrack, suffix: String?, youtube: Bool) {
        let feature: LimitedFeature = youtube ? .youtubeSearch : .lyricsSearch
        guard useDailyFeatureIfAllowed(feature) else { return }

        var query = discovery.searchQuery
        if let suffix {
            query += " \(suffix)"
        }

        var components = URLComponents(string: youtube ? "https://www.youtube.com/results" : "https://www.google.com/search")
        components?.queryItems = [
            URLQueryItem(name: youtube ? "search_query" : "q", value: query)
        ]

        guard let url = components?.url else { return }
        browserDestination = BrowserDestination(url: url)
    }

    private func openAppleMusicSearch(_ discovery: DiscoveredTrack) {
        guard useDailyFeatureIfAllowed(.appleMusicSearch) else { return }

        var components = URLComponents(string: "https://music.apple.com/search")
        components?.queryItems = [
            URLQueryItem(name: "term", value: discovery.searchQuery)
        ]

        guard let url = components?.url else { return }
        openURL(url)
    }

    private func openSpotifySearch(_ discovery: DiscoveredTrack) {
        guard useDailyFeatureIfAllowed(.spotifySearch) else { return }

        guard
            let encodedQuery = discovery.searchQuery.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
            let url = URL(string: "https://open.spotify.com/search/\(encodedQuery)")
        else {
            return
        }

        openURL(url)
    }

    private func useDailyFeatureIfAllowed(_ feature: LimitedFeature) -> Bool {
        guard accessController.canUseDailyFeature(feature) else {
            accessController.presentUpgradePrompt(for: feature)
            return false
        }

        accessController.recordDailyFeatureUse(feature)
        return true
    }
}

private enum MusicLibraryMode: String, CaseIterable, Identifiable {
    case songs
    case artists
    case history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .songs:
            return L10n.string("shell.music.mode.songs")
        case .artists:
            return L10n.string("shell.music.mode.artists")
        case .history:
            return L10n.string("shell.music.mode.history")
        }
    }

    var songsTitle: String {
        switch self {
        case .songs, .artists:
            return L10n.string("shell.library.discoveries.songs.savedTitle")
        case .history:
            return L10n.string("shell.library.discoveries.songs.historyTitle")
        }
    }
}

private struct DiscoveryArtistSummary: Identifiable {
    let name: String
    let trackCount: Int
    let artworkURL: URL?

    var id: String {
        name
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: L10n.locale)
            .lowercased()
    }
}

private struct MiniPlayerView: View {
    @EnvironmentObject private var audioPlayer: AudioPlayerService

    let station: Station
    let openPlayer: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            miniArtwork

            VStack(alignment: .leading, spacing: 2) {
                Text(station.name)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                    .foregroundStyle(AvradioTheme.textPrimary)

                Text(artistLine)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(trackArtworkExists ? AvradioTheme.highlight : AvradioTheme.textSecondary)
                    .lineLimit(1)

                Text(titleLine)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AvradioTheme.textSecondary.opacity(0.88))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button {
                audioPlayer.togglePlayback()
            } label: {
                ZStack {
                    Circle()
                        .fill(playButtonBackground)

                    if isCurrentStationLoading {
                        ProgressView()
                            .tint(playButtonForeground)
                    } else {
                        Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(playButtonForeground)
                    }
                }
                .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("miniPlayer.playPause")

            if audioPlayer.canCyclePlaybackQueue {
                Button {
                    audioPlayer.playNextInQueue()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AvradioTheme.textSecondary)
                        .frame(width: 34, height: 34)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay {
                            Circle()
                                .stroke(.white.opacity(0.12), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("miniPlayer.next")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AvradioTheme.elevatedSurface)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [AvradioTheme.glassStroke, AvradioTheme.highlight.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: AvradioTheme.glassShadow.opacity(0.7), radius: 8, y: 2)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture(perform: openPlayer)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(L10n.string("shell.miniPlayer.accessibility.label", station.name))
        .accessibilityHint(L10n.string("shell.miniPlayer.accessibility.hint"))
        .accessibilityIdentifier("miniPlayer.container")
    }

    @ViewBuilder
    private var miniArtwork: some View {
        if let artworkURL = audioPlayer.currentTrackArtworkURL {
            AsyncImage(url: artworkURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    StationArtworkView(station: station, size: 46)
                }
            }
            .frame(width: 46, height: 46)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AvradioTheme.borderSubtle.opacity(0.55), lineWidth: 1)
            }
        } else {
            StationThumbnailView(station: station, size: 46)
        }
    }

    private var artistLine: String {
        if let artist = normalizedMetadata(audioPlayer.currentTrackArtist) {
            return artist
        }

        return station.cardDetailText(preferCountryName: station.flagEmoji == nil)
            ?? L10n.string("shell.station.row.defaultDetail")
    }

    private var titleLine: String {
        if let title = normalizedMetadata(audioPlayer.currentTrackTitle) {
            return title
        }

        if let albumTitle = normalizedMetadata(audioPlayer.currentTrackAlbumTitle) {
            return albumTitle
        }

        return L10n.string("player.track.liveStreamActive")
    }

    private var trackArtworkExists: Bool {
        audioPlayer.currentTrackArtworkURL != nil
    }

    private var isCurrentStationLoading: Bool {
        audioPlayer.isCurrent(station) && audioPlayer.isLoading
    }

    private var playButtonBackground: Color {
        if audioPlayer.isPlaying {
            return AvradioTheme.brandGraphite
        }
        return AvradioTheme.highlight
    }

    private var playButtonForeground: Color {
        .white
    }

    private func normalizedMetadata(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct DiscoveryTrackCard: View {
    let discovery: DiscoveredTrack
    let stationArtworkURL: URL?
    let openStation: () -> Void
    let toggleSaved: () -> Void
    let openYouTube: () -> Void
    let openLyrics: () -> Void
    let openAppleMusic: () -> Void
    let openSpotify: () -> Void
    let hideAction: () -> Void
    let removeAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: openStation) {
                HStack(spacing: 12) {
                    artwork

                    VStack(alignment: .leading, spacing: 3) {
                        Text(discovery.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AvradioTheme.textPrimary)
                            .lineLimit(1)

                        Text(discovery.artistDisplayText)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AvradioTheme.highlight)
                            .lineLimit(1)

                        Text(discovery.stationName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AvradioTheme.textSecondary.opacity(0.82))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("\(discovery.title), \(discovery.artistDisplayText), \(discovery.stationName)")
            .accessibilityHint(L10n.string("shell.music.discovery.openStation.hint"))
            .accessibilityIdentifier("discoveryTrack.openStation.\(discovery.discoveryID)")

            discoverySaveButton
            discoveryMenu
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AvradioTheme.cardSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(AvradioTheme.borderSubtle, lineWidth: 1)
                }
        )
        .shadow(color: AvradioTheme.softShadow.opacity(0.18), radius: 8, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("discoveryTrack.\(discovery.discoveryID)")
    }

    private var discoverySaveButton: some View {
        discoveryStateButton(
            systemImage: discovery.isMarkedInteresting ? "bookmark.fill" : "bookmark",
            isActive: discovery.isMarkedInteresting,
            activeColor: AvradioTheme.highlight,
            accessibilityLabel: discovery.isMarkedInteresting
                ? L10n.string("player.discovery.unsave")
                : L10n.string("player.discovery.save"),
            accessibilityIdentifier: "discoveryTrack.save.\(discovery.discoveryID)",
            action: toggleSaved
        )
    }

    private func discoveryStateButton(
        systemImage: String,
        isActive: Bool,
        activeColor: Color,
        accessibilityLabel: String,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(isActive ? activeColor : AvradioTheme.textSecondary)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(isActive ? activeColor.opacity(0.14) : AvradioTheme.mutedSurface)
                )
                .overlay {
                    Circle()
                        .stroke(isActive ? activeColor.opacity(0.28) : AvradioTheme.borderSubtle, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var discoveryMenu: some View {
        Menu {
            Button(L10n.string("player.discovery.youtube"), action: openYouTube)
            Button(L10n.string("player.discovery.lyrics"), action: openLyrics)
            Button(L10n.string("player.discovery.appleMusic"), action: openAppleMusic)
            Button(L10n.string("player.discovery.spotify"), action: openSpotify)

            Button(L10n.string("player.discovery.hide"), role: .destructive, action: hideAction)
            Button(L10n.string("player.discovery.remove"), role: .destructive, action: removeAction)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AvradioTheme.textPrimary)
                .rotationEffect(.degrees(90))
                .frame(width: 34, height: 34)
                .background(AvradioTheme.mutedSurface, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.string("common.more"))
        .accessibilityIdentifier("discoveryTrack.menu.\(discovery.discoveryID)")
    }

    @ViewBuilder
    private var artwork: some View {
        if let artworkURL = discovery.resolvedArtworkURL {
            remoteArtwork(url: artworkURL, fallback: AnyView(fallbackArtwork))
        } else if let stationArtworkURL {
            remoteArtwork(url: stationArtworkURL, fallback: AnyView(fallbackArtwork))
        } else if let stationArtworkURL = discovery.resolvedStationArtworkURL {
            remoteArtwork(url: stationArtworkURL, fallback: AnyView(fallbackArtwork))
        } else {
            fallbackArtwork
        }
    }

    private func remoteArtwork(url: URL, fallback: AnyView) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            default:
                fallback
            }
        }
        .frame(width: 54, height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private var fallbackArtwork: some View {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
            .fill(AvradioTheme.mutedSurface)
            .frame(width: 54, height: 54)
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AvradioTheme.highlight)
            }
    }
}

private struct MusicSignalSummary: View {
    let savedCount: Int
    let historyCount: Int
    let artistCount: Int
    let selectedMode: MusicLibraryMode
    let selectMode: (MusicLibraryMode) -> Void

    var body: some View {
        HStack(spacing: 10) {
            MusicSignalButton(
                title: MusicLibraryMode.songs.title,
                value: savedCount,
                systemImage: "bookmark.fill",
                accessibilityIdentifier: "music.mode.songs",
                isSelected: selectedMode == .songs,
                action: { selectMode(.songs) }
            )

            MusicSignalButton(
                title: MusicLibraryMode.artists.title,
                value: artistCount,
                systemImage: "person.2.fill",
                accessibilityIdentifier: "music.mode.artists",
                isSelected: selectedMode == .artists,
                action: { selectMode(.artists) }
            )

            MusicSignalButton(
                title: MusicLibraryMode.history.title,
                value: historyCount,
                systemImage: "clock.fill",
                accessibilityIdentifier: "music.mode.history",
                isSelected: selectedMode == .history,
                action: { selectMode(.history) }
            )
        }
        .accessibilityElement(children: .contain)
    }
}

private struct MusicSignalButton: View {
    let title: String
    let value: Int
    let systemImage: String
    let accessibilityIdentifier: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .bold))

                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .foregroundStyle(isSelected ? Color.white : AvradioTheme.textSecondary)

                Text("\(value)")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(isSelected ? Color.white : AvradioTheme.textPrimary)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? AvradioTheme.highlight.opacity(0.82) : AvradioTheme.mutedSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(isSelected ? AvradioTheme.highlight.opacity(0.95) : AvradioTheme.borderSubtle, lineWidth: 1)
                    }
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(value)")
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct DiscoveryArtistCard: View {
    let summary: DiscoveryArtistSummary
    let openArtist: () -> Void
    let openYouTube: () -> Void
    let openAppleMusic: () -> Void
    let openSpotify: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: openArtist) {
                HStack(spacing: 10) {
                    artwork

                    VStack(alignment: .leading, spacing: 3) {
                        Text(summary.name)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AvradioTheme.textPrimary)
                            .lineLimit(1)

                        Text(L10n.plural(
                            singular: "shell.library.discoveries.artistSongs.one",
                            plural: "shell.library.discoveries.artistSongs.other",
                            count: summary.trackCount,
                            summary.trackCount
                        ))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AvradioTheme.textSecondary)
                        .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                Button(L10n.string("shell.music.artist.viewSongs"), action: openArtist)
                Button(L10n.string("player.discovery.youtube"), action: openYouTube)
                Button(L10n.string("player.discovery.appleMusic"), action: openAppleMusic)
                Button(L10n.string("player.discovery.spotify"), action: openSpotify)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AvradioTheme.textPrimary)
                    .rotationEffect(.degrees(90))
                    .frame(width: 32, height: 32)
                    .background(AvradioTheme.mutedSurface, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.string("common.more"))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AvradioTheme.cardSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AvradioTheme.borderSubtle, lineWidth: 1)
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("discoveryArtist.\(summary.id)")
    }

    @ViewBuilder
    private var artwork: some View {
        if let artworkURL = summary.artworkURL {
            AsyncImage(url: artworkURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    fallbackArtwork
                }
            }
            .frame(width: 42, height: 42)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        } else {
            fallbackArtwork
        }
    }

    private var fallbackArtwork: some View {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
            .fill(AvradioTheme.mutedSurface)
            .frame(width: 42, height: 42)
            .overlay {
                Image(systemName: "person.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AvradioTheme.highlight)
            }
    }
}

struct ShellBrandHeader: View {
    let statusTitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image("BrandMark")
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 26)
                .padding(10)
                .background(AvradioTheme.cardSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AvradioTheme.borderSubtle, lineWidth: 1)
                }

            (
                Text("AV ")
                    .foregroundStyle(AvradioTheme.textPrimary) +
                Text("Radio")
                    .foregroundStyle(AvradioTheme.highlight)
            )
            .font(.system(size: 22, weight: .bold))

            Spacer()

            ShellStatusPill(title: statusTitle)
        }
    }
}

private struct LiveNowPanel: View {
    @EnvironmentObject private var audioPlayer: AudioPlayerService

    let currentStation: Station?
    let status: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L10n.string("shell.liveNow.title"))
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(AvradioTheme.highlight)

                Spacer()

                ShellStatusPill(title: status)
            }

            HStack(spacing: 12) {
                Group {
                    if let currentStation {
                        StationThumbnailView(station: currentStation, size: 64, surfaceStyle: .dark)
                    } else {
                        EmptyLiveArtwork(size: 64)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(audioPlayer.currentTrackTitle ?? currentStation?.name ?? L10n.string("shell.liveNow.ready"))
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(AvradioTheme.textInverse)
                        .lineLimit(2)

                    if let currentTrackArtist = audioPlayer.currentTrackArtist, !currentTrackArtist.isEmpty {
                        Text(currentTrackArtist)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AvradioTheme.highlight)
                    }

                    Text(audioPlayer.currentTrackAlbumTitle ?? currentStation?.shortMeta ?? L10n.string("shell.liveNow.subtitle.empty"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AvradioTheme.textInverse.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(3)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AvradioTheme.darkSurface)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AvradioTheme.highlight.opacity(0.18))
                        .padding(.top, 18)
                        .padding(.trailing, 16)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(AvradioTheme.borderSubtle.opacity(0.48), lineWidth: 1)
                }
        )
        .shadow(color: AvradioTheme.softShadow.opacity(0.72), radius: 16, y: 8)
    }
}

private struct EmptyLiveArtwork: View {
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        AvradioTheme.darkSurface,
                        AvradioTheme.highlight.opacity(0.04)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
            .overlay {
                ZStack {
                    Circle()
                        .fill(AvradioTheme.highlight.opacity(0.08))
                        .frame(width: size * 0.62, height: size * 0.62)

                    HStack(alignment: .bottom, spacing: size * 0.05) {
                        ForEach([0.28, 0.46, 0.74, 0.46, 0.28], id: \.self) { scale in
                            Capsule(style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            AvradioTheme.textInverse.opacity(0.45),
                                            AvradioTheme.highlight.opacity(0.92)
                                        ],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                )
                                .frame(width: size * 0.07, height: size * CGFloat(scale))
                        }
                    }
                    .frame(height: size * 0.24)
                }
            }
            .shadow(color: AvradioTheme.highlight.opacity(0.07), radius: 10, y: 5)
    }
}

private struct StationThumbnailView: View {
    let station: Station
    let size: CGFloat
    var surfaceStyle: StationArtworkView.SurfaceStyle = .light

    private var cornerRadius: CGFloat {
        size * 0.24
    }

    var body: some View {
        Group {
            if let artworkURL = station.displayArtworkURL {
                AsyncImage(url: artworkURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        StationArtworkView(
                            station: station,
                            size: size,
                            surfaceStyle: surfaceStyle
                        )
                    }
                }
            } else {
                StationArtworkView(
                    station: station,
                    size: size,
                    surfaceStyle: surfaceStyle
                )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .background(
            thumbnailBackground,
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(thumbnailBorder, lineWidth: 1)
        }
        .shadow(color: thumbnailShadow, radius: size * 0.08, y: size * 0.03)
    }

    private var thumbnailBackground: Color {
        switch surfaceStyle {
        case .light:
            return Color.white
        case .dark:
            return AvradioTheme.darkSurface
        }
    }

    private var thumbnailBorder: Color {
        switch surfaceStyle {
        case .light:
            return AvradioTheme.borderSubtle
        case .dark:
            return Color.white.opacity(0.08)
        }
    }

    private var thumbnailShadow: Color {
        switch surfaceStyle {
        case .light:
            return AvradioTheme.softShadow.opacity(0.08)
        case .dark:
            return AvradioTheme.softShadow.opacity(0.18)
        }
    }
}

private struct GenreTagStrip: View {
    let tags: [String]
    let activeTag: String?
    let toggleTag: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(tags, id: \.self) { tag in
                    Button {
                        toggleTag(tag)
                    } label: {
                        Text(L10n.genreLabel(for: tag))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(activeTag == tag ? AvradioTheme.highlight : AvradioTheme.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(activeTag == tag ? AvradioTheme.highlight.opacity(0.1) : AvradioTheme.cardSurface)
                            )
                            .overlay {
                                Capsule(style: .continuous)
                                    .stroke(activeTag == tag ? AvradioTheme.highlight.opacity(0.22) : AvradioTheme.borderSubtle, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 1)
        }
    }
}

private struct SearchCountryFilterButton: View {
    let title: String
    let flag: String?
    let isActive: Bool
    let clearAction: () -> Void
    let openAction: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: openAction) {
                HStack(spacing: 8) {
                    Image(systemName: "globe.europe.africa")
                        .font(.system(size: 14, weight: .semibold))

                    Text(L10n.string("shell.search.country.label"))
                        .font(.system(size: 14, weight: .semibold))

                    if let flag {
                        Text(flag)
                            .font(.system(size: 16))
                    }

                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(1)

                    Spacer(minLength: 6)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(isActive ? AvradioTheme.highlight : AvradioTheme.textPrimary)
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(isActive ? AvradioTheme.highlight.opacity(0.08) : AvradioTheme.cardSurface)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(isActive ? AvradioTheme.highlight.opacity(0.22) : AvradioTheme.borderSubtle, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)

            if isActive {
                Button(action: clearAction) {
                    Text(L10n.string("shell.search.country.clear"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AvradioTheme.highlight)
                        .padding(.horizontal, 14)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(AvradioTheme.cardSurface)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(AvradioTheme.borderSubtle, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct SearchCountryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var libraryStore: LibraryStore

    @Binding var selectedCountryCode: String?

    @State private var query = ""

    private var countryOptions: [CountryOption] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return CountryOption.all }

        return CountryOption.all.filter { option in
            option.name.localizedCaseInsensitiveContains(trimmedQuery) ||
                option.code.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    private var suggestedCountries: [CountryOption] {
        let codes =
            [selectedCountryCode, resolvedDeviceCountryCode()] +
            libraryStore.recentStations().compactMap(\.countryCode) +
            libraryStore.favoriteStations().compactMap(\.countryCode) +
            ["ES", "US", "GB", "FR", "DE", "IT", "MX", "AR"]
        let lookup = Dictionary(uniqueKeysWithValues: CountryOption.all.map { ($0.code, $0) })
        var seen = Set<String>()

        return codes
            .compactMap(CountryOption.sanitizedCode)
            .filter { seen.insert($0).inserted }
            .compactMap { lookup[$0] }
            .prefix(8)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    SearchField(query: $query, prompt: L10n.string("shell.search.country.searchPrompt"))

                    Button {
                        selectedCountryCode = nil
                        dismiss()
                    } label: {
                        CountryRow(
                            title: L10n.string("shell.search.country.all"),
                            subtitle: L10n.string("shell.search.country.allSubtitle"),
                            flag: nil,
                            isSelected: selectedCountryCode == nil
                        )
                    }
                    .buttonStyle(.plain)

                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(L10n.string("shell.search.country.suggested"))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(AvradioTheme.textPrimary)

                            FlowLayout(horizontalSpacing: 10, verticalSpacing: 10) {
                                ForEach(suggestedCountries) { option in
                                    Button {
                                        selectedCountryCode = option.code
                                        dismiss()
                                    } label: {
                                        HStack(spacing: 8) {
                                            if let flag = option.flag {
                                                Text(flag)
                                                    .font(.system(size: 17))
                                            }

                                            Text(option.name)
                                                .font(.system(size: 14, weight: .semibold))
                                                .lineLimit(1)

                                            if selectedCountryCode == option.code {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 11, weight: .bold))
                                            }
                                        }
                                        .foregroundStyle(selectedCountryCode == option.code ? AvradioTheme.highlight : AvradioTheme.textPrimary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 11)
                                        .background(
                                            Capsule(style: .continuous)
                                                .fill(selectedCountryCode == option.code ? AvradioTheme.highlight.opacity(0.1) : AvradioTheme.cardSurface)
                                        )
                                        .overlay {
                                            Capsule(style: .continuous)
                                                .stroke(selectedCountryCode == option.code ? AvradioTheme.highlight.opacity(0.24) : AvradioTheme.borderSubtle, lineWidth: 1)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.top, 6)
                    }

                    ForEach(countryOptions) { option in
                        Button {
                            selectedCountryCode = option.code
                            dismiss()
                        } label: {
                            CountryRow(
                                title: option.name,
                                subtitle: nil,
                                flag: option.flag,
                                isSelected: selectedCountryCode == option.code
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(24)
            }
            .scrollIndicators(.hidden)
            .background(AvradioTheme.shellBackground.ignoresSafeArea())
            .navigationTitle(L10n.string("shell.search.country.pickerTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.string("shell.search.country.done")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func resolvedDeviceCountryCode() -> String? {
        CountryOption.sanitizedCode(
            Locale.autoupdatingCurrent.region?.identifier ?? Locale.current.region?.identifier
        )
    }
}

private struct CountryRow: View {
    let title: String
    let subtitle: String?
    let flag: String?
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? AvradioTheme.highlight.opacity(0.12) : AvradioTheme.mutedSurface)

                if let flag {
                    Text(flag)
                        .font(.system(size: 22))
                } else {
                    Image(systemName: "globe")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AvradioTheme.highlight)
                }
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AvradioTheme.textPrimary)
                    .multilineTextAlignment(.leading)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AvradioTheme.textSecondary)
                }
            }

            Spacer(minLength: 12)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AvradioTheme.highlight)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AvradioTheme.cardSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(isSelected ? AvradioTheme.highlight.opacity(0.22) : AvradioTheme.borderSubtle, lineWidth: 1)
                }
        )
    }
}

private struct CountryOption: Identifiable {
    let code: String
    let name: String

    var id: String { code }

    private static let excludedRegionCodes: Set<String> = [
        "AC", "CP", "CQ", "DG", "EA", "EU", "EZ", "IC", "QO", "TA", "UN"
    ]

    static func sanitizedCode(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }
        let code = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard code.count == 2 else { return nil }
        guard code.unicodeScalars.allSatisfy({ CharacterSet.uppercaseLetters.contains($0) }) else { return nil }
        guard !excludedRegionCodes.contains(code) else { return nil }
        return code
    }

    var flag: String? {
        guard code.count == 2 else { return nil }
        let base: UInt32 = 127397
        let scalars = code.uppercased().unicodeScalars.compactMap { UnicodeScalar(base + $0.value) }
        guard scalars.count == 2 else { return nil }
        return String(String.UnicodeScalarView(scalars))
    }

    static let all: [CountryOption] = Locale.Region.isoRegions.compactMap { region in
        guard let code = sanitizedCode(region.identifier) else { return nil }
        return CountryOption(code: code, name: L10n.countryName(for: code))
    }
    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
}

private struct FeaturedStationCard: View {
    let station: Station
    let label: String
    let subtitle: String
    let isFavorite: Bool
    let playAction: () -> Void
    let favoriteAction: () -> Void
    let detailsAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(label)
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(AvradioTheme.highlight)

            HStack(alignment: .top, spacing: 16) {
                StationThumbnailView(station: station, size: 106)

                VStack(alignment: .leading, spacing: 8) {
                    Text(station.name)
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(AvradioTheme.textPrimary)
                        .lineLimit(3)

                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AvradioTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Button(action: playAction) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                        Text(L10n.string("shell.featured.play"))
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(AvradioTheme.highlight, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(action: favoriteAction) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(isFavorite ? Color(red: 1, green: 0.17, blue: 0.38) : AvradioTheme.textPrimary)
                        .frame(width: 48, height: 48)
                        .background(AvradioTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(AvradioTheme.borderSubtle, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(AvradioTheme.cardSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(AvradioTheme.borderSubtle, lineWidth: 1)
                }
        )
        .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .onTapGesture(perform: detailsAction)
    }
}

private struct StationSection<Content: View>: View {
    let title: String
    let subtitle: String
    let accessibilityIdentifier: String?
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        subtitle: String,
        accessibilityIdentifier: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.accessibilityIdentifier = accessibilityIdentifier
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AvradioTheme.textPrimary)

                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AvradioTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 12) {
                content()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
    }
}

private enum StationRowMetrics {
    static let artworkSize: CGFloat = 62
    static let favoriteButtonSize: CGFloat = 34
    static let playButtonSize: CGFloat = 38
}

private enum StationCompactMetrics {
    static let cardWidth: CGFloat = 112
    static let cardHeight: CGFloat = 164
    static let favoriteButtonSize: CGFloat = 30
    static let playBadgeSize: CGFloat = 36
    static let textLineHeight: CGFloat = 13
}

private struct StationCompactCarousel: View {
    let stations: [Station]
    let favoriteStationIDs: Set<String>
    let nowPlayingTracks: [String: NowPlayingTrack]
    let queueSource: AudioPlayerService.PlaybackQueue.Source
    let queueStations: [Station]
    let playStation: (Station, AudioPlayerService.PlaybackQueue.Source, [Station]?) -> Void
    let toggleFavorite: (Station) -> Void
    let showStationDetails: (Station, AudioPlayerService.PlaybackQueue.Source, [Station]?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(stations) { station in
                    StationCompactCard(
                        station: station,
                        isFavorite: favoriteStationIDs.contains(station.id),
                        nowPlayingTrack: nowPlayingTracks[station.id],
                        toggleFavorite: { toggleFavorite(station) },
                        playAction: { playStation(station, queueSource, queueStations) },
                        detailsAction: { showStationDetails(station, queueSource, queueStations) }
                    )
                    .frame(width: StationCompactMetrics.cardWidth)
                }
            }
            .padding(.horizontal, 1)
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }
}

private struct StationCompactCard: View {
    @EnvironmentObject private var audioPlayer: AudioPlayerService

    let station: Station
    let isFavorite: Bool
    let nowPlayingTrack: NowPlayingTrack?
    let toggleFavorite: () -> Void
    let playAction: () -> Void
    let detailsAction: () -> Void

    private var isPlayingCurrentStation: Bool {
        audioPlayer.isCurrent(station) && audioPlayer.isPlaying
    }

    private var detailText: String {
        station.cardDetailText(preferCountryName: station.flagEmoji == nil)
            ?? L10n.string("shell.station.row.defaultDetail")
    }

    private var artistLine: String {
        if audioPlayer.isCurrent(station), let artist = normalizedMetadata(audioPlayer.currentTrackArtist) {
            return artist
        }

        if let artist = normalizedMetadata(nowPlayingTrack?.artist) {
            return artist
        }

        return detailText
    }

    private var titleLine: String {
        if audioPlayer.isCurrent(station), let title = normalizedMetadata(audioPlayer.currentTrackTitle) {
            return title
        }

        if let title = normalizedMetadata(nowPlayingTrack?.title) {
            return title
        }

        if audioPlayer.isCurrent(station), let albumTitle = normalizedMetadata(audioPlayer.currentTrackAlbumTitle) {
            return albumTitle
        }

        if let primaryTag = station.normalizedTags.first {
            return primaryTag
        }

        return normalizedMetadata(station.language) ?? L10n.string("shell.station.codec.live")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack(alignment: .topTrailing) {
                Button {
                    if audioPlayer.isCurrent(station) {
                        audioPlayer.togglePlayback()
                    } else {
                        playAction()
                    }
                } label: {
                    StationThumbnailView(station: station, size: StationCompactMetrics.cardWidth)
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(isPlayingCurrentStation ? AvradioTheme.highlight.opacity(0.16) : .clear)
                        }
                        .overlay {
                            if audioPlayer.isCurrent(station) {
                                ZStack {
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                    Circle()
                                        .stroke(AvradioTheme.highlight.opacity(0.42), lineWidth: 1)
                                    Image(systemName: isPlayingCurrentStation ? "pause.fill" : "play.fill")
                                        .font(.system(size: 14, weight: .black))
                                        .foregroundStyle(isPlayingCurrentStation ? AvradioTheme.highlight : AvradioTheme.textPrimary)
                                }
                                .frame(width: StationCompactMetrics.playBadgeSize, height: StationCompactMetrics.playBadgeSize)
                            }
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(isPlayingCurrentStation ? AvradioTheme.highlight : AvradioTheme.borderSubtle, lineWidth: isPlayingCurrentStation ? 2 : 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("stationRow.play.\(station.id)")

                favoriteButton
                    .padding(6)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(station.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AvradioTheme.textPrimary)
                    .lineLimit(1)
                    .frame(height: 15, alignment: .leading)

                Text(artistLine)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(audioPlayer.isCurrent(station) ? AvradioTheme.highlight : AvradioTheme.textSecondary.opacity(0.9))
                    .lineLimit(1)
                    .frame(height: 14, alignment: .leading)

                Text(titleLine)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AvradioTheme.textSecondary.opacity(0.74))
                    .lineLimit(1)
                    .frame(height: 13, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: detailsAction)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("stationRow.\(station.id)")
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: StationCompactMetrics.cardHeight, alignment: .top)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture(perform: detailsAction)
    }

    private var favoriteButton: some View {
        Button(action: toggleFavorite) {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isFavorite ? Color(red: 1, green: 0.17, blue: 0.38) : AvradioTheme.textPrimary)
                .frame(width: StationCompactMetrics.favoriteButtonSize, height: StationCompactMetrics.favoriteButtonSize)
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle()
                        .stroke(AvradioTheme.borderSubtle.opacity(0.65), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("stationRow.favorite.\(station.id)")
    }

    private func normalizedMetadata(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct StationDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let station: Station
    let isFavorite: Bool
    let isPlaying: Bool
    let playAction: () -> Void
    let toggleFavorite: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 16) {
                        StationThumbnailView(station: station, size: 104)
                            .overlay {
                                RoundedRectangle(cornerRadius: 25, style: .continuous)
                                    .stroke(isPlaying ? AvradioTheme.highlight : AvradioTheme.borderSubtle, lineWidth: isPlaying ? 2 : 1)
                            }

                        VStack(alignment: .leading, spacing: 10) {
                            Text(station.name)
                                .font(.system(size: 28, weight: .black))
                                .foregroundStyle(AvradioTheme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)

                            if !station.primaryDetailLine.isEmpty {
                                Text(station.primaryDetailLine)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(AvradioTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    HStack(spacing: 10) {
                        Button {
                            playAction()
                            dismiss()
                        } label: {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(AvradioTheme.highlight, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isPlaying ? L10n.string("player.control.pause") : L10n.string("player.control.play"))
                        .accessibilityIdentifier("stationDetail.play")

                        Button(action: toggleFavorite) {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(isFavorite ? Color(red: 1, green: 0.17, blue: 0.38) : AvradioTheme.textPrimary)
                                .frame(width: 50, height: 50)
                                .background(AvradioTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(AvradioTheme.borderSubtle, lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isFavorite ? L10n.string("player.menu.removeFavorite") : L10n.string("player.menu.addFavorite"))

                        if let homepageURL {
                            Button {
                                openURL(homepageURL)
                            } label: {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(AvradioTheme.textPrimary)
                                    .frame(width: 50, height: 50)
                                    .background(AvradioTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(AvradioTheme.borderSubtle, lineWidth: 1)
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(L10n.string("player.menu.openWebsite"))
                        }
                    }
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(AvradioTheme.cardSurface)
                        .overlay {
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(AvradioTheme.borderSubtle, lineWidth: 1)
                        }
                )
                .shadow(color: AvradioTheme.softShadow.opacity(0.22), radius: 12, y: 4)

                if !station.normalizedTags.isEmpty {
                    DetailSection(title: L10n.string("shell.stationDetail.section.tags")) {
                        WrapTagsRow(tags: station.normalizedTags)
                    }
                }

                if !station.technicalBadges.isEmpty {
                    DetailSection(title: L10n.string("shell.stationDetail.section.technical")) {
                        WrapTagsRow(tags: station.technicalBadges, highlighted: true)
                    }
                }

                if !station.popularityBadges.isEmpty {
                    DetailSection(title: L10n.string("shell.stationDetail.section.signals")) {
                        WrapTagsRow(tags: station.popularityBadges)
                    }
                }

                DetailSection(title: L10n.string("shell.stationDetail.section.about")) {
                    VStack(spacing: 12) {
                        DetailInfoRow(title: L10n.string("shell.stationDetail.field.country"), value: station.country)
                        DetailInfoRow(title: L10n.string("shell.stationDetail.field.language"), value: station.language)
                        if let state = station.state, !state.isEmpty {
                            DetailInfoRow(title: L10n.string("shell.stationDetail.field.state"), value: state)
                        }
                        if let countryCode = station.countryCode, !countryCode.isEmpty {
                            DetailInfoRow(title: L10n.string("shell.stationDetail.field.code"), value: countryCode)
                        }
                        if let lastCheckOKAt = formattedLastCheck {
                            DetailInfoRow(title: L10n.string("shell.stationDetail.field.lastCheck"), value: lastCheckOKAt)
                        }
                        if let homepageHost, !homepageHost.isEmpty {
                            DetailInfoRow(title: L10n.string("shell.stationDetail.field.website"), value: homepageHost)
                        }
                    }
                }
            }
            .padding(24)
            .padding(.bottom, 16)
        }
        .background(AvradioTheme.shellBackground.ignoresSafeArea())
    }

    private var homepageURL: URL? {
        guard let homepage = station.homepageURL else { return nil }
        return URL(string: homepage)
    }

    private var homepageHost: String? {
        homepageURL?.host()
    }

    private var formattedLastCheck: String? {
        guard let lastCheckOKAt = station.lastCheckOKAt, !lastCheckOKAt.isEmpty else { return nil }
        guard let date = ISO8601DateFormatter().date(from: lastCheckOKAt) else { return lastCheckOKAt }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

private struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AvradioTheme.textPrimary)

            content()
        }
    }
}

private struct DetailInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AvradioTheme.textSecondary)
                .frame(width: 88, alignment: .leading)

            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AvradioTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }
}

private struct WrapTagsRow: View {
    let tags: [String]
    var highlighted = false

    var body: some View {
        FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(highlighted ? AvradioTheme.highlight : AvradioTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(highlighted ? AvradioTheme.highlight.opacity(0.1) : AvradioTheme.cardSurface)
                    )
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(highlighted ? AvradioTheme.highlight.opacity(0.18) : AvradioTheme.borderSubtle, lineWidth: 1)
                    }
            }
        }
    }
}

private struct FlowLayout: Layout {
    var horizontalSpacing: CGFloat = 8
    var verticalSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxLineWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if lineWidth > 0, lineWidth + horizontalSpacing + size.width > maxWidth {
                totalHeight += lineHeight + verticalSpacing
                maxLineWidth = max(maxLineWidth, lineWidth)
                lineWidth = size.width
                lineHeight = size.height
            } else {
                lineWidth += lineWidth == 0 ? size.width : horizontalSpacing + size.width
                lineHeight = max(lineHeight, size.height)
            }
        }

        maxLineWidth = max(maxLineWidth, lineWidth)
        totalHeight += lineHeight

        return CGSize(width: maxLineWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var origin = CGPoint(x: bounds.minX, y: bounds.minY)
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if origin.x > bounds.minX, origin.x + size.width > bounds.maxX {
                origin.x = bounds.minX
                origin.y += lineHeight + verticalSpacing
                lineHeight = 0
            }

            subview.place(
                at: origin,
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            origin.x += size.width + horizontalSpacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

private struct StationCardSkeletonGroup: View {
    var count: Int = 4

    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<count, id: \.self) { index in
                StationRowSkeletonCard(accentWidth: index == 0 ? 152 : 124)
            }
        }
    }
}

private struct SearchLoadingCard: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(AvradioTheme.highlight)

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.string("shell.search.loading.title"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AvradioTheme.textPrimary)

                Text(L10n.string("shell.search.loading.detail"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AvradioTheme.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AvradioTheme.cardSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AvradioTheme.borderSubtle, lineWidth: 1)
                }
        )
    }
}

private struct StationRowSkeletonCard: View {
    let accentWidth: CGFloat
    @State private var isAnimating = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            SkeletonBlock(cornerRadius: 18)
                .frame(width: StationRowMetrics.artworkSize, height: StationRowMetrics.artworkSize)

            VStack(alignment: .leading, spacing: 10) {
                SkeletonBlock(cornerRadius: 8)
                    .frame(width: accentWidth, height: 16)

                SkeletonBlock(cornerRadius: 7)
                    .frame(width: 116, height: 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)

            Spacer(minLength: 8)

            HStack(spacing: 10) {
                SkeletonBlock(cornerRadius: 17)
                    .frame(width: StationRowMetrics.favoriteButtonSize, height: StationRowMetrics.favoriteButtonSize)
                    .clipShape(Circle())

                SkeletonBlock(cornerRadius: 19)
                    .frame(width: StationRowMetrics.playButtonSize, height: StationRowMetrics.playButtonSize)
                    .clipShape(Circle())
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AvradioTheme.cardSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(AvradioTheme.borderSubtle, lineWidth: 1)
                }
        )
        .opacity(isAnimating ? 1 : 0.72)
        .animation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true), value: isAnimating)
        .onAppear {
            isAnimating = true
        }
    }
}

private struct SkeletonBlock: View {
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        AvradioTheme.mutedSurface.opacity(0.9),
                        AvradioTheme.skeletonHighlight,
                        AvradioTheme.mutedSurface.opacity(0.92)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AvradioTheme.glassStroke, lineWidth: 0.8)
            }
    }
}

private struct SearchField: View {
    @Binding var query: String
    let prompt: String
    let focusRequest: Int?

    @FocusState private var isFocused: Bool

    init(query: Binding<String>, prompt: String? = nil, focusRequest: Int? = nil) {
        _query = query
        self.prompt = prompt ?? L10n.string("shell.search.field.defaultPrompt")
        self.focusRequest = focusRequest
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AvradioTheme.textSecondary)

            TextField(
                text: $query,
                prompt: Text(prompt)
                    .foregroundStyle(AvradioTheme.textSecondary.opacity(0.68))
            ) {
            }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AvradioTheme.textPrimary)
                .tint(AvradioTheme.highlight)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($isFocused)

            if !query.isEmpty {
                Button(L10n.string("shell.search.field.clear")) {
                    query = ""
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AvradioTheme.highlight)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AvradioTheme.cardSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(AvradioTheme.borderSubtle, lineWidth: 1)
                }
        )
        .task(id: focusRequest) {
            guard focusRequest != nil else { return }
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            isFocused = true
        }
    }
}

struct ShellRow: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AvradioTheme.highlight)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AvradioTheme.textPrimary)

                Text(detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AvradioTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct ShellStatusPill: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(AvradioTheme.highlight)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AvradioTheme.highlight.opacity(0.1), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(AvradioTheme.highlight.opacity(0.22), lineWidth: 1)
            }
    }
}

private struct EmptyLibraryState: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AvradioTheme.textPrimary)

            Text(detail)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AvradioTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AvradioTheme.cardSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(AvradioTheme.borderSubtle, lineWidth: 1)
                }
        )
    }
}

#Preview {
    let persistence = PersistenceController(inMemory: true)

    AppShellView()
        .environmentObject(AccessController())
        .environmentObject(AudioPlayerService())
        .environmentObject(LibraryStore(container: persistence.container))
        .modelContainer(persistence.container)
}
