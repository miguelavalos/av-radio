import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var libraryStore: LibraryStore
    @EnvironmentObject private var audioPlayer: AudioPlayerService

    @State private var selectedSection: SidebarSection = .home
    @State private var selectedStation: Station?
    @State private var searchQuery = ""
    @State private var searchResults: [Station] = []
    @State private var searchIsLoading = false
    @State private var searchErrorMessage: String?
    @State private var activeSearchTag: String?
    @State private var selectedCountryCode: String?
    @State private var isShowingNowPlaying = false
    @State private var detailStation: Station?
    @Namespace private var navigationSelectionAnimation
    @AppStorage("avradio.mac.appearance") private var appearanceMode = "system"
    @AppStorage("avradio.mac.launchToSearch") private var launchToSearch = false
    @AppStorage("avradio.mac.keepMiniPlayerVisible") private var keepMiniPlayerVisible = true

    private let stationService = StationService()
    private let genreTags = ["ambient", "rock", "pop", "jazz", "news", "electronic"]

    var body: some View {
        ZStack {
            AvradioTheme.shellBackground.ignoresSafeArea()

            currentScreen
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(alignment: .bottom) {
            footerNavigation
        }
        .sheet(isPresented: $isShowingNowPlaying) {
            MacNowPlayingView()
                .environmentObject(audioPlayer)
                .environmentObject(libraryStore)
        }
        .sheet(item: $detailStation) { station in
            StationDetailSheet(
                station: station,
                isFavorite: libraryStore.isFavorite(station),
                isPlaying: audioPlayer.isCurrent(station) && audioPlayer.isPlaying,
                playAction: { play(station) },
                toggleFavorite: { libraryStore.toggleFavorite(station) }
            )
        }
        .task {
            selectedStation = libraryStore.recents.first ?? Station.samples.first
            selectedCountryCode = libraryStore.preferredCountryCode
            if launchToSearch {
                selectedSection = .search
                activeSearchTag = libraryStore.preferredTag
            }
            await loadHomeFeedIfNeeded()
        }
        .onChange(of: selectedSection) { _, newValue in
            if newValue == .search {
                Task { await performSearch(force: true) }
            }
        }
        .preferredColorScheme(preferredColorScheme)
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch selectedSection {
        case .home:
            HomeView(
                stations: searchResults.isEmpty ? Station.samples : searchResults,
                isLoading: searchIsLoading && searchResults.isEmpty,
                errorMessage: searchErrorMessage,
                favorites: libraryStore.favorites,
                recents: libraryStore.recents,
                feedContext: .popularWorldwide,
                playAction: play,
                toggleFavorite: libraryStore.toggleFavorite,
                showDetails: { detailStation = $0 }
            )
        case .search:
            SearchView(
                query: $searchQuery,
                activeTag: $activeSearchTag,
                selectedCountryCode: $selectedCountryCode,
                results: searchResults,
                isLoading: searchIsLoading,
                errorMessage: searchErrorMessage,
                genreTags: genreTags,
                playAction: play,
                toggleFavorite: libraryStore.toggleFavorite,
                isFavorite: libraryStore.isFavorite,
                showDetails: { detailStation = $0 },
                searchAction: { Task { await performSearch(force: true) } }
            )
        case .library:
            LibraryView(
                favorites: libraryStore.favorites,
                recents: libraryStore.recents,
                playAction: play,
                toggleFavorite: libraryStore.toggleFavorite,
                showDetails: { detailStation = $0 }
            )
        case .profile:
            ProfileView(
                preferredTag: Binding(
                    get: { libraryStore.preferredTag },
                    set: { libraryStore.updatePreferredTag($0) }
                ),
                clearAction: libraryStore.clearLocalState
            )
        }
    }

    private func loadHomeFeedIfNeeded() async {
        guard searchResults.isEmpty else { return }
        await performSearch(initial: true)
    }

    private func play(_ station: Station) {
        selectedStation = station
        libraryStore.recordPlayback(of: station)
        audioPlayer.play(station)
    }

    private func performSearch(initial: Bool = false, force: Bool = false) async {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let tag = activeSearchTag ?? (trimmedQuery.isEmpty ? libraryStore.preferredTag : "")
        let countryCode = selectedCountryCode ?? ""

        if !force, !initial, trimmedQuery.isEmpty, selectedSection != .home, tag.isEmpty, countryCode.isEmpty {
            searchResults = []
            return
        }

        searchIsLoading = true
        searchErrorMessage = nil

        do {
            let results = try await stationService.searchStations(
                filters: .init(
                    query: trimmedQuery,
                    countryCode: countryCode,
                    tag: tag,
                    limit: 24,
                    allowsEmptySearch: initial || !tag.isEmpty || !countryCode.isEmpty
                )
            )
            searchResults = results.isEmpty ? Station.samples : results
        } catch {
            searchResults = Station.samples
            searchErrorMessage = error.localizedDescription
        }

        searchIsLoading = false
    }

    private var footerNavigation: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < 720

            VStack(spacing: 10) {
                if keepMiniPlayerVisible, let currentStation = audioPlayer.currentStation {
                    MiniPlayerBar(station: currentStation) {
                        isShowingNowPlaying = true
                    }
                    .frame(maxWidth: compact ? .infinity : 520)
                }

                HStack(spacing: compact ? 12 : 18) {
                    HStack {
                        FooterTabButton(
                            title: "Home",
                            systemImage: "house.fill",
                            isSelected: selectedSection == .home,
                            selectionNamespace: navigationSelectionAnimation,
                            compact: compact
                        ) {
                            selectedSection = .home
                        }

                        FooterTabButton(
                            title: "Library",
                            systemImage: "heart.fill",
                            isSelected: selectedSection == .library,
                            selectionNamespace: navigationSelectionAnimation,
                            compact: compact
                        ) {
                            selectedSection = .library
                        }

                        FooterTabButton(
                            title: "Profile",
                            systemImage: "person.crop.circle.fill",
                            isSelected: selectedSection == .profile,
                            selectionNamespace: navigationSelectionAnimation,
                            compact: compact
                        ) {
                            selectedSection = .profile
                        }
                    }
                    .padding(.horizontal, compact ? 10 : 14)
                    .padding(.vertical, compact ? 6 : 7)
                    .background {
                        Capsule(style: .continuous)
                            .fill(AvradioTheme.elevatedSurface)
                            .overlay {
                                Capsule(style: .continuous)
                                    .stroke(AvradioTheme.glassStroke, lineWidth: 1)
                            }
                    }
                    .shadow(color: AvradioTheme.glassShadow, radius: 18, y: 10)

                    FooterSearchButton(isSelected: selectedSection == .search, compact: compact) {
                        selectedSection = .search
                    }
                    .shadow(color: AvradioTheme.glassShadow, radius: 18, y: 10)
                }
                .frame(maxWidth: compact ? .infinity : 420)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.horizontal, compact ? 12 : 18)
            .padding(.bottom, 10)
        }
        .frame(height: keepMiniPlayerVisible && audioPlayer.currentStation != nil ? 124 : 84)
    }

    private var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }
}

