import XCTest

@MainActor
final class ProfileUITests: AvradioUITestCase {
    func testProProfileShowsCloudSyncStatusAndRetry() {
        let app = launchApp(
            preferredTab: "settings",
            extraEnvironment: [
                "AVRADIO_UI_TESTS_ACCOUNT_MODE": "pro"
            ]
        )

        let syncCard = app.descendants(matching: .any)["profile.sync.card"].firstMatch
        if !syncCard.waitForExistence(timeout: 3) {
            app.swipeUp()
        }

        XCTAssertTrue(syncCard.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["profile.sync.status"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["profile.sync.retry"].exists)
    }

    func testCloudSyncConflictCanKeepThisDevice() {
        let app = launchApp(
            preferredTab: "settings",
            extraEnvironment: [
                "AVRADIO_UI_TESTS_ACCOUNT_MODE": "pro",
                "AVRADIO_UI_TEST_CLOUD_SYNC_STATUS": "conflict"
            ]
        )

        let conflictAlert = app.alerts["Cloud sync conflict"].firstMatch
        XCTAssertTrue(conflictAlert.waitForExistence(timeout: 5))
        XCTAssertTrue(conflictAlert.buttons["Refresh"].exists)

        conflictAlert.buttons["Keep this device"].tap()

        XCTAssertFalse(conflictAlert.waitForExistence(timeout: 2))
    }

    func testCloudSyncConflictCanRefreshFromCloud() {
        let app = launchApp(
            preferredTab: "settings",
            extraEnvironment: [
                "AVRADIO_UI_TESTS_ACCOUNT_MODE": "pro",
                "AVRADIO_UI_TEST_CLOUD_SYNC_STATUS": "conflict"
            ]
        )

        let conflictAlert = app.alerts["Cloud sync conflict"].firstMatch
        XCTAssertTrue(conflictAlert.waitForExistence(timeout: 5))

        conflictAlert.buttons["Refresh"].tap()

        XCTAssertFalse(conflictAlert.waitForExistence(timeout: 2))
    }
}
