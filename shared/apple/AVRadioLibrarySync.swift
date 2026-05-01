import Foundation

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

extension Station {
    init(record: StationRecord) {
        self.init(
            id: record.id,
            name: record.name,
            country: record.country,
            countryCode: record.countryCode,
            state: record.state,
            language: record.language,
            languageCodes: record.languageCodes,
            tags: record.tags,
            streamURL: record.streamURL,
            faviconURL: record.faviconURL,
            bitrate: record.bitrate,
            codec: record.codec,
            homepageURL: record.homepageURL,
            votes: record.votes,
            clickCount: record.clickCount,
            clickTrend: record.clickTrend,
            isHLS: record.isHLS,
            hasExtendedInfo: record.hasExtendedInfo,
            hasSSLError: record.hasSSLError,
            lastCheckOKAt: record.lastCheckOKAt,
            geoLatitude: record.geoLatitude,
            geoLongitude: record.geoLongitude
        )
    }

    var appDataRecord: StationRecord {
        StationRecord(
            id: id,
            name: name,
            country: country,
            countryCode: countryCode,
            state: state,
            language: language,
            languageCodes: languageCodes,
            tags: tags,
            streamURL: streamURL,
            faviconURL: faviconURL,
            bitrate: bitrate,
            codec: codec,
            homepageURL: homepageURL,
            votes: votes,
            clickCount: clickCount,
            clickTrend: clickTrend,
            isHLS: isHLS,
            hasExtendedInfo: hasExtendedInfo,
            hasSSLError: hasSSLError,
            lastCheckOKAt: lastCheckOKAt,
            geoLatitude: geoLatitude,
            geoLongitude: geoLongitude
        )
    }
}
