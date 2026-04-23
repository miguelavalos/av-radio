import SwiftUI

struct LibraryView: View {
    private enum SortMode: String, CaseIterable, Identifiable {
        case recent = "Recent"
        case alphabetical = "A-Z"
        case country = "Country"

        var id: String { rawValue }
    }

    @State private var query = ""
    @State private var sortMode: SortMode = .recent

    let favorites: [Station]
    let recents: [Station]
    let playAction: (Station) -> Void
    let toggleFavorite: (Station) -> Void
    let showDetails: (Station) -> Void

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let compact = width < 840

            ScrollView {
                VStack(alignment: .leading, spacing: compact ? 20 : 24) {
                    ShellHeader(status: favorites.isEmpty ? "Empty" : "\(favorites.count) saved")
                    Text("Library")
                        .font(.system(size: compact ? 34 : 38, weight: .bold))
                        .foregroundStyle(AvradioTheme.textPrimary)
                    Text("Your local listening history and saved stations live here.")
                        .font(.system(size: compact ? 15 : 16, weight: .medium))
                        .foregroundStyle(AvradioTheme.textSecondary)

                    LibrarySummaryRow(
                        favoritesCount: favorites.count,
                        recentsCount: recents.count,
                        latestStationName: recents.first?.name
                    )

                    if compact {
                        VStack(alignment: .leading, spacing: 12) {
                            librarySearchField
                            sortPicker
                        }
                    } else {
                        HStack(alignment: .center, spacing: 16) {
                            librarySearchField
                            sortPicker
                                .frame(width: 220)
                        }
                    }

                    StationSection(title: "Favorites", subtitle: favoritesSubtitle) {
                        if sortedFavorites.isEmpty {
                            EmptyStateCard(
                                title: favorites.isEmpty ? "No favorites yet" : "No favorite matches",
                                detail: favorites.isEmpty ? "Save stations from Home or Search." : "Try another filter query."
                            )
                        } else {
                            ForEach(sortedFavorites) { station in
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

                    if !sortedRecents.isEmpty {
                        StationSection(title: "Recents", subtitle: recentsSubtitle) {
                            ForEach(sortedRecents) { station in
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
                }
                .frame(maxWidth: compact ? 760 : 1040, alignment: .leading)
                .padding(.horizontal, compact ? 20 : 28)
                .padding(.top, compact ? 22 : 28)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var sortedFavorites: [Station] {
        sortStations(filterStations(favorites), preserveOrder: false)
    }

    private var sortedRecents: [Station] {
        sortStations(filterStations(recents), preserveOrder: sortMode == .recent)
    }

    private func filterStations(_ stations: [Station]) -> [Station] {
        guard !trimmedQuery.isEmpty else { return stations }

        return stations.filter { station in
            station.name.localizedCaseInsensitiveContains(trimmedQuery) ||
            station.country.localizedCaseInsensitiveContains(trimmedQuery) ||
            station.tags.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    private func sortStations(_ stations: [Station], preserveOrder: Bool) -> [Station] {
        guard !preserveOrder else { return stations }

        switch sortMode {
        case .recent:
            return stations
        case .alphabetical:
            return stations.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .country:
            return stations.sorted {
                if $0.country.localizedCaseInsensitiveCompare($1.country) == .orderedSame {
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                return $0.country.localizedCaseInsensitiveCompare($1.country) == .orderedAscending
            }
        }
    }

    private var favoritesSubtitle: String {
        switch sortMode {
        case .recent:
            return "Pinned stations stay here."
        case .alphabetical:
            return "Pinned stations sorted alphabetically."
        case .country:
            return "Pinned stations grouped by country."
        }
    }

    private var recentsSubtitle: String {
        switch sortMode {
        case .recent:
            return "Latest playback sessions."
        case .alphabetical:
            return "Recent stations sorted alphabetically."
        case .country:
            return "Recent stations grouped by country."
        }
    }

    private var librarySearchField: some View {
        TextField("Filter stations in your library", text: $query)
            .textFieldStyle(.plain)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(AvradioTheme.cardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AvradioTheme.borderSubtle, lineWidth: 1)
            }
    }

    private var sortPicker: some View {
        Picker("Sort", selection: $sortMode) {
            ForEach(SortMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }
}

struct ProfileView: View {
    @Binding var preferredTag: String
    let clearAction: () -> Void
    @AppStorage("avradio.mac.appearance") private var appearanceMode = "system"
    @AppStorage("avradio.mac.launchToSearch") private var launchToSearch = false
    @AppStorage("avradio.mac.keepMiniPlayerVisible") private var keepMiniPlayerVisible = true

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let compact = width < 900

            ScrollView {
                VStack(alignment: .leading, spacing: compact ? 20 : 24) {
                    ShellHeader(status: "Settings")
                    Text("Profile")
                        .font(.system(size: compact ? 34 : 38, weight: .bold))
                        .foregroundStyle(AvradioTheme.textPrimary)
                    Text("Preferences for the standalone macOS app.")
                        .font(.system(size: compact ? 15 : 16, weight: .medium))
                        .foregroundStyle(AvradioTheme.textSecondary)

                    ProfileSummaryRow(
                        preferredTag: preferredTag,
                        appearanceMode: appearanceLabel,
                        launchToSearch: launchToSearch
                    )

                    if compact {
                        VStack(spacing: 16) {
                            discoveryCard
                            appearanceCard
                            localDataCard
                            aboutCard
                        }
                    } else {
                        HStack(alignment: .top, spacing: 16) {
                            VStack(spacing: 16) {
                                discoveryCard
                                localDataCard
                            }
                            .frame(maxWidth: .infinity, alignment: .top)

                            VStack(spacing: 16) {
                                appearanceCard
                                aboutCard
                            }
                            .frame(maxWidth: .infinity, alignment: .top)
                        }
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

    private var discoveryCard: some View {
        SettingsCard(title: "Discovery", subtitle: "Tune what the app prioritizes when you open it.") {
            SettingsFieldRow(
                title: "Preferred discovery tag",
                description: "This drives the default feed when Search opens with no query."
            ) {
                TextField("ambient", text: $preferredTag)
                    .textFieldStyle(.roundedBorder)
            }

            Toggle(isOn: $launchToSearch) {
                SettingsLabel(
                    title: "Open in Search",
                    description: "Launch straight into search and browsing instead of Home."
                )
            }
            .toggleStyle(.switch)
        }
    }

    private var appearanceCard: some View {
        SettingsCard(title: "Appearance", subtitle: "Desktop-specific display preferences.") {
            SettingsFieldRow(
                title: "Appearance",
                description: "Choose how the standalone Mac app renders its chrome."
            ) {
                Picker("Appearance", selection: $appearanceMode) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
            }

            Toggle(isOn: $keepMiniPlayerVisible) {
                SettingsLabel(
                    title: "Keep mini player visible",
                    description: "Leave the bottom transport pinned while browsing."
                )
            }
            .toggleStyle(.switch)
        }
    }

    private var localDataCard: some View {
        SettingsCard(title: "Local Data", subtitle: "Everything in this Mac app stays on-device.") {
            SettingsStatsRow(title: "Favorites", value: "Saved locally")
            SettingsStatsRow(title: "History", value: "Recent playback retained on this Mac")

            Button("Clear local library", action: clearAction)
                .buttonStyle(.bordered)
        }
    }

    private var aboutCard: some View {
        SettingsCard(title: "About", subtitle: "Independent macOS edition.") {
            SettingsStatsRow(title: "Edition", value: "macOS standalone")
            SettingsStatsRow(title: "Design", value: "Aligned with AV Radio iOS")
            SettingsStatsRow(title: "Storage", value: "Local preferences only")
        }
    }

    private var appearanceLabel: String {
        switch appearanceMode {
        case "light":
            return "Light"
        case "dark":
            return "Dark"
        default:
            return "System"
        }
    }
}
