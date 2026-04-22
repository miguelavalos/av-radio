import Foundation

struct LaunchContext {
    enum Tab: String {
        case search
        case library
        case player
        case settings
    }

    let preferredTab: Tab?
    let demoStation: Station?
    let seedFavorite: Bool
    let preferredSearchQuery: String?

    static let current = LaunchContext(environment: ProcessInfo.processInfo.environment)

    init(environment: [String: String]) {
        preferredTab = environment["AVRADIO_OPEN_TAB"].flatMap(Tab.init(rawValue:))
            ?? environment["AIRADIO_OPEN_TAB"].flatMap(Tab.init(rawValue:))
        seedFavorite = environment["AVRADIO_SEED_FAVORITE"] == "1" || environment["AIRADIO_SEED_FAVORITE"] == "1"
        preferredSearchQuery = environment["AVRADIO_SEARCH_QUERY"]?.nilIfEmpty
            ?? environment["AIRADIO_SEARCH_QUERY"]?.nilIfEmpty

        if environment["AVRADIO_DEMO_MODE"] == "1" || environment["AIRADIO_DEMO_MODE"] == "1" {
            demoStation = Station(
                id: "demo-groove-salad",
                name: "SomaFM Groove Salad",
                country: "United States",
                language: "English",
                tags: "ambient,chillout,electronic",
                streamURL: "https://ice1.somafm.com/groovesalad-128-mp3",
                faviconURL: nil,
                bitrate: 128,
                codec: "MP3",
                homepageURL: "https://somafm.com/groovesalad/"
            )
        } else {
            demoStation = nil
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
