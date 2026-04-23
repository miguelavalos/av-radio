import XCTest

@MainActor
class AvradioUITestCase: XCTestCase {
    @discardableResult
    func launchApp(
        preferredTab: String? = nil,
        extraEnvironment: [String: String] = [:]
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["AVRADIO_UI_TESTS"] = "1"
        app.launchEnvironment["AVRADIO_DISABLE_SPLASH"] = "1"
        app.launchEnvironment["AVRADIO_DISABLE_ONBOARDING"] = "1"

        if let preferredTab {
            app.launchEnvironment["AVRADIO_OPEN_TAB"] = preferredTab
        }

        for (key, value) in extraEnvironment {
            app.launchEnvironment[key] = value
        }

        app.launch()
        return app
    }
}
