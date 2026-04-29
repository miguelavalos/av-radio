import Foundation

struct LaunchContext {
    enum Tab: String {
        case search
        case library
        case music
        case player
        case settings
    }

    let preferredTab: Tab?
    let demoStation: Station?
    let seedFavorite: Bool
    let preferredSearchQuery: String?
    let isUITesting: Bool
    let shouldDisableSplash: Bool
    let shouldDisableOnboarding: Bool
    let shouldSeedUITestLibrary: Bool
    let shouldUseLocalUITestDiscovery: Bool
    let shouldUseLocalUITestSearch: Bool
    let uiTestTrackTitle: String?
    let uiTestTrackArtist: String?

    static let current = LaunchContext(environment: ProcessInfo.processInfo.environment)

    init(environment: [String: String]) {
        isUITesting = environment["AVRADIO_UI_TESTS"] == "1"
            || environment["AIRADIO_UI_TESTS"] == "1"
        shouldDisableSplash = isUITesting
            || environment["AVRADIO_DISABLE_SPLASH"] == "1"
            || environment["AIRADIO_DISABLE_SPLASH"] == "1"
        shouldDisableOnboarding = isUITesting
            || environment["AVRADIO_DISABLE_ONBOARDING"] == "1"
            || environment["AIRADIO_DISABLE_ONBOARDING"] == "1"
        shouldSeedUITestLibrary = environment["AVRADIO_UI_TESTS_DISABLE_LIBRARY_SEED"] != "1"
            && environment["AIRADIO_UI_TESTS_DISABLE_LIBRARY_SEED"] != "1"
        shouldUseLocalUITestDiscovery = environment["AVRADIO_UI_TESTS_LOCAL_DISCOVERY"] == "1"
            || environment["AIRADIO_UI_TESTS_LOCAL_DISCOVERY"] == "1"
        shouldUseLocalUITestSearch = environment["AVRADIO_UI_TESTS_LOCAL_SEARCH"] == "1"
            || environment["AIRADIO_UI_TESTS_LOCAL_SEARCH"] == "1"
        uiTestTrackTitle = environment["AVRADIO_UI_TEST_TRACK_TITLE"]?.nilIfEmpty
            ?? environment["AIRADIO_UI_TEST_TRACK_TITLE"]?.nilIfEmpty
        uiTestTrackArtist = environment["AVRADIO_UI_TEST_TRACK_ARTIST"]?.nilIfEmpty
            ?? environment["AIRADIO_UI_TEST_TRACK_ARTIST"]?.nilIfEmpty
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
