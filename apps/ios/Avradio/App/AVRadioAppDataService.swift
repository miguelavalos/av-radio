import Foundation

private enum AVRadioAppDataConstants {
    static let appId = "avradio"
    static let resource = "library"
    static let deviceId = "avradio-ios"
}

struct AVRadioLibraryDocument {
    let snapshot: AVRadioLibrarySnapshot?
    let updatedAt: Date
}

struct AVRadioLibrarySnapshot: Codable, Equatable {
    let favorites: [FavoriteStationRecord]
    let recents: [RecentStationRecord]
    let settings: AppSettingsRecord

    var hasMeaningfulContent: Bool {
        !favorites.isEmpty || !recents.isEmpty || settings.hasMeaningfulContent
    }
}

struct FavoriteStationRecord: Codable, Equatable {
    let station: StationRecord
    let createdAt: String
}

struct RecentStationRecord: Codable, Equatable {
    let station: StationRecord
    let lastPlayedAt: String
}

struct AppSettingsRecord: Codable, Equatable {
    let preferredCountry: String
    let preferredLanguage: String
    let preferredTag: String
    let lastPlayedStationID: String?
    let sleepTimerMinutes: Int?
    let updatedAt: String

    var hasMeaningfulContent: Bool {
        !preferredCountry.isEmpty ||
            !preferredLanguage.isEmpty ||
            !preferredTag.isEmpty ||
            lastPlayedStationID != nil ||
            sleepTimerMinutes != nil
    }
}

struct StationRecord: Codable, Equatable {
    let id: String
    let name: String
    let country: String
    let countryCode: String?
    let state: String?
    let language: String
    let languageCodes: String?
    let tags: String
    let streamURL: String
    let faviconURL: String?
    let bitrate: Int?
    let codec: String?
    let homepageURL: String?
    let votes: Int?
    let clickCount: Int?
    let clickTrend: Int?
    let isHLS: Bool?
    let hasExtendedInfo: Bool?
    let hasSSLError: Bool?
    let lastCheckOKAt: String?
    let geoLatitude: Double?
    let geoLongitude: Double?
}

private struct AppDataResponsePayload: Decodable {
    let data: AppDataEnvelopePayload
    let updatedAt: String
}

private struct AppDataEnvelopePayload: Codable {
    let appId: String
    let resource: String
    let deviceId: String
    let sentAt: String
    let entries: [AVRadioLibrarySnapshot]
}

@MainActor
final class AVRadioAppDataService {
    private let apiClient: AVAppsAPIClient
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(apiClient: AVAppsAPIClient) {
        self.apiClient = apiClient
    }

    func isConfigured() -> Bool {
        apiClient.isConfigured()
    }

    func pullLibrary() async throws -> AVRadioLibraryDocument {
        let payload: AppDataResponsePayload = try await apiClient.request(
            path: "/v1/apps/\(AVRadioAppDataConstants.appId)/data/\(AVRadioAppDataConstants.resource)"
        )

        return AVRadioLibraryDocument(
            snapshot: payload.data.entries.first,
            updatedAt: Self.date(from: payload.updatedAt)
        )
    }

    func pushLibrary(_ snapshot: AVRadioLibrarySnapshot) async throws {
        let envelope = AppDataEnvelopePayload(
            appId: AVRadioAppDataConstants.appId,
            resource: AVRadioAppDataConstants.resource,
            deviceId: AVRadioAppDataConstants.deviceId,
            sentAt: Self.isoString(from: .now),
            entries: [snapshot]
        )

        let _: AppDataResponsePayload = try await apiClient.request(
            path: "/v1/apps/\(AVRadioAppDataConstants.appId)/data/\(AVRadioAppDataConstants.resource)",
            method: "PUT",
            body: try encoder.encode(envelope)
        )
    }

    private static func date(from value: String) -> Date {
        iso8601Formatter().date(from: value) ?? .distantPast
    }

    static func isoString(from date: Date) -> String {
        iso8601Formatter().string(from: date)
    }

    private static func iso8601Formatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }
}
