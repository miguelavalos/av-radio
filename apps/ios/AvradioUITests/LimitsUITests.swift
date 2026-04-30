import XCTest

@MainActor
final class LimitsUITests: AvradioUITestCase {
    func testFavoriteLimitShowsUpgradePrompt() {
        let app = launchApp(
            extraEnvironment: [
                "AVRADIO_UI_TESTS_FORCE_GUEST": "1",
                "AVRADIO_UI_TESTS_DISABLE_LIBRARY_SEED": "1",
                "AVRADIO_DEMO_MODE": "1",
                "AVRADIO_UI_TEST_FAVORITE_LIMIT": "0"
            ]
        )

        let recentsSection = app.otherElements["home.section.recents"]
        XCTAssertTrue(recentsSection.waitForExistence(timeout: 5))

        let favoriteButton = recentsSection.descendants(matching: .button)["stationRow.favorite.demo-groove-salad"].firstMatch
        XCTAssertTrue(favoriteButton.waitForExistence(timeout: 5))
        favoriteButton.tap()

        let upgradeSheet = app.descendants(matching: .any)["limits.upgrade.sheet.favoriteStations"].firstMatch
        XCTAssertTrue(upgradeSheet.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["limits.upgrade.message"].exists)

        let dismissButton = app.descendants(matching: .any)["limits.upgrade.dismiss"].firstMatch
        XCTAssertTrue(dismissButton.exists)
        dismissButton.tap()

        XCTAssertFalse(upgradeSheet.exists)
    }

    func testYouTubeLimitShowsUpgradePromptInNowPlaying() {
        let app = launchApp(
            preferredTab: "player",
            extraEnvironment: [
                "AVRADIO_UI_TESTS_FORCE_GUEST": "1",
                "AVRADIO_DEMO_MODE": "1",
                "AVRADIO_UI_TEST_TRACK_TITLE": "Midnight City",
                "AVRADIO_UI_TEST_TRACK_ARTIST": "M83",
                "AVRADIO_UI_TEST_YOUTUBE_LIMIT": "0",
                "AVRADIO_UI_TEST_UPGRADE_PROMPT_FEATURE": "youtubeSearch"
            ]
        )

        let artworkFront = app.descendants(matching: .any)["player.artwork.front"].firstMatch
        XCTAssertTrue(artworkFront.waitForExistence(timeout: 5))

        let upgradeMessage = app.descendants(matching: .any)["limits.upgrade.message"].firstMatch
        XCTAssertTrue(upgradeMessage.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["limits.upgrade.dismiss"].exists)
    }

}
