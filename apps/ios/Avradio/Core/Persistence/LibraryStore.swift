import SwiftData
import SwiftUI

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var favorites: [FavoriteStation] = []
    @Published private(set) var recents: [RecentStation] = []
    @Published private(set) var settings: AppSettings

    private let context: ModelContext

    init(container: ModelContainer) {
        self.context = ModelContext(container)

        if let existingSettings = try? context.fetch(FetchDescriptor<AppSettings>()).first {
            self.settings = existingSettings
        } else {
            let settings = AppSettings()
            context.insert(settings)
            try? context.save()
            self.settings = settings
        }

        refresh()
    }

    func refresh() {
        let favoriteDescriptor = FetchDescriptor<FavoriteStation>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let recentDescriptor = FetchDescriptor<RecentStation>(
            sortBy: [SortDescriptor(\.lastPlayedAt, order: .reverse)]
        )

        favorites = (try? context.fetch(favoriteDescriptor)) ?? []
        recents = (try? context.fetch(recentDescriptor)) ?? []

        if let currentSettings = try? context.fetch(FetchDescriptor<AppSettings>()).first {
            settings = currentSettings
        }
    }

    func isFavorite(_ station: Station) -> Bool {
        favorites.contains { $0.stationID == station.id }
    }

    func toggleFavorite(for station: Station) {
        if let existing = favorites.first(where: { $0.stationID == station.id }) {
            context.delete(existing)
        } else {
            context.insert(FavoriteStation(station: station))
        }

        saveAndRefresh()
    }

    func recordPlayback(of station: Station) {
        if let existing = recents.first(where: { $0.stationID == station.id }) {
            existing.name = station.name
            existing.country = station.country
            existing.countryCode = station.countryCode
            existing.state = station.state
            existing.language = station.language
            existing.languageCodes = station.languageCodes
            existing.tags = station.tags
            existing.streamURL = station.streamURL
            existing.faviconURL = station.faviconURL
            existing.bitrate = station.bitrate
            existing.codec = station.codec
            existing.homepageURL = station.homepageURL
            existing.votes = station.votes
            existing.clickCount = station.clickCount
            existing.clickTrend = station.clickTrend
            existing.isHLS = station.isHLS
            existing.hasExtendedInfo = station.hasExtendedInfo
            existing.hasSSLError = station.hasSSLError
            existing.lastCheckOKAt = station.lastCheckOKAt
            existing.geoLatitude = station.geoLatitude
            existing.geoLongitude = station.geoLongitude
            existing.lastPlayedAt = .now
        } else {
            context.insert(RecentStation(station: station))
        }

        settings.lastPlayedStationID = station.id
        settings.updatedAt = .now
        trimRecents(limit: 20)
        saveAndRefresh()
    }

    func station(for stationID: String?) -> Station? {
        guard let stationID else { return nil }

        if let favorite = favorites.first(where: { $0.stationID == stationID }) {
            return Station(favorite: favorite)
        }

        if let recent = recents.first(where: { $0.stationID == stationID }) {
            return Station(recent: recent)
        }

        return nil
    }

    func ensureSeededStation(_ station: Station, favorite: Bool) {
        if favorite, !isFavorite(station) {
            context.insert(FavoriteStation(station: station))
        }

        if recents.contains(where: { $0.stationID == station.id }) == false {
            context.insert(RecentStation(station: station))
        }

        settings.lastPlayedStationID = station.id
        settings.updatedAt = .now
        saveAndRefresh()
    }

    func favoriteStations() -> [Station] {
        favorites.map(Station.init(favorite:))
    }

    func recentStations() -> [Station] {
        recents.map(Station.init(recent:))
    }

    func setPreferredTag(_ tag: String?) {
        settings.preferredTag = tag?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        settings.updatedAt = .now
        saveAndRefresh()
    }

    func clearLocalData() {
        for favorite in favorites {
            context.delete(favorite)
        }

        for recent in recents {
            context.delete(recent)
        }

        settings.preferredCountry = ""
        settings.preferredLanguage = ""
        settings.preferredTag = ""
        settings.lastPlayedStationID = nil
        settings.sleepTimerMinutes = nil
        settings.updatedAt = .now

        saveAndRefresh()
    }

    private func trimRecents(limit: Int) {
        guard recents.count > limit else { return }
        let sorted = recents.sorted { $0.lastPlayedAt > $1.lastPlayedAt }
        for item in sorted.dropFirst(limit) {
            context.delete(item)
        }
    }

    private func saveAndRefresh() {
        try? context.save()
        refresh()
    }
}
