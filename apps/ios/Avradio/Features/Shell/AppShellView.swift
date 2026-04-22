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
    @State private var searchResults: [Station] = []
    @State private var searchIsLoading = false
    @State private var searchErrorMessage: String?
    @State private var homeTag: String?
    @State private var homeStations: [Station] = []
    @State private var homeIsLoading = false
    @State private var homeErrorMessage: String?
    @State private var selectedStation: Station?
    @State private var didBootstrap = false

    private let stationService = StationService()
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
        .fullScreenCover(isPresented: $isShowingNowPlaying) {
            NowPlayingView()
                .environmentObject(audioPlayer)
                .environmentObject(libraryStore)
        }
        .sheet(item: $selectedStation) { station in
            StationDetailSheet(
                station: station,
                isFavorite: favoriteStationIDs.contains(station.id),
                isPlaying: audioPlayer.isCurrent(station) && audioPlayer.isPlaying,
                playAction: { playStation(station) },
                toggleFavorite: { libraryStore.toggleFavorite(for: station) }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .task {
            await bootstrapIfNeeded()
        }
        .task(id: homeTag) {
            await refreshHomeFeed()
        }
        .task(id: searchRequestKey) {
            await loadSearchResults()
        }
        .onChange(of: audioPlayer.currentStation?.id) { _, stationID in
            guard stationID != nil, let station = audioPlayer.currentStation else { return }
            libraryStore.recordPlayback(of: station)
        }
        .onChange(of: accessController.accessMode) { _, newMode in
            applyConnectedAccountHomePreference(for: newMode)
        }
        .onChange(of: libraryStore.settings.preferredTag) { _, _ in
            applyConnectedAccountHomePreference(for: accessController.accessMode)
        }
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch selectedTab {
        case .home:
            HomeScreen(
                stations: homeStations,
                isLoading: homeIsLoading,
                errorMessage: homeErrorMessage,
                activeTag: homeTag,
                tags: genreTags,
                recentStations: recentStations,
                bottomContentPadding: shellScrollBottomPadding,
                favoriteStationIDs: favoriteStationIDs,
                toggleTag: toggleHomeTag,
                playStation: playStation,
                toggleFavorite: libraryStore.toggleFavorite(for:),
                showStationDetails: { selectedStation = $0 }
            )
        case .search:
            SearchScreen(
                query: $searchQuery,
                activeTag: $searchTag,
                results: searchResults,
                isLoading: searchIsLoading,
                errorMessage: searchErrorMessage,
                tags: genreTags,
                bottomContentPadding: shellScrollBottomPadding,
                favoriteStationIDs: favoriteStationIDs,
                playStation: playStation,
                toggleFavorite: libraryStore.toggleFavorite(for:),
                showStationDetails: { selectedStation = $0 }
            )
        case .library:
            LibraryScreen(
                favorites: favoriteStations,
                recents: recentStations,
                bottomContentPadding: shellScrollBottomPadding,
                favoriteStationIDs: favoriteStationIDs,
                playStation: playStation,
                toggleFavorite: libraryStore.toggleFavorite(for:),
                showStationDetails: { selectedStation = $0 }
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
        "\(searchQuery.trimmingCharacters(in: .whitespacesAndNewlines))|\(searchTag ?? "")"
    }

    private var shellScrollBottomPadding: CGFloat {
        // The footer is visually detached and floats above scroll content,
        // so scrollable screens need extra trailing space to bring the last row above it.
        audioPlayer.currentStation == nil ? 96 : 168
    }

    private func bootstrapIfNeeded() async {
        guard !didBootstrap else { return }
        didBootstrap = true

        audioPlayer.setSleepTimer(minutes: libraryStore.settings.sleepTimerMinutes)
        applyConnectedAccountHomePreference(for: accessController.accessMode)

        if let preferredTab = launchContext.preferredTab {
            switch preferredTab {
            case .search:
                selectedTab = .search
            case .library:
                selectedTab = .library
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
        }
    }

    private func toggleHomeTag(_ tag: String) {
        homeTag = homeTag == tag ? nil : tag
    }

    private func applyConnectedAccountHomePreference(for accessMode: AccessMode) {
        let preferredTag = libraryStore.settings.preferredTag

        guard accessMode != .guest else {
            if homeTag == preferredTag {
                homeTag = nil
            }
            return
        }

        guard !preferredTag.isEmpty else { return }
        guard homeTag == nil || homeTag == preferredTag else { return }
        homeTag = preferredTag
    }

    private func playStation(_ station: Station) {
        audioPlayer.play(station: station)
        libraryStore.recordPlayback(of: station)
    }

    private func refreshHomeFeed() async {
        guard let homeTag, !homeTag.isEmpty else {
            homeStations = defaultEditorialStations
            homeIsLoading = false
            homeErrorMessage = nil
            return
        }

        homeIsLoading = true
        homeErrorMessage = nil

        do {
            homeStations = try await stationService.searchStations(
                filters: .init(query: "", tag: homeTag, limit: 8)
            )
            homeIsLoading = false
        } catch is CancellationError {
            homeIsLoading = false
        } catch {
            homeStations = []
            homeErrorMessage = L10n.string("shell.error.home")
            homeIsLoading = false
        }
    }

    private func loadSearchResults() async {
        let queryText = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let tagText = searchTag?.trimmingCharacters(in: .whitespacesAndNewlines)
        let requestKey = "\(queryText)|\(tagText ?? "")"

        guard !queryText.isEmpty || tagText != nil else {
            searchResults = []
            searchErrorMessage = nil
            searchIsLoading = false
            return
        }

        searchIsLoading = true
        searchErrorMessage = nil

        do {
            try await Task.sleep(for: .milliseconds(300))
            try Task.checkCancellation()

            let results = try await stationService.searchStations(
                filters: .init(query: queryText, tag: tagText ?? "", limit: queryText.isEmpty ? 12 : 24)
            )
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
}

private enum AppShellTab: Equatable {
    case home
    case search
    case library
    case profile

    init(_ preferredTab: LaunchContext.Tab?, preferredSearchQuery: String?) {
        switch preferredTab {
        case .search:
            self = .search
        case .library:
            self = .library
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
        VStack(spacing: 10) {
            footerPlayer()

            HStack(spacing: 18) {
                HStack {
                    AppShellFooterTabButton(
                        title: L10n.string("tab.home"),
                        systemImage: "house.fill",
                        isSelected: selectedTab == .home,
                        selectionNamespace: footerSelectionAnimation
                    ) {
                        selectTab(.home)
                    }

                    AppShellFooterTabButton(
                        title: L10n.string("tab.library"),
                        systemImage: "heart.fill",
                        isSelected: selectedTab == .library,
                        selectionNamespace: footerSelectionAnimation
                    ) {
                        selectTab(.library)
                    }

                    AppShellFooterTabButton(
                        title: L10n.string("tab.profile"),
                        systemImage: "person.crop.circle.fill",
                        isSelected: selectedTab == .profile,
                        selectionNamespace: footerSelectionAnimation
                    ) {
                        selectTab(.profile)
                    }
                }
                .padding(.leading, 14)
                .padding(.trailing, 14)
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
            .frame(maxWidth: 372)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, -8)
        .ignoresSafeArea(edges: .bottom)
    }
}

private struct AppShellFooterTabButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let selectionNamespace: Namespace.ID
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
            .frame(width: 82, height: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
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
    }
}

private struct HomeScreen: View {
    @EnvironmentObject private var audioPlayer: AudioPlayerService

    let stations: [Station]
    let isLoading: Bool
    let errorMessage: String?
    let activeTag: String?
    let tags: [String]
    let recentStations: [Station]
    let bottomContentPadding: CGFloat
    let favoriteStationIDs: Set<String>
    let toggleTag: (String) -> Void
    let playStation: (Station) -> Void
    let toggleFavorite: (Station) -> Void
    let showStationDetails: (Station) -> Void

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

                GenreTagStrip(tags: tags, activeTag: activeTag, toggleTag: toggleTag)

                LiveNowPanel(currentStation: audioPlayer.currentStation, status: audioPlayer.status.label)

                if isLoading && stations.isEmpty {
                    StationCardSkeletonGroup()
                } else if let errorMessage {
                    EmptyLibraryState(
                        title: L10n.string("shell.home.error.title"),
                        detail: errorMessage
                    )
                } else if let featuredStation = stations.first {
                    FeaturedStationCard(
                        station: featuredStation,
                        label: activeTag.map { L10n.genreLabel(for: $0).uppercased(with: .current) } ?? L10n.string("shell.home.featured.frontPage").uppercased(with: .current),
                        subtitle: stationDeck(for: featuredStation),
                        isFavorite: favoriteStationIDs.contains(featuredStation.id),
                        playAction: { playStation(featuredStation) },
                        favoriteAction: { toggleFavorite(featuredStation) },
                        detailsAction: { showStationDetails(featuredStation) }
                    )

                    if stations.count > 1 {
                        StationSection(
                            title: activeTag == nil
                                ? L10n.string("shell.home.section.freshPicks.title")
                                : L10n.string("shell.home.section.topGenre.title", L10n.genreLabel(for: activeTag ?? "")),
                            subtitle: activeTag == nil
                                ? L10n.string("shell.home.section.freshPicks.subtitle")
                                : L10n.string("shell.home.section.topGenre.subtitle")
                        ) {
                            ForEach(Array(stations.dropFirst())) { station in
                                StationRowCard(
                                    station: station,
                                    isFavorite: favoriteStationIDs.contains(station.id),
                                    toggleFavorite: { toggleFavorite(station) },
                                    playAction: { playStation(station) },
                                    detailsAction: { showStationDetails(station) }
                                )
                            }
                        }
                    }
                } else {
                    EmptyLibraryState(
                        title: L10n.string("shell.home.empty.title"),
                        detail: L10n.string("shell.home.empty.detail")
                    )
                }

                if !recentStations.isEmpty {
                    StationSection(title: L10n.string("shell.home.recents.title"), subtitle: L10n.string("shell.home.recents.subtitle")) {
                        ForEach(recentStations) { station in
                            StationRowCard(
                                station: station,
                                isFavorite: favoriteStationIDs.contains(station.id),
                                toggleFavorite: { toggleFavorite(station) },
                                playAction: { playStation(station) },
                                detailsAction: { showStationDetails(station) }
                            )
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

    private func stationDeck(for station: Station) -> String {
        let codec = station.codec ?? L10n.string("shell.station.codec.live")
        return "\(station.country) · \(station.language) · \(codec)"
    }
}

private struct SearchScreen: View {
    @Binding var query: String
    @Binding var activeTag: String?

    let results: [Station]
    let isLoading: Bool
    let errorMessage: String?
    let tags: [String]
    let bottomContentPadding: CGFloat
    let favoriteStationIDs: Set<String>
    let playStation: (Station) -> Void
    let toggleFavorite: (Station) -> Void
    let showStationDetails: (Station) -> Void

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

                SearchField(query: $query)
                GenreTagStrip(tags: tags, activeTag: activeTag, toggleTag: toggleTag)

                StationSection(
                    title: queryText.isEmpty ? L10n.string("shell.search.section.browse.title") : L10n.string("shell.search.section.results.title"),
                    subtitle: queryText.isEmpty
                        ? L10n.string("shell.search.section.browse.subtitle")
                        : L10n.plural(
                            singular: "shell.search.results.count.one",
                            plural: "shell.search.results.count.other",
                            count: results.count,
                            results.count,
                            queryText
                        )
                ) {
                    if !results.isEmpty {
                        if isLoading {
                            SearchLoadingCard()
                        }

                        ForEach(results) { station in
                            StationRowCard(
                                station: station,
                                isFavorite: favoriteStationIDs.contains(station.id),
                                toggleFavorite: { toggleFavorite(station) },
                                playAction: { playStation(station) },
                                detailsAction: { showStationDetails(station) }
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
    }

    private var queryText: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func toggleTag(_ tag: String) {
        activeTag = activeTag == tag ? nil : tag
    }
}

private struct LibraryScreen: View {
    @State private var query = ""

    let favorites: [Station]
    let recents: [Station]
    let bottomContentPadding: CGFloat
    let favoriteStationIDs: Set<String>
    let playStation: (Station) -> Void
    let toggleFavorite: (Station) -> Void
    let showStationDetails: (Station) -> Void

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

                StationSection(title: L10n.string("shell.library.favorites.title"), subtitle: L10n.string("shell.library.favorites.subtitle")) {
                    if filteredFavorites.isEmpty {
                        EmptyLibraryState(
                            title: favorites.isEmpty ? L10n.string("shell.library.favorites.empty") : L10n.string("shell.library.favorites.noMatch"),
                            detail: favorites.isEmpty
                                ? L10n.string("shell.library.favorites.empty.detail")
                                : L10n.string("shell.library.favorites.noMatch.detail")
                        )
                    } else {
                        ForEach(filteredFavorites) { station in
                            StationRowCard(
                                station: station,
                                isFavorite: favoriteStationIDs.contains(station.id),
                                toggleFavorite: { toggleFavorite(station) },
                                playAction: { playStation(station) },
                                detailsAction: { showStationDetails(station) }
                            )
                        }
                    }
                }

                if !filteredRecents.isEmpty {
                    StationSection(title: L10n.string("shell.library.recents.title"), subtitle: L10n.string("shell.library.recents.subtitle")) {
                        ForEach(filteredRecents) { station in
                            StationRowCard(
                                station: station,
                                isFavorite: favoriteStationIDs.contains(station.id),
                                toggleFavorite: { toggleFavorite(station) },
                                playAction: { playStation(station) },
                                detailsAction: { showStationDetails(station) }
                            )
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

private struct MiniPlayerView: View {
    @EnvironmentObject private var audioPlayer: AudioPlayerService
    @EnvironmentObject private var libraryStore: LibraryStore

    let station: Station
    let openPlayer: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            StationArtworkView(station: station, size: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text(station.name)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                    .foregroundStyle(AvradioTheme.textPrimary)

                HStack(spacing: 8) {
                    Circle()
                        .fill(audioPlayer.isPlaying ? AvradioTheme.highlight : AvradioTheme.textSecondary)
                        .frame(width: 7, height: 7)

                    Text(audioPlayer.status.label)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AvradioTheme.textSecondary)
                        .lineLimit(1)
                }

                if let trackLine {
                    Text(trackLine)
                        .font(.caption2)
                        .foregroundStyle(AvradioTheme.textSecondary.opacity(0.88))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Button {
                libraryStore.toggleFavorite(for: station)
            } label: {
                Image(systemName: libraryStore.isFavorite(station) ? "heart.fill" : "heart")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(libraryStore.isFavorite(station) ? Color(red: 1.0, green: 0.16, blue: 0.38) : AvradioTheme.textSecondary)
                    .frame(width: 34, height: 34)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)

            Button {
                audioPlayer.togglePlayback()
            } label: {
                Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(AvradioTheme.highlight, in: Circle())
            }
            .buttonStyle(.plain)
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
    }

    private var trackLine: String? {
        switch (audioPlayer.currentTrackArtist, audioPlayer.currentTrackTitle) {
        case let (.some(artist), .some(title)) where !artist.isEmpty && !title.isEmpty:
            return "\(artist) · \(title)"
        case let (_, .some(title)) where !title.isEmpty:
            return title
        default:
            return nil
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
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(L10n.string("shell.liveNow.title"))
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(AvradioTheme.highlight)

                Spacer()

                ShellStatusPill(title: status)
            }

            HStack(spacing: 16) {
                Group {
                    if let currentStation {
                        StationArtworkView(station: currentStation, size: 82)
                    } else {
                        StationArtworkView(station: Station.samples[0], size: 82)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(audioPlayer.currentTrackTitle ?? currentStation?.name ?? L10n.string("shell.liveNow.ready"))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(AvradioTheme.textInverse)
                        .lineLimit(2)

                    if let currentTrackArtist = audioPlayer.currentTrackArtist, !currentTrackArtist.isEmpty {
                        Text(currentTrackArtist)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AvradioTheme.highlight)
                    }

                    Text(audioPlayer.currentTrackAlbumTitle ?? currentStation?.shortMeta ?? L10n.string("shell.liveNow.subtitle.empty"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AvradioTheme.textInverse.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(AvradioTheme.darkSurface)
                .overlay(alignment: .topTrailing) {
                    ZStack {
                        Circle()
                            .stroke(AvradioTheme.highlight.opacity(0.18), lineWidth: 1)
                            .frame(width: 140, height: 140)
                        Circle()
                            .stroke(AvradioTheme.highlight.opacity(0.08), lineWidth: 1)
                            .frame(width: 190, height: 190)
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(AvradioTheme.highlight.opacity(0.85))
                    }
                    .padding(.top, 18)
                    .padding(.trailing, 14)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(AvradioTheme.borderSubtle.opacity(0.55), lineWidth: 1)
                }
        )
        .shadow(color: AvradioTheme.softShadow, radius: 30, y: 16)
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
                StationArtworkView(station: station, size: 106)

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
    @ViewBuilder let content: () -> Content

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
    }
}

private enum StationRowMetrics {
    static let artworkSize: CGFloat = 58
    static let favoriteButtonSize: CGFloat = 34
    static let playButtonSize: CGFloat = 38
}

private struct StationRowCard: View {
    @EnvironmentObject private var audioPlayer: AudioPlayerService

    let station: Station
    let isFavorite: Bool
    let toggleFavorite: () -> Void
    let playAction: () -> Void
    let detailsAction: () -> Void

    private var isPlayingCurrentStation: Bool {
        audioPlayer.isCurrent(station) && audioPlayer.isPlaying
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            StationArtworkView(station: station, size: StationRowMetrics.artworkSize)

            VStack(alignment: .leading, spacing: 4) {
                Text(station.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AvradioTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(station.shortMeta)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AvradioTheme.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Spacer(minLength: 8)

            Button(action: toggleFavorite) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(isFavorite ? Color(red: 1, green: 0.17, blue: 0.38) : AvradioTheme.textSecondary)
                    .frame(width: StationRowMetrics.favoriteButtonSize, height: StationRowMetrics.favoriteButtonSize)
                    .background(AvradioTheme.mutedSurface, in: Circle())
            }
            .buttonStyle(.plain)

            Button {
                if audioPlayer.isCurrent(station) {
                    audioPlayer.togglePlayback()
                } else {
                    playAction()
                }
            } label: {
                Image(systemName: isPlayingCurrentStation ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isPlayingCurrentStation ? .white : AvradioTheme.textSecondary)
                    .frame(width: StationRowMetrics.playButtonSize, height: StationRowMetrics.playButtonSize)
                    .background(
                        isPlayingCurrentStation ? AnyShapeStyle(AvradioTheme.highlight) : AnyShapeStyle(AvradioTheme.mutedSurface),
                        in: Circle()
                    )
            }
            .buttonStyle(.plain)
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
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture(perform: detailsAction)
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
                HStack(alignment: .top, spacing: 16) {
                    StationArtworkView(station: station, size: 92)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(station.name)
                            .font(.system(size: 28, weight: .black))
                            .foregroundStyle(AvradioTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        if !station.primaryDetailLine.isEmpty {
                            Text(station.primaryDetailLine)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(AvradioTheme.textSecondary)
                        }

                        if !station.normalizedTags.isEmpty {
                            WrapTagsRow(tags: Array(station.normalizedTags.prefix(4)))
                        }
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        playAction()
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            Text(isPlaying ? L10n.string("audio.status.playing") : L10n.string("player.control.play"))
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(AvradioTheme.highlight, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)

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

    init(query: Binding<String>, prompt: String? = nil) {
        _query = query
        self.prompt = prompt ?? L10n.string("shell.search.field.defaultPrompt")
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
