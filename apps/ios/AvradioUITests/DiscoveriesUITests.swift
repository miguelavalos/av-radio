import XCTest

@MainActor
final class DiscoveriesUITests: AvradioUITestCase {
    func testLibraryShowsAndFiltersDiscoveries() {
        let app = launchApp(
            preferredTab: "library",
            extraEnvironment: [
                "AVRADIO_UI_TESTS_LOCAL_DISCOVERY": "1",
            ]
        )

        openDiscover(in: app)

        let discoveriesSection = app.otherElements["library.section.discoveries"]
        XCTAssertTrue(discoveriesSection.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Sweet Disposition"].exists)
        XCTAssertFalse(app.staticTexts["Midnight City"].exists)

        showDiscoveryHistory(in: app)

        XCTAssertTrue(app.staticTexts["Midnight City"].exists)
        XCTAssertTrue(app.staticTexts["Sweet Disposition"].exists)
    }

    func testCanRemoveDiscovery() {
        let app = launchApp(
            preferredTab: "library",
            extraEnvironment: [
                "AVRADIO_UI_TESTS_LOCAL_DISCOVERY": "1",
            ]
        )

        openDiscover(in: app)
        showDiscoveryHistory(in: app)

        let discoveriesSection = app.otherElements["library.section.discoveries"]
        XCTAssertTrue(discoveriesSection.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Midnight City"].exists)

        let discovery = app.otherElements.matching(identifier: "discoveryTrack.m83-midnight-city-groove-salad").firstMatch
        XCTAssertTrue(discovery.exists)
        discovery.buttons["Más"].tap()
        app.buttons["Eliminar descubrimiento"].tap()

        XCTAssertFalse(app.staticTexts["Midnight City"].exists)
    }

    func testCanClearAllDiscoveriesAfterConfirmation() {
        let app = launchApp(
            preferredTab: "library",
            extraEnvironment: [
                "AVRADIO_UI_TESTS_LOCAL_DISCOVERY": "1",
            ]
        )

        openDiscover(in: app)
        showDiscoveryHistory(in: app)

        let discoveriesSection = app.otherElements["library.section.discoveries"]
        XCTAssertTrue(discoveriesSection.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Midnight City"].exists)
        XCTAssertTrue(app.staticTexts["Sweet Disposition"].exists)

        discoveriesSection.buttons["discoveries.clear"].tap()

        let confirmButton = app.buttons["Borrar descubrimientos"].firstMatch
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        confirmButton.tap()

        XCTAssertTrue(app.staticTexts["Aún no hay descubrimientos"].waitForExistence(timeout: 5))
    }

    func testCanOpenShareSheetForDiscoveries() {
        let app = launchApp(
            preferredTab: "library",
            extraEnvironment: [
                "AVRADIO_UI_TESTS_LOCAL_DISCOVERY": "1",
            ]
        )

        openDiscover(in: app)

        let discoveriesSection = app.otherElements["library.section.discoveries"]
        XCTAssertTrue(discoveriesSection.waitForExistence(timeout: 5))

        discoveriesSection.buttons["discoveries.share"].tap()

        let shareSheet = app.otherElements["ActivityListView"].firstMatch
        XCTAssertTrue(shareSheet.waitForExistence(timeout: 5))
    }

    func testCanSaveCurrentTrackFromPlayer() {
        let app = launchApp(
            preferredTab: "player",
            extraEnvironment: [
                "AVRADIO_DEMO_MODE": "1",
                "AVRADIO_UI_TESTS_DISABLE_LIBRARY_SEED": "1",
                "AVRADIO_UI_TEST_TRACK_ARTIST": "Massive Attack",
                "AVRADIO_UI_TEST_TRACK_TITLE": "Teardrop",
            ]
        )

        let artwork = app.otherElements["player.artwork.front"].firstMatch
        XCTAssertTrue(artwork.waitForExistence(timeout: 5))
        artwork.tap()

        let saveButton = app.buttons["player.artwork.options.discovery"].firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        app.buttons["player.close"].tap()
        app.buttons["tab.library"].tap()
        openDiscover(in: app)

        let discoveriesSection = app.otherElements["library.section.discoveries"]
        XCTAssertTrue(discoveriesSection.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Teardrop"].exists)
        XCTAssertTrue(app.staticTexts["Massive Attack"].exists)
    }

    func testArtworkFlipsToTrackOptionsAndSavesDiscovery() {
        let app = launchApp(
            preferredTab: "player",
            extraEnvironment: [
                "AVRADIO_DEMO_MODE": "1",
                "AVRADIO_UI_TESTS_DISABLE_LIBRARY_SEED": "1",
                "AVRADIO_UI_TEST_TRACK_ARTIST": "Radiohead",
                "AVRADIO_UI_TEST_TRACK_TITLE": "Reckoner",
            ]
        )

        let artwork = app.otherElements["player.artwork.front"].firstMatch
        XCTAssertTrue(artwork.waitForExistence(timeout: 5))
        artwork.tap()

        XCTAssertTrue(app.staticTexts["Reckoner"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Radiohead"].exists)

        app.buttons["player.artwork.options.discovery"].tap()

        app.buttons["player.close"].tap()
        app.buttons["tab.library"].tap()
        openDiscover(in: app)

        let discoveriesSection = app.otherElements["library.section.discoveries"]
        XCTAssertTrue(discoveriesSection.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Reckoner"].exists)
        XCTAssertTrue(app.staticTexts["Radiohead"].exists)
    }

    func testTrackMetadataOnlyAppearsAfterArtworkFlip() {
        let app = launchApp(
            preferredTab: "player",
            extraEnvironment: [
                "AVRADIO_DEMO_MODE": "1",
                "AVRADIO_UI_TESTS_DISABLE_LIBRARY_SEED": "1",
                "AVRADIO_UI_TEST_TRACK_ARTIST": "Massive Attack",
                "AVRADIO_UI_TEST_TRACK_TITLE": "Teardrop",
            ]
        )

        XCTAssertFalse(app.staticTexts["Teardrop"].waitForExistence(timeout: 1))
        XCTAssertFalse(app.staticTexts["Massive Attack"].exists)

        let artwork = app.otherElements["player.artwork.front"].firstMatch
        XCTAssertTrue(artwork.waitForExistence(timeout: 5))
        artwork.tap()

        XCTAssertTrue(app.staticTexts["Teardrop"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Massive Attack"].exists)
    }

    func testDetectedTrackAppearsWithoutBeingMarkedInteresting() {
        let app = launchApp(
            preferredTab: "player",
            extraEnvironment: [
                "AVRADIO_DEMO_MODE": "1",
                "AVRADIO_UI_TESTS_DISABLE_LIBRARY_SEED": "1",
                "AVRADIO_UI_TEST_TRACK_ARTIST": "Portishead",
                "AVRADIO_UI_TEST_TRACK_TITLE": "Roads",
            ]
        )

        XCTAssertTrue(app.staticTexts["Roads"].waitForExistence(timeout: 5))

        app.buttons["player.close"].tap()
        app.buttons["tab.library"].tap()
        openDiscover(in: app)

        let discoveriesSection = app.otherElements["library.section.discoveries"]
        XCTAssertTrue(discoveriesSection.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Roads"].exists)

        showDiscoveryHistory(in: app)

        XCTAssertTrue(app.staticTexts["Roads"].exists)
        XCTAssertTrue(app.staticTexts["Portishead"].exists)
    }

    private func openDiscover(in app: XCUIApplication) {
        let discoverButton = app.buttons["Descubrir"].firstMatch
        XCTAssertTrue(discoverButton.waitForExistence(timeout: 5))
        discoverButton.tap()
    }

    private func showDiscoveryHistory(in app: XCUIApplication) {
        let filterButton = app.buttons["discoveries.filter"].firstMatch
        XCTAssertTrue(filterButton.waitForExistence(timeout: 5))
        filterButton.tap()

        let historyButton = app.buttons["Historial"].firstMatch
        XCTAssertTrue(historyButton.waitForExistence(timeout: 5))
        historyButton.tap()
    }
}
