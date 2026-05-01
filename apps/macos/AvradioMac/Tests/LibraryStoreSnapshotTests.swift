import XCTest
@testable import AvradioMac

@MainActor
final class LibraryStoreSnapshotTests: XCTestCase {
    func testApplyLibrarySnapshotPersistsRoundTripState() {
        let defaults = isolatedUserDefaults()
        let store = LibraryStore(defaults: defaults)
        let favorite = stationRecord(id: "favorite")
        let recent = stationRecord(id: "recent")
        let snapshot = AVRadioLibrarySnapshot(
            favorites: [
                FavoriteStationRecord(
                    station: favorite,
                    createdAt: "2026-04-30T10:00:00.000Z"
                )
            ],
            recents: [
                RecentStationRecord(
                    station: recent,
                    lastPlayedAt: "2026-04-30T11:00:00.000Z"
                )
            ],
            discoveries: [
                DiscoveredTrackRecord(
                    discoveryID: "track-recent",
                    title: "Midnight Signal",
                    artist: "AV Artist",
                    stationID: "recent",
                    stationName: "Station recent",
                    artworkURL: "https://example.com/track.jpg",
                    stationArtworkURL: "https://example.com/station.jpg",
                    playedAt: "2026-04-30T11:30:00.000Z",
                    markedInterestedAt: "2026-04-30T11:31:00.000Z",
                    hiddenAt: nil
                )
            ],
            settings: AppSettingsRecord(
                preferredCountry: "ES",
                preferredLanguage: "",
                preferredTag: "ambient",
                lastPlayedStationID: "recent",
                sleepTimerMinutes: nil,
                updatedAt: "2026-04-30T12:00:00.000Z"
            )
        )

        store.applyLibrarySnapshot(snapshot)
        let reloadedStore = LibraryStore(defaults: defaults)
        let reloadedSnapshot = reloadedStore.librarySnapshot()

        XCTAssertEqual(reloadedSnapshot.favorites.map(\.station.id), ["favorite"])
        XCTAssertEqual(reloadedSnapshot.recents.map(\.station.id), ["recent"])
        XCTAssertEqual(reloadedSnapshot.discoveries.map(\.discoveryID), ["track-recent"])
        XCTAssertEqual(reloadedSnapshot.discoveries.first?.title, "Midnight Signal")
        XCTAssertEqual(reloadedSnapshot.discoveries.first?.artist, "AV Artist")
        XCTAssertEqual(reloadedSnapshot.settings.preferredCountry, "ES")
        XCTAssertEqual(reloadedSnapshot.settings.preferredTag, "ambient")
        XCTAssertEqual(reloadedSnapshot.settings.lastPlayedStationID, "recent")
    }

    func testApplyLibrarySnapshotClearsEmptyCountryAndDefaultsEmptyTag() {
        let defaults = isolatedUserDefaults()
        let store = LibraryStore(defaults: defaults)
        let snapshot = AVRadioLibrarySnapshot(
            favorites: [],
            recents: [],
            discoveries: [],
            settings: AppSettingsRecord(
                preferredCountry: "",
                preferredLanguage: "",
                preferredTag: "",
                lastPlayedStationID: nil,
                sleepTimerMinutes: nil,
                updatedAt: "2026-04-30T12:00:00.000Z"
            )
        )

        store.applyLibrarySnapshot(snapshot)
        let reloadedStore = LibraryStore(defaults: defaults)

        XCTAssertNil(reloadedStore.preferredCountryCode)
        XCTAssertEqual(reloadedStore.preferredTag, "ambient")
    }

    func testDailyFeatureUsageKeysOnlyCountUniqueUses() {
        let store = LibraryStore(defaults: isolatedUserDefaults())
        let lyricsURL = "https://www.google.com/search?q=artist%20song%20lyrics"

        XCTAssertTrue(store.useDailyFeatureIfAllowed(.lyricsSearch, usageKey: lyricsURL))
        XCTAssertTrue(store.useDailyFeatureIfAllowed(.lyricsSearch, usageKey: lyricsURL))
        XCTAssertTrue(store.useDailyFeatureIfAllowed(.lyricsSearch, usageKey: "  \(lyricsURL.uppercased())  "))

        XCTAssertTrue(store.useDailyFeatureIfAllowed(.lyricsSearch, usageKey: "https://www.google.com/search?q=artist%20song%202%20lyrics"))
        XCTAssertTrue(store.useDailyFeatureIfAllowed(.lyricsSearch, usageKey: "https://www.google.com/search?q=artist%20song%203%20lyrics"))
        XCTAssertTrue(store.useDailyFeatureIfAllowed(.lyricsSearch, usageKey: "https://www.google.com/search?q=artist%20song%204%20lyrics"))
        XCTAssertTrue(store.useDailyFeatureIfAllowed(.lyricsSearch, usageKey: "https://www.google.com/search?q=artist%20song%205%20lyrics"))

        XCTAssertTrue(store.useDailyFeatureIfAllowed(.lyricsSearch, usageKey: lyricsURL))
        XCTAssertFalse(store.useDailyFeatureIfAllowed(.lyricsSearch, usageKey: "https://www.google.com/search?q=artist%20song%206%20lyrics"))
    }

    private func isolatedUserDefaults() -> UserDefaults {
        let suiteName = "LibraryStoreSnapshotTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        return userDefaults
    }

    private func stationRecord(id: String) -> StationRecord {
        StationRecord(
            id: id,
            name: "Station \(id)",
            country: "Spain",
            countryCode: "ES",
            state: nil,
            language: "Spanish",
            languageCodes: "es",
            tags: "ambient,radio",
            streamURL: "https://example.com/\(id).mp3",
            faviconURL: "https://example.com/\(id).png",
            bitrate: 128,
            codec: "MP3",
            homepageURL: "https://example.com/\(id)",
            votes: nil,
            clickCount: nil,
            clickTrend: nil,
            isHLS: false,
            hasExtendedInfo: false,
            hasSSLError: false,
            lastCheckOKAt: nil,
            geoLatitude: nil,
            geoLongitude: nil
        )
    }
}
