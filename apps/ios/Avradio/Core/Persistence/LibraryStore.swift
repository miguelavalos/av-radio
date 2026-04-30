import SwiftData
import SwiftUI

enum CloudSyncStatus: Equatable {
    case idle
    case syncing
    case synced(Date)
    case conflict
    case failed
}

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var favorites: [FavoriteStation] = []
    @Published private(set) var recents: [RecentStation] = []
    @Published private(set) var discoveries: [DiscoveredTrack] = []
    @Published private(set) var settings: AppSettings
    @Published private(set) var cloudSyncStatus: CloudSyncStatus = .idle

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
        let discoveryDescriptor = FetchDescriptor<DiscoveredTrack>(
            sortBy: [SortDescriptor(\.playedAt, order: .reverse)]
        )

        favorites = (try? context.fetch(favoriteDescriptor)) ?? []
        recents = (try? context.fetch(recentDescriptor)) ?? []
        discoveries = (try? context.fetch(discoveryDescriptor)) ?? []

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

    func recordPlayback(of station: Station, recentLimit: Int? = nil) {
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
        trimRecents(limit: recentLimit ?? 20)
        saveAndRefresh()
    }

    func isDiscoveredTrack(title: String?, artist: String?, station: Station?) -> Bool {
        discovery(for: title, artist: artist, station: station) != nil
    }

    func isSavedDiscoveredTrack(title: String?, artist: String?, station: Station?) -> Bool {
        discovery(for: title, artist: artist, station: station)?.isMarkedInteresting == true
    }

    var savedDiscoveriesCount: Int {
        discoveries.filter(\.isMarkedInteresting).count
    }

    private func discovery(for title: String?, artist: String?, station: Station?) -> DiscoveredTrack? {
        guard
            let station,
            let normalizedTitle = normalizedTrackValue(title)
        else {
            return nil
        }

        let discoveryID = DiscoveredTrack.makeID(
            title: normalizedTitle,
            artist: normalizedTrackValue(artist),
            stationID: station.id
        )
        return discoveries.first { $0.discoveryID == discoveryID }
    }

    func canMarkTrackInteresting(title: String?, artist: String?, station: Station?, limit: Int?) -> Bool {
        guard let limit else { return true }
        if isSavedDiscoveredTrack(title: title, artist: artist, station: station) {
            return true
        }

        return savedDiscoveriesCount < limit
    }

    func markTrackInteresting(title: String?, artist: String?, station: Station?, artworkURL: URL?, discoveryLimit: Int? = nil) {
        saveDiscoveredTrack(
            title: title,
            artist: artist,
            station: station,
            artworkURL: artworkURL,
            markInteresting: true,
            discoveryLimit: discoveryLimit
        )
    }

    func toggleDiscoverySaved(_ discovery: DiscoveredTrack, savedLimit: Int? = nil) -> Bool {
        if discovery.isMarkedInteresting {
            discovery.markedInterestedAt = nil
        } else {
            if let savedLimit, savedDiscoveriesCount >= savedLimit {
                return false
            }

            discovery.markedInterestedAt = .now
            discovery.hiddenAt = nil
        }

        saveAndRefresh()
        return true
    }

    func hideDiscovery(_ discovery: DiscoveredTrack) {
        discovery.hiddenAt = .now
        discovery.markedInterestedAt = nil
        saveAndRefresh()
    }

    func restoreDiscovery(_ discovery: DiscoveredTrack) {
        discovery.hiddenAt = nil
        saveAndRefresh()
    }

    func recordDiscoveredTrack(title: String?, artist: String?, station: Station?, artworkURL: URL?, discoveryLimit: Int? = nil) {
        saveDiscoveredTrack(
            title: title,
            artist: artist,
            station: station,
            artworkURL: artworkURL,
            markInteresting: false,
            discoveryLimit: discoveryLimit
        )
    }

    private func saveDiscoveredTrack(
        title: String?,
        artist: String?,
        station: Station?,
        artworkURL: URL?,
        markInteresting: Bool,
        discoveryLimit: Int? = nil
    ) {
        guard
            let station,
            let normalizedTitle = normalizedTrackValue(title)
        else {
            return
        }

        let normalizedArtist = normalizedTrackValue(artist)
        let discoveryID = DiscoveredTrack.makeID(
            title: normalizedTitle,
            artist: normalizedArtist,
            stationID: station.id
        )

        if let existing = discoveries.first(where: { $0.discoveryID == discoveryID }) {
            existing.playedAt = .now
            if markInteresting {
                existing.markedInterestedAt = existing.markedInterestedAt ?? .now
                existing.hiddenAt = nil
            }
            existing.artworkURL = artworkURL?.absoluteString ?? existing.artworkURL
            existing.stationArtworkURL = station.displayArtworkURL?.absoluteString ?? existing.stationArtworkURL
        } else {
            context.insert(
                DiscoveredTrack(
                    title: normalizedTitle,
                    artist: normalizedArtist,
                    station: station,
                    artworkURL: artworkURL,
                    markedInterestedAt: markInteresting ? .now : nil
                )
            )
        }

        trimDiscoveries(limit: discoveryLimit ?? 100)
        saveAndRefresh()
    }

    func removeDiscovery(_ discovery: DiscoveredTrack) {
        context.delete(discovery)
        saveAndRefresh()
    }

    func clearDiscoveries() {
        for discovery in discoveries {
            context.delete(discovery)
        }

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

        for discovery in discoveries {
            context.delete(discovery)
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
            cloudSyncStatus = .idle
            return
        }

        do {
            cloudSyncStatus = .syncing
            let remoteDocument = try await appDataService.pullLibrary()
            let localSnapshot = librarySnapshot()
            let localHasContent = localSnapshot.hasMeaningfulContent
            let localUpdatedAt = latestLocalUpdateAt()

            guard let remoteSnapshot = remoteDocument.snapshot else {
                if localHasContent {
                    try await appDataService.pushLibrary(localSnapshot)
                }
                cloudSyncStatus = .synced(.now)
                return
            }

            let remoteHasContent = remoteSnapshot.hasMeaningfulContent
            if !remoteHasContent {
                if localHasContent {
                    try await appDataService.pushLibrary(localSnapshot)
                }
                cloudSyncStatus = .synced(.now)
                return
            }

            if !localHasContent || remoteDocument.updatedAt > localUpdatedAt {
                applyRemoteSnapshot(remoteSnapshot)
                cloudSyncStatus = .synced(.now)
                return
            }

            if localUpdatedAt > remoteDocument.updatedAt {
                try await appDataService.pushLibrary(localSnapshot)
            }
            cloudSyncStatus = .synced(.now)
        } catch AVRadioAppDataError.conflict {
            cloudSyncStatus = .conflict
        } catch {
            cloudSyncStatus = .failed
            return
        }
    }

    func overwriteCloudLibraryWithLocalData() async {
        guard let appDataService, appDataService.isConfigured() else {
            cloudSyncStatus = .idle
            return
        }

        do {
            cloudSyncStatus = .syncing
            try await appDataService.overwriteLibrary(librarySnapshot())
            cloudSyncStatus = .synced(.now)
        } catch AVRadioAppDataError.conflict {
            cloudSyncStatus = .conflict
        } catch {
            cloudSyncStatus = .failed
        }
    }

    func clearCloudSyncStatus() {
        cloudSyncStatus = .idle
    }

    func setCloudSyncStatusForUITests(_ status: CloudSyncStatus) {
        guard ProcessInfo.processInfo.environment["AVRADIO_UI_TESTS"] == "1" else {
            return
        }

        cloudSyncStatus = status
    }

    private func trimRecents(limit: Int) {
        guard recents.count > limit else { return }
        let sorted = recents.sorted { $0.lastPlayedAt > $1.lastPlayedAt }
        for item in sorted.dropFirst(limit) {
            context.delete(item)
        }
    }

    private func trimDiscoveries(limit: Int) {
        guard discoveries.count > limit else { return }
        let sorted = discoveries.sorted { $0.playedAt > $1.playedAt }
        for item in sorted.dropFirst(limit) {
            context.delete(item)
        }
    }

    private func normalizedTrackValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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
            do {
                cloudSyncStatus = .syncing
                try await appDataService.pushLibrary(snapshot)
                cloudSyncStatus = .synced(.now)
            } catch AVRadioAppDataError.conflict {
                cloudSyncStatus = .conflict
            } catch {
                cloudSyncStatus = .failed
            }
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
            discoveries: discoveries.map(\.appDataRecord),
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
            discoveries.flatMap { discovery in
                [
                    discovery.playedAt,
                    discovery.markedInterestedAt,
                    discovery.hiddenAt
                ].compactMap { $0 }
            } +
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

        for discovery in discoveries {
            context.delete(discovery)
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

        for discovery in snapshot.discoveries {
            context.insert(DiscoveredTrack(record: discovery))
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
