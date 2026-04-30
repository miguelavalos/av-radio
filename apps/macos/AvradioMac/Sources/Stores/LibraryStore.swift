import Foundation

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var favorites: [Station]
    @Published private(set) var recents: [Station]
    @Published private(set) var discoveries: [DiscoveredTrack]
    @Published var preferredTag: String
    @Published var preferredCountryCode: String?
    @Published private(set) var accessMode: AccessMode
    @Published var upgradePrompt: UpgradePromptContext?

    private let defaults: UserDefaults
    private let favoritesKey = "avradio.mac.favorites"
    private let recentsKey = "avradio.mac.recents"
    private let discoveriesKey = "avradio.mac.discoveries"
    private let preferredTagKey = "avradio.mac.preferredTag"
    private let preferredCountryKey = "avradio.mac.preferredCountry"
    private let accessModeKey = "avradio.mac.accessMode"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.favorites = Self.loadStations(forKey: favoritesKey, defaults: defaults)
        self.recents = Self.loadStations(forKey: recentsKey, defaults: defaults)
        self.discoveries = Self.loadDiscoveries(forKey: discoveriesKey, defaults: defaults)
        self.preferredTag = defaults.string(forKey: preferredTagKey) ?? "ambient"
        self.preferredCountryCode = defaults.string(forKey: preferredCountryKey)
        self.accessMode = AccessMode(rawValue: defaults.string(forKey: accessModeKey) ?? "") ?? .guest
        self.favorites = Self.trim(Self.loadStations(forKey: favoritesKey, defaults: defaults), limit: AccessLimits.forMode(accessMode).favoriteStations)
        self.recents = Self.trim(Self.loadStations(forKey: recentsKey, defaults: defaults), limit: AccessLimits.forMode(accessMode).recentStations)
        self.discoveries = Self.trim(Self.loadDiscoveries(forKey: discoveriesKey, defaults: defaults), limit: AccessLimits.forMode(accessMode).discoveredTracks)
    }

    var capabilities: AccessCapabilities {
        AccessCapabilities.forMode(accessMode)
    }

    var limits: AccessLimits {
        AccessLimits.forMode(accessMode)
    }

    func isFavorite(_ station: Station) -> Bool {
        favorites.contains(where: { $0.id == station.id })
    }

    func toggleFavorite(_ station: Station) {
        if let index = favorites.firstIndex(where: { $0.id == station.id }) {
            favorites.remove(at: index)
        } else {
            if let limit = limits.favoriteStations, favorites.count >= limit {
                upgradePrompt = .favorites(current: favorites.count, limit: limit)
                return
            }

            favorites.insert(station, at: 0)
        }

        persist(stations: favorites, key: favoritesKey)
    }

    func recordPlayback(of station: Station) {
        recents.removeAll(where: { $0.id == station.id })
        recents.insert(station, at: 0)
        recents = Self.trim(recents, limit: limits.recentStations)
        persist(stations: recents, key: recentsKey)
    }

    func recordDiscoveredTrack(title: String?, artist: String?, station: Station?, artworkURL: URL?) {
        saveDiscoveredTrack(title: title, artist: artist, station: station, artworkURL: artworkURL, markInteresting: false)
    }

    func markTrackInteresting(title: String?, artist: String?, station: Station?, artworkURL: URL?) {
        if let limit = limits.savedTracks, savedDiscoveriesCount >= limit {
            upgradePrompt = .dailyFeature(.savedTracks, current: savedDiscoveriesCount, limit: limit)
            return
        }
        saveDiscoveredTrack(title: title, artist: artist, station: station, artworkURL: artworkURL, markInteresting: true)
    }

    func toggleDiscoverySaved(_ discovery: DiscoveredTrack) {
        guard let index = discoveries.firstIndex(where: { $0.discoveryID == discovery.discoveryID }) else { return }
        if discoveries[index].isMarkedInteresting {
            discoveries[index].markedInterestedAt = nil
        } else {
            if let limit = limits.savedTracks, savedDiscoveriesCount >= limit {
                upgradePrompt = .dailyFeature(.savedTracks, current: savedDiscoveriesCount, limit: limit)
                return
            }
            discoveries[index].markedInterestedAt = .now
            discoveries[index].hiddenAt = nil
        }
        persist(discoveries: discoveries)
    }

    func hideDiscovery(_ discovery: DiscoveredTrack) {
        guard let index = discoveries.firstIndex(where: { $0.discoveryID == discovery.discoveryID }) else { return }
        discoveries[index].hiddenAt = .now
        discoveries[index].markedInterestedAt = nil
        persist(discoveries: discoveries)
    }

    func restoreDiscovery(_ discovery: DiscoveredTrack) {
        guard let index = discoveries.firstIndex(where: { $0.discoveryID == discovery.discoveryID }) else { return }
        discoveries[index].hiddenAt = nil
        persist(discoveries: discoveries)
    }

    func removeDiscovery(_ discovery: DiscoveredTrack) {
        discoveries.removeAll { $0.discoveryID == discovery.discoveryID }
        persist(discoveries: discoveries)
    }

    func clearDiscoveries() {
        discoveries = []
        persist(discoveries: discoveries)
    }

    func station(for stationID: String?) -> Station? {
        guard let stationID else { return nil }
        return favorites.first(where: { $0.id == stationID }) ?? recents.first(where: { $0.id == stationID })
    }

    func useDailyFeatureIfAllowed(_ feature: LimitedFeature) -> Bool {
        guard let limit = limits.limit(for: feature) else { return true }
        let key = dailyCounterKey(for: feature)
        let current = defaults.integer(forKey: key)
        guard current < limit else {
            upgradePrompt = .dailyFeature(feature, current: current, limit: limit)
            return false
        }
        defaults.set(current + 1, forKey: key)
        return true
    }

    func updateAccessMode(_ mode: AccessMode) {
        accessMode = mode
        defaults.set(mode.rawValue, forKey: accessModeKey)
        favorites = Self.trim(favorites, limit: limits.favoriteStations)
        recents = Self.trim(recents, limit: limits.recentStations)
        discoveries = Self.trim(discoveries, limit: limits.discoveredTracks)
        persist(stations: favorites, key: favoritesKey)
        persist(stations: recents, key: recentsKey)
        persist(discoveries: discoveries)
    }

    func updatePreferredTag(_ tag: String) {
        preferredTag = tag
        defaults.set(tag, forKey: preferredTagKey)
    }

    func updatePreferredCountryCode(_ code: String?) {
        preferredCountryCode = code
        if let code {
            defaults.set(code, forKey: preferredCountryKey)
        } else {
            defaults.removeObject(forKey: preferredCountryKey)
        }
    }

    func clearLocalState() {
        favorites = []
        recents = []
        discoveries = []
        preferredTag = "ambient"
        accessMode = .guest
        defaults.removeObject(forKey: favoritesKey)
        defaults.removeObject(forKey: recentsKey)
        defaults.removeObject(forKey: discoveriesKey)
        defaults.set(preferredTag, forKey: preferredTagKey)
        defaults.removeObject(forKey: preferredCountryKey)
        defaults.set(accessMode.rawValue, forKey: accessModeKey)
        preferredCountryCode = nil
    }

    private func persist(stations: [Station], key: String) {
        guard let data = try? JSONEncoder().encode(stations) else { return }
        defaults.set(data, forKey: key)
    }

    private func persist(discoveries: [DiscoveredTrack]) {
        guard let data = try? JSONEncoder().encode(discoveries) else { return }
        defaults.set(data, forKey: discoveriesKey)
    }

    private var savedDiscoveriesCount: Int {
        discoveries.filter(\.isMarkedInteresting).count
    }

    private func saveDiscoveredTrack(title: String?, artist: String?, station: Station?, artworkURL: URL?, markInteresting: Bool) {
        guard let station, let normalizedTitle = normalizedTrackValue(title) else { return }
        let normalizedArtist = normalizedTrackValue(artist)
        let discoveryID = DiscoveredTrack.makeID(title: normalizedTitle, artist: normalizedArtist, stationID: station.id)

        if let index = discoveries.firstIndex(where: { $0.discoveryID == discoveryID }) {
            discoveries[index].playedAt = .now
            discoveries[index].artworkURL = artworkURL?.absoluteString ?? discoveries[index].artworkURL
            discoveries[index].stationArtworkURL = station.displayArtworkURL?.absoluteString ?? discoveries[index].stationArtworkURL
            if markInteresting {
                discoveries[index].markedInterestedAt = discoveries[index].markedInterestedAt ?? .now
                discoveries[index].hiddenAt = nil
            }
        } else {
            discoveries.insert(
                DiscoveredTrack(
                    title: normalizedTitle,
                    artist: normalizedArtist,
                    station: station,
                    artworkURL: artworkURL,
                    markedInterestedAt: markInteresting ? .now : nil
                ),
                at: 0
            )
        }

        discoveries = Self.trim(discoveries.sorted { $0.playedAt > $1.playedAt }, limit: limits.discoveredTracks)
        persist(discoveries: discoveries)
    }

    private func normalizedTrackValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func dailyCounterKey(for feature: LimitedFeature) -> String {
        let day = ISO8601DateFormatter.string(from: .now, timeZone: .current, formatOptions: [.withFullDate])
        return "avradio.mac.daily.\(feature.rawValue).\(day)"
    }

    private static func loadStations(forKey key: String, defaults: UserDefaults) -> [Station] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Station].self, from: data)) ?? []
    }

    private static func loadDiscoveries(forKey key: String, defaults: UserDefaults) -> [DiscoveredTrack] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([DiscoveredTrack].self, from: data)) ?? []
    }

    private static func trim<T>(_ values: [T], limit: Int?) -> [T] {
        guard let limit else { return values }
        return Array(values.prefix(limit))
    }
}
