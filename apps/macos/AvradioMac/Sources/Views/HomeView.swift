import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var audioPlayer: AudioPlayerService

    let stations: [Station]
    let isLoading: Bool
    let errorMessage: String?
    let favorites: [Station]
    let recents: [Station]
    let feedContext: HomeFeedContext
    let playAction: (Station) -> Void
    let toggleFavorite: (Station) -> Void
    let showDetails: (Station) -> Void

    private enum FeaturedSource {
        case favorite
        case popular
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let compact = width < 860

            ScrollView {
                VStack(alignment: .leading, spacing: compact ? 20 : 24) {
                    ShellHeader(status: isLoading ? "Refreshing" : (audioPlayer.currentStation == nil ? "Live" : currentPlaybackStatus))
                    Text("Listen without friction.")
                        .font(.system(size: compact ? 34 : 40, weight: .bold))
                        .foregroundStyle(AvradioTheme.textPrimary)
                    Text("The same AV Radio flow, adapted for the desktop without turning it into a generic Mac sidebar app.")
                        .font(.system(size: compact ? 15 : 16, weight: .medium))
                        .foregroundStyle(AvradioTheme.textSecondary)

                    if let featured = featuredStation {
                        if compact {
                            VStack(spacing: 16) {
                                FeaturedStationCard(
                                    station: featured,
                                    label: featuredLabel,
                                    subtitle: stationDeck(for: featured),
                                    isFavorite: favorites.contains(where: { $0.id == featured.id }),
                                    playAction: { playAction(featured) },
                                    favoriteAction: { toggleFavorite(featured) },
                                    detailsAction: { showDetails(featured) }
                                )

                                if shouldShowLiveNowPanel {
                                    LiveNowPanel(currentStation: audioPlayer.currentStation, status: currentPlaybackStatus)
                                }
                            }
                        } else {
                            HStack(alignment: .top, spacing: 16) {
                                FeaturedStationCard(
                                    station: featured,
                                    label: featuredLabel,
                                    subtitle: stationDeck(for: featured),
                                    isFavorite: favorites.contains(where: { $0.id == featured.id }),
                                    playAction: { playAction(featured) },
                                    favoriteAction: { toggleFavorite(featured) },
                                    detailsAction: { showDetails(featured) }
                                )
                                .frame(maxWidth: .infinity)

                                if shouldShowLiveNowPanel {
                                    LiveNowPanel(currentStation: audioPlayer.currentStation, status: currentPlaybackStatus)
                                        .frame(width: min(280, width * 0.28))
                                }
                            }
                        }
                    } else if shouldShowLiveNowPanel {
                        LiveNowPanel(currentStation: audioPlayer.currentStation, status: currentPlaybackStatus)
                    }

                    if !displayedRecentStations.isEmpty {
                        StationSection(title: "Recents", subtitle: "Continue where you left off.") {
                            ForEach(displayedRecentStations) { station in
                                StationRowCard(
                                    station: station,
                                    isFavorite: favorites.contains(where: { $0.id == station.id }),
                                    toggleFavorite: { toggleFavorite(station) },
                                    playAction: { playAction(station) },
                                    detailsAction: { showDetails(station) }
                                )
                            }
                        }
                    }

                    if !displayedFavoriteStations.isEmpty {
                        StationSection(title: "Favorites", subtitle: "Pinned stations you come back to.") {
                            ForEach(displayedFavoriteStations) { station in
                                StationRowCard(
                                    station: station,
                                    isFavorite: true,
                                    toggleFavorite: { toggleFavorite(station) },
                                    playAction: { playAction(station) },
                                    detailsAction: { showDetails(station) }
                                )
                            }
                        }
                    }

                    if isLoading && featuredStation == nil && displayedPopularStations.isEmpty {
                        EmptyStateCard(title: "Refreshing stations", detail: "Fetching the latest live feed.")
                    } else if let errorMessage {
                        EmptyStateCard(title: "Feed unavailable", detail: errorMessage)
                    } else if featuredStation != nil {
                        if !displayedPopularStations.isEmpty {
                            StationSection(title: sectionTitle, subtitle: sectionSubtitle) {
                                ForEach(displayedPopularStations) { station in
                                    StationRowCard(
                                        station: station,
                                        isFavorite: favorites.contains(where: { $0.id == station.id }),
                                        toggleFavorite: { toggleFavorite(station) },
                                        playAction: { playAction(station) },
                                        detailsAction: { showDetails(station) }
                                    )
                                }
                            }
                        }
                    } else {
                        EmptyStateCard(title: "Nothing to play yet", detail: "Try a genre search or wait for the feed to refresh.")
                    }
                }
                .frame(maxWidth: compact ? 760 : 1040, alignment: .leading)
                .padding(.horizontal, compact ? 20 : 28)
                .padding(.top, compact ? 22 : 28)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var currentPlaybackStatus: String {
        switch audioPlayer.playbackState {
        case .idle:
            return "Live"
        case .loading:
            return "Loading"
        case .playing:
            return "Playing"
        case .paused:
            return "Paused"
        case .failed:
            return "Error"
        }
    }

    private var hasPersonalActivity: Bool {
        !recents.isEmpty || !favorites.isEmpty
    }

    private var shouldShowLiveNowPanel: Bool {
        audioPlayer.currentStation != nil || !hasPersonalActivity
    }

    private var featuredSource: FeaturedSource? {
        if !favorites.isEmpty { return .favorite }
        if !stations.isEmpty { return .popular }
        return nil
    }

    private var featuredStation: Station? {
        switch featuredSource {
        case .favorite:
            return favorites.first
        case .popular:
            return stations.first
        case .none:
            return nil
        }
    }

    private var displayedRecentStations: [Station] {
        recents
    }

    private var displayedFavoriteStations: [Station] {
        Array(filteredStationsExcludingFeatured(from: favorites).prefix(6))
    }

    private var displayedPopularStations: [Station] {
        let excludedIDs = Set(displayedRecentStations.map(\.id) + displayedFavoriteStations.map(\.id))
        return filteredStationsExcludingFeatured(from: stations)
            .filter { !excludedIDs.contains($0.id) }
    }

    private func filteredStationsExcludingFeatured(from stations: [Station]) -> [Station] {
        guard let featuredStation else { return stations }
        return stations.filter { $0.id != featuredStation.id }
    }

    private func stationDeck(for station: Station) -> String {
        if let flag = station.flagEmoji {
            return "\(flag) \(station.language)"
        }
        return station.shortMeta
    }

    private var featuredLabel: String {
        switch featuredSource {
        case .favorite:
            return "FRONT PAGE"
        case .popular, .none:
            switch feedContext {
            case .popularWorldwide:
                return "POPULAR"
            case .popularInCountry(let countryName):
                return countryName.uppercased(with: .current)
            }
        }
    }

    private var sectionTitle: String {
        switch feedContext {
        case .popularWorldwide:
            return "Popular Worldwide"
        case .popularInCountry(let countryName):
            return "Popular in \(countryName)"
        }
    }

    private var sectionSubtitle: String {
        switch feedContext {
        case .popularWorldwide:
            return "Fresh stations from the live feed."
        case .popularInCountry(let countryName):
            return "Live stations gaining traction in \(countryName)."
        }
    }
}
