import Foundation

private enum AVRadioAppDataConstants {
    static let appId = "avradio"
    static let deviceId = "avradio-ios"
}

private enum AVRadioAppDataResource: String, CaseIterable {
    case favorites
    case recents
    case discoveries
    case settings

    static let syncResources: [AVRadioAppDataResource] = [
        .favorites,
        .recents,
        .discoveries,
        .settings
    ]
}

private struct AppDataResponsePayload<Entry: Codable>: Decodable {
    let data: AppDataEnvelopePayload<Entry>
    let updatedAt: String
    let revision: Int?
    let etag: String?
}

private struct AppDataEnvelopePayload<Entry: Codable>: Codable {
    let appId: String
    let resource: String
    let deviceId: String
    let sentAt: String
    let entries: [Entry]
}

private struct AppDataResourceDocument<Entry: Codable> {
    let entries: [Entry]
    let updatedAt: Date
    let revision: Int
    let etag: String?
}

@MainActor
final class AVRadioAppDataService {
    private let apiClient: AVAppsAPIClient
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private var lastKnownRevisions: [String: Int] = [:]
    private var lastKnownEtags: [String: String] = [:]

    init(apiClient: AVAppsAPIClient) {
        self.apiClient = apiClient
    }

    func isConfigured() -> Bool {
        apiClient.isConfigured()
    }

    func pullLibrary() async throws -> AVRadioLibraryDocument {
        let favorites = try await pullResource(
            .favorites,
            entryType: FavoriteStationRecord.self
        )
        let recents = try await pullResource(
            .recents,
            entryType: RecentStationRecord.self
        )
        let discoveries = try await pullResource(
            .discoveries,
            entryType: DiscoveredTrackRecord.self
        )
        let settings = try await pullResource(
            .settings,
            entryType: AppSettingsRecord.self
        )

        let snapshot = AVRadioLibrarySnapshot(
            favorites: favorites.entries,
            recents: recents.entries,
            discoveries: discoveries.entries,
            settings: settings.entries.first ?? .empty
        )
        let updatedAt = [
            favorites.updatedAt,
            recents.updatedAt,
            discoveries.updatedAt,
            settings.updatedAt
        ].max() ?? .distantPast

        return AVRadioLibraryDocument(
            snapshot: snapshot.hasMeaningfulContent ? snapshot : nil,
            updatedAt: updatedAt,
            revision: [
                favorites.revision,
                recents.revision,
                discoveries.revision,
                settings.revision
            ].max() ?? 0,
            etag: nil
        )
    }

    func pushLibrary(_ snapshot: AVRadioLibrarySnapshot) async throws {
        try await pushResource(.favorites, entries: snapshot.favorites)
        try await pushResource(.recents, entries: snapshot.recents)
        try await pushResource(.discoveries, entries: snapshot.discoveries)
        try await pushResource(.settings, entries: [snapshot.settings])
    }

    func overwriteLibrary(_ snapshot: AVRadioLibrarySnapshot) async throws {
        for resource in AVRadioAppDataResource.syncResources {
            forgetSyncVersion(for: resource)
        }

        try await pushLibrary(snapshot)
    }

    private func pullResource<Entry: Codable>(
        _ resource: AVRadioAppDataResource,
        entryType: Entry.Type
    ) async throws -> AppDataResourceDocument<Entry> {
        let payload: AppDataResponsePayload<Entry> = try await apiClient.request(
            path: dataPath(for: resource)
        )
        rememberSyncVersion(
            for: resource,
            revision: payload.revision,
            etag: payload.etag
        )

        return AppDataResourceDocument(
            entries: payload.data.entries,
            updatedAt: Self.date(from: payload.updatedAt),
            revision: payload.revision ?? 0,
            etag: payload.etag
        )
    }

    private func pushResource<Entry: Codable>(
        _ resource: AVRadioAppDataResource,
        entries: [Entry]
    ) async throws {
        let envelope = AppDataEnvelopePayload(
            appId: AVRadioAppDataConstants.appId,
            resource: resource.rawValue,
            deviceId: AVRadioAppDataConstants.deviceId,
            sentAt: Self.isoString(from: .now),
            entries: entries
        )

        var headers: [String: String] = [:]
        if let lastKnownEtag = lastKnownEtags[resource.rawValue] {
            headers["If-Match"] = lastKnownEtag
        } else if let lastKnownRevision = lastKnownRevisions[resource.rawValue] {
            headers["If-Match"] = "\"revision-\(lastKnownRevision)\""
        }

        let response: AppDataResponsePayload<Entry>
        do {
            response = try await apiClient.request(
                path: dataPath(for: resource),
                method: "PUT",
                body: try encoder.encode(envelope),
                headers: headers
            )
        } catch AVAppsAPIClientError.requestFailed(let statusCode) where statusCode == 409 {
            throw AVRadioAppDataError.conflict
        }
        rememberSyncVersion(for: resource, revision: response.revision, etag: response.etag)
    }

    private func rememberSyncVersion(
        for resource: AVRadioAppDataResource,
        revision: Int?,
        etag: String?
    ) {
        lastKnownRevisions[resource.rawValue] = revision
        lastKnownEtags[resource.rawValue] = etag
    }

    private func forgetSyncVersion(for resource: AVRadioAppDataResource) {
        lastKnownRevisions[resource.rawValue] = nil
        lastKnownEtags[resource.rawValue] = nil
    }

    private func dataPath(for resource: AVRadioAppDataResource) -> String {
        "/v1/apps/\(AVRadioAppDataConstants.appId)/data/\(resource.rawValue)"
    }

    private static func date(from value: String) -> Date {
        AVRadioDateCoding.date(from: value)
    }

    static func isoString(from date: Date) -> String {
        AVRadioDateCoding.string(from: date)
    }
}