private struct FooterTabButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let selectionNamespace: Namespace.ID
    let compact: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AvradioTheme.cardSurface.opacity(0.96))
                        .matchedGeometryEffect(id: "footerSelection", in: selectionNamespace)
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(AvradioTheme.glassStroke, lineWidth: 0.8)
                        }
                }

                Image(systemName: displayedSystemImage)
                    .font(.system(size: compact ? 18 : 20, weight: isSelected ? .semibold : .regular))
                    .frame(width: compact ? 18 : 20, height: compact ? 18 : 20)
                    .symbolRenderingMode(.monochrome)
            }
            .foregroundStyle(isSelected ? AvradioTheme.highlight : AvradioTheme.textSecondary)
            .frame(width: compact ? 68 : 82, height: compact ? 42 : 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
    }

    private var displayedSystemImage: String {
        guard !isSelected else { return systemImage }
        return systemImage.replacingOccurrences(of: ".fill", with: "")
    }
}

private struct FooterSearchButton: View {
    let isSelected: Bool
    let compact: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(AvradioTheme.elevatedSurface)
                    .overlay {
                        Circle()
                            .stroke(AvradioTheme.glassStroke, lineWidth: 1)
                    }

                if isSelected {
                    Circle()
                        .fill(AvradioTheme.cardSurface.opacity(0.96))
                        .padding(4)
                }

                Image(systemName: "magnifyingglass")
                    .font(.system(size: compact ? 20 : 22, weight: .semibold))
                    .foregroundStyle(isSelected ? AvradioTheme.highlight : AvradioTheme.textSecondary)
            }
            .frame(width: compact ? 54 : 62, height: compact ? 54 : 62)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Search")
    }
}

struct SettingsView: View {
    @EnvironmentObject private var libraryStore: LibraryStore

    var body: some View {
        ProfileView(
            preferredTag: Binding(
                get: { libraryStore.preferredTag },
                set: { libraryStore.updatePreferredTag($0) }
            ),
            clearAction: libraryStore.clearLocalState
        )
        .frame(width: 520, height: 420)
    }
}
