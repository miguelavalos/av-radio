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
    @State private var searchResults: [Station] = []
    @State private var searchIsLoading = false
    @State private var searchErrorMessage: String?
    @State private var homeStations: [Station] = []
    @State private var homeIsLoading = false
    @State private var homeErrorMessage: String?
    @State private var homeFeedContext: HomeFeedContext = .popularWorldwide
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
        .task {
            await refreshHomeFeed()
        }
        .task(id: searchRequestKey) {
            await loadSearchResults()
        }
        .onChange(of: audioPlayer.currentStation?.id) { _, stationID in
            guard stationID != nil, let station = audioPlayer.currentStation else { return }
            libraryStore.recordPlayback(of: station)
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
                recentStations: recentStations,
                favoriteStations: favoriteStations,
                feedContext: homeFeedContext,
                bottomContentPadding: shellScrollBottomPadding,
                favoriteStationIDs: favoriteStationIDs,
                playStation: playStation,
                toggleFavorite: libraryStore.toggleFavorite(for:),
                showStationDetails: { selectedStation = $0 }
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
        "\(searchQuery.trimmingCharacters(in: .whitespacesAndNewlines))|\(searchTag ?? "")|\(searchCountryCode ?? "")"
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

    private func playStation(_ station: Station) {
        audioPlayer.play(station: station)
        libraryStore.recordPlayback(of: station)
    }

    private func refreshHomeFeed() async {
        homeIsLoading = true
        homeErrorMessage = nil

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
            homeIsLoading = false
        } catch is CancellationError {
            homeIsLoading = false
        } catch {
            homeStations = defaultEditorialStations
            homeFeedContext = .popularWorldwide
            homeErrorMessage = defaultEditorialStations.isEmpty ? L10n.string("shell.error.home") : nil
            homeIsLoading = false
        }
    }

    private func loadSearchResults() async {
        let queryText = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let tagText = searchTag?.trimmingCharacters(in: .whitespacesAndNewlines)
        let countryCode = searchCountryCode?.trimmingCharacters(in: .whitespacesAndNewlines)
        let requestKey = "\(queryText)|\(tagText ?? "")|\(countryCode ?? "")"

        searchIsLoading = true
        searchErrorMessage = nil

        do {
            try await Task.sleep(for: .milliseconds(300))
            try Task.checkCancellation()

            let results: [Station]

            if queryText.isEmpty && (tagText?.isEmpty != false) && (countryCode?.isEmpty != false) {
                results = try await loadWorldwideDiscoveryStations(limit: 12)
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

    private func loadWorldwideDiscoveryStations(limit: Int) async throws -> [Station] {
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
                filters: .init(query: "", countryCode: code, limit: 4, allowsEmptySearch: true)
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

private enum HomeFeedContext: Equatable {
    case popularInCountry(String)
    case popularWorldwide
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
    let recentStations: [Station]
    let favoriteStations: [Station]
    let feedContext: HomeFeedContext
    let bottomContentPadding: CGFloat
    let favoriteStationIDs: Set<String>
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
                        label: featuredLabel,
                        subtitle: stationDeck(for: featuredStation),
                        isFavorite: favoriteStationIDs.contains(featuredStation.id),
                        playAction: { playStation(featuredStation) },
                        favoriteAction: { toggleFavorite(featuredStation) },
                        detailsAction: { showStationDetails(featuredStation) }
                    )

                    if stations.count > 1 {
                        StationSection(
                            title: sectionTitle,
                            subtitle: sectionSubtitle
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

                if !favoriteStations.isEmpty {
                    StationSection(title: L10n.string("shell.home.favorites.title"), subtitle: L10n.string("shell.home.favorites.subtitle")) {
                        ForEach(Array(favoriteStations.prefix(6))) { station in
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

    private var featuredLabel: String {
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
    let bottomContentPadding: CGFloat
    let favoriteStationIDs: Set<String>
    let playStation: (Station) -> Void
    let toggleFavorite: (Station) -> Void
    let showStationDetails: (Station) -> Void

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

                SearchField(query: $query)
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
                        StationArtworkView(station: currentStation, size: 64, surfaceStyle: .dark)
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
    static let artworkSize: CGFloat = 62
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

    private var detailText: String? {
        station.cardDetailText(preferCountryName: station.flagEmoji == nil)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            StationArtworkView(station: station, size: StationRowMetrics.artworkSize)

            VStack(alignment: .leading, spacing: 5) {
                Text(station.name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AvradioTheme.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let detailText {
                    HStack(spacing: 6) {
                        if let flagEmoji = station.flagEmoji {
                            Text(flagEmoji)
                                .font(.system(size: 12))
                        }

                        Text(detailText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AvradioTheme.textSecondary.opacity(0.88))
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Spacer(minLength: 14)

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
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(AvradioTheme.cardSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(AvradioTheme.borderSubtle, lineWidth: 1)
                }
        )
        .shadow(color: AvradioTheme.softShadow.opacity(0.28), radius: 12, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
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
