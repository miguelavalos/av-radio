import ClerkKit
import Foundation

@MainActor
enum AppConfig {
    static var avAppsAccountKey: String {
        stringValue(for: "AVAPPS_ACCOUNT_PUBLISHABLE_KEY")
    }

    static var supportEmail: String? {
        nonEmptyStringValue(for: "AVRADIO_SUPPORT_EMAIL")
    }

    static var avAppsAPIBaseURL: URL? {
        urlValue(for: "AVAPPS_API_BASE_URL")
    }

    static var accountManagementURL: URL? {
        urlValue(for: "AVRADIO_ACCOUNT_MANAGEMENT_URL")
    }

    static var termsURL: URL? {
        urlValue(for: "AVRADIO_TERMS_URL")
    }

    static var privacyURL: URL? {
        urlValue(for: "AVRADIO_PRIVACY_URL")
    }

    static var openSourceURL: URL? {
        urlValue(for: "AVRADIO_OPEN_SOURCE_URL")
    }

    static var radioBrowserURL: URL? {
        URL(string: "https://www.radio-browser.info/")
    }

    static var supportURL: URL? {
        guard let supportEmail else { return nil }
        let encodedSubject = "AV Radio Support".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "AV%20Radio%20Support"
        return URL(string: "mailto:\(supportEmail)?subject=\(encodedSubject)")
    }

    static var premiumProductIDs: [String] {
        stringValue(for: "AVRADIO_PREMIUM_PRODUCT_IDS")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    static var isPremiumSubscriptionAvailable: Bool {
        !premiumProductIDs.isEmpty
    }

    static var isAVAppsAccountAvailable: Bool {
        !avAppsAccountKey.isEmpty
    }

    static func configureAVAppsAccountIfPossible() {
        guard isAVAppsAccountAvailable else {
            return
        }

        Clerk.configure(publishableKey: avAppsAccountKey)
    }

    private static func stringValue(for key: String) -> String {
        nonEmptyStringValue(for: key) ?? ""
    }

    private static func nonEmptyStringValue(for key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func urlValue(for key: String) -> URL? {
        guard let rawValue = nonEmptyStringValue(for: key) else {
            return nil
        }
        return URL(string: rawValue)
    }
}
