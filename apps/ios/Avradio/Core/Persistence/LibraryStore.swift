import SwiftData
import SwiftUI

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var favorites: [FavoriteStation] = []
    @Published private(set) var recents: [RecentStation] = []
    @Published private(set) var settings: AppSettings

    private let context: ModelContext
    private var appDataService: AVRadioAppDataService?
    private var isApplyingRemoteSnapshot = false
    private var pushTask: Task<Void, Never>?

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

    func setPreferredCountry(_ countryCode: String?) {
        settings.preferredCountry = countryCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
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

    func setAppDataService(_ service: AVRadioAppDataService?) {
        appDataService = service
    }

    func refreshCloudLibraryIfNeeded() async {
        guard let appDataService, appDataService.isConfigured() else {
            return
        }

        do {
            let remoteDocument = try await appDataService.pullLibrary()
            let localSnapshot = librarySnapshot()
            let localHasContent = localSnapshot.hasMeaningfulContent
            let localUpdatedAt = latestLocalUpdateAt()

            guard let remoteSnapshot = remoteDocument.snapshot else {
                if localHasContent {
                    try await appDataService.pushLibrary(localSnapshot)
                }
                return
            }

            let remoteHasContent = remoteSnapshot.hasMeaningfulContent
            if !remoteHasContent {
                if localHasContent {
                    try await appDataService.pushLibrary(localSnapshot)
                }
                return
            }

            if !localHasContent || remoteDocument.updatedAt > localUpdatedAt {
                applyRemoteSnapshot(remoteSnapshot)
                return
            }

            if localUpdatedAt > remoteDocument.updatedAt {
                try await appDataService.pushLibrary(localSnapshot)
            }
        } catch {
            return
        }
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
        scheduleCloudPushIfNeeded()
    }

    private func scheduleCloudPushIfNeeded() {
        guard !isApplyingRemoteSnapshot, let appDataService, appDataService.isConfigured() else {
            return
        }

        let snapshot = librarySnapshot()
        pushTask?.cancel()
        pushTask = Task { [snapshot] in
            try? await appDataService.pushLibrary(snapshot)
        }
    }

    private func librarySnapshot() -> AVRadioLibrarySnapshot {
        AVRadioLibrarySnapshot(
            favorites: favorites.map {
                FavoriteStationRecord(
                    station: Station(favorite: $0).appDataRecord,
                    createdAt: AVRadioAppDataService.isoString(from: $0.createdAt)
                )
            },
            recents: recents.map {
                RecentStationRecord(
                    station: Station(recent: $0).appDataRecord,
                    lastPlayedAt: AVRadioAppDataService.isoString(from: $0.lastPlayedAt)
                )
            },
            settings: AppSettingsRecord(
                preferredCountry: settings.preferredCountry,
                preferredLanguage: settings.preferredLanguage,
                preferredTag: settings.preferredTag,
                lastPlayedStationID: settings.lastPlayedStationID,
                sleepTimerMinutes: settings.sleepTimerMinutes,
                updatedAt: AVRadioAppDataService.isoString(from: settings.updatedAt)
            )
        )
    }

    private func latestLocalUpdateAt() -> Date {
        let timestamps =
            favorites.map(\.createdAt) +
            recents.map(\.lastPlayedAt) +
            [settings.updatedAt]
        return timestamps.max() ?? .distantPast
    }

    private func applyRemoteSnapshot(_ snapshot: AVRadioLibrarySnapshot) {
        isApplyingRemoteSnapshot = true
        defer { isApplyingRemoteSnapshot = false }

        for favorite in favorites {
            context.delete(favorite)
        }

        for recent in recents {
            context.delete(recent)
        }

        for favorite in snapshot.favorites {
            context.insert(
                FavoriteStation(
                    station: Station(record: favorite.station),
                    createdAt: Self.date(from: favorite.createdAt)
                )
            )
        }

        for recent in snapshot.recents {
            context.insert(
                RecentStation(
                    station: Station(record: recent.station),
                    lastPlayedAt: Self.date(from: recent.lastPlayedAt)
                )
            )
        }

        settings.preferredCountry = snapshot.settings.preferredCountry
        settings.preferredLanguage = snapshot.settings.preferredLanguage
        settings.preferredTag = snapshot.settings.preferredTag
        settings.lastPlayedStationID = snapshot.settings.lastPlayedStationID
        settings.sleepTimerMinutes = snapshot.settings.sleepTimerMinutes
        settings.updatedAt = Self.date(from: snapshot.settings.updatedAt)

        try? context.save()
        refresh()
    }

    private static func date(from value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? .distantPast
    }
}
