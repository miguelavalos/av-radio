import Foundation

private enum AVRadioAppDataConstants {
    static let appId = "avradio"
    static let legacyLibraryResource = "library"
    static let deviceId = "avradio-ios"
}

private enum AVRadioAppDataResource: String, CaseIterable {
    case favorites
    case recents
    case discoveries
    case settings
    case legacyLibrary = "library"

    static let syncResources: [AVRadioAppDataResource] = [
        .favorites,
        .recents,
        .discoveries,
        .settings
    ]
}

struct AVRadioLibraryDocument {
    let snapshot: AVRadioLibrarySnapshot?
    let updatedAt: Date
    let revision: Int
    let etag: String?
}

enum AVRadioLibrarySyncDecision: Equatable {
    case pullRemote(AVRadioLibrarySnapshot)
    case pushLocal
    case noContent
    case alreadyCurrent
}

enum AVRadioLibrarySyncPlanner {
    static func decision(
        localSnapshot: AVRadioLibrarySnapshot,
        localUpdatedAt: Date,
        remoteDocument: AVRadioLibraryDocument
    ) -> AVRadioLibrarySyncDecision {
        let localHasContent = localSnapshot.hasMeaningfulContent

        guard let remoteSnapshot = remoteDocument.snapshot else {
            return localHasContent ? .pushLocal : .noContent
        }

        let remoteHasContent = remoteSnapshot.hasMeaningfulContent
        if !remoteHasContent {
            return localHasContent ? .pushLocal : .noContent
        }

        if !localHasContent || remoteDocument.updatedAt > localUpdatedAt {
            return .pullRemote(remoteSnapshot)
        }

        if localUpdatedAt > remoteDocument.updatedAt {
            return .pushLocal
        }

        return .alreadyCurrent
    }
}

enum AVRadioAppDataError: Error {
    case conflict
}

struct AVRadioLibrarySnapshot: Codable, Equatable {
    let favorites: [FavoriteStationRecord]
    let recents: [RecentStationRecord]
    let discoveries: [DiscoveredTrackRecord]
    let settings: AppSettingsRecord

    var hasMeaningfulContent: Bool {
        !favorites.isEmpty || !recents.isEmpty || !discoveries.isEmpty || settings.hasMeaningfulContent
    }

    init(
        favorites: [FavoriteStationRecord],
        recents: [RecentStationRecord],
        discoveries: [DiscoveredTrackRecord] = [],
        settings: AppSettingsRecord
    ) {
        self.favorites = favorites
        self.recents = recents
        self.discoveries = discoveries
        self.settings = settings
    }

    private enum CodingKeys: String, CodingKey {
        case favorites
        case recents
        case discoveries
        case settings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        favorites = try container.decode([FavoriteStationRecord].self, forKey: .favorites)
        recents = try container.decode([RecentStationRecord].self, forKey: .recents)
        discoveries = try container.decodeIfPresent([DiscoveredTrackRecord].self, forKey: .discoveries) ?? []
        settings = try container.decode(AppSettingsRecord.self, forKey: .settings)
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

struct DiscoveredTrackRecord: Codable, Equatable {
    let discoveryID: String
    let title: String
    let artist: String?
    let stationID: String
    let stationName: String
    let artworkURL: String?
    let stationArtworkURL: String?
    let playedAt: String
    let markedInterestedAt: String?
    let hiddenAt: String?
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

    static var empty: AppSettingsRecord {
        AppSettingsRecord(
            preferredCountry: "",
            preferredLanguage: "",
            preferredTag: "",
            lastPlayedStationID: nil,
            sleepTimerMinutes: nil,
            updatedAt: "1970-01-01T00:00:00.000Z"
        )
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

        if [favorites.revision, recents.revision, discoveries.revision, settings.revision].allSatisfy({ $0 == 0 }) {
            return try await pullLegacyLibrary()
        }

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

    private func pullLegacyLibrary() async throws -> AVRadioLibraryDocument {
        let payload: AppDataResponsePayload<AVRadioLibrarySnapshot> = try await apiClient.request(
            path: dataPath(for: .legacyLibrary)
        )
        rememberSyncVersion(
            for: .legacyLibrary,
            revision: payload.revision,
            etag: payload.etag
        )

        return AVRadioLibraryDocument(
            snapshot: payload.data.entries.first,
            updatedAt: Self.date(from: payload.updatedAt),
            revision: payload.revision ?? 0,
            etag: payload.etag
        )
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
