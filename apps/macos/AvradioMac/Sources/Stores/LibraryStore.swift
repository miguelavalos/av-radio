import Foundation

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var favorites: [Station]
    @Published private(set) var recents: [Station]
    @Published var preferredTag: String
    @Published var preferredCountryCode: String?

    private let defaults: UserDefaults
    private let favoritesKey = "avradio.mac.favorites"
    private let recentsKey = "avradio.mac.recents"
    private let preferredTagKey = "avradio.mac.preferredTag"
    private let preferredCountryKey = "avradio.mac.preferredCountry"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.favorites = Self.loadStations(forKey: favoritesKey, defaults: defaults)
        self.recents = Self.loadStations(forKey: recentsKey, defaults: defaults)
        self.preferredTag = defaults.string(forKey: preferredTagKey) ?? "ambient"
        self.preferredCountryCode = defaults.string(forKey: preferredCountryKey)
    }

    func isFavorite(_ station: Station) -> Bool {
        favorites.contains(where: { $0.id == station.id })
    }

    func toggleFavorite(_ station: Station) {
        if let index = favorites.firstIndex(where: { $0.id == station.id }) {
            favorites.remove(at: index)
        } else {
            favorites.insert(station, at: 0)
        }

        persist(stations: favorites, key: favoritesKey)
    }

    func recordPlayback(of station: Station) {
        recents.removeAll(where: { $0.id == station.id })
        recents.insert(station, at: 0)
        recents = Array(recents.prefix(20))
        persist(stations: recents, key: recentsKey)
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
        preferredTag = "ambient"
        defaults.removeObject(forKey: favoritesKey)
        defaults.removeObject(forKey: recentsKey)
        defaults.set(preferredTag, forKey: preferredTagKey)
        defaults.removeObject(forKey: preferredCountryKey)
        preferredCountryCode = nil
    }

    private func persist(stations: [Station], key: String) {
        guard let data = try? JSONEncoder().encode(stations) else { return }
        defaults.set(data, forKey: key)
    }

    private static func loadStations(forKey key: String, defaults: UserDefaults) -> [Station] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Station].self, from: data)) ?? []
    }
}
