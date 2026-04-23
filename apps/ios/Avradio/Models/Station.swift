import Foundation
import SwiftData

struct Station: Identifiable, Hashable {
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

    init(
        id: String,
        name: String,
        country: String,
        countryCode: String? = nil,
        state: String? = nil,
        language: String,
        languageCodes: String? = nil,
        tags: String,
        streamURL: String,
        faviconURL: String? = nil,
        bitrate: Int? = nil,
        codec: String? = nil,
        homepageURL: String? = nil,
        votes: Int? = nil,
        clickCount: Int? = nil,
        clickTrend: Int? = nil,
        isHLS: Bool? = nil,
        hasExtendedInfo: Bool? = nil,
        hasSSLError: Bool? = nil,
        lastCheckOKAt: String? = nil,
        geoLatitude: Double? = nil,
        geoLongitude: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.country = country
        self.countryCode = countryCode
        self.state = state
        self.language = language
        self.languageCodes = languageCodes
        self.tags = tags
        self.streamURL = streamURL
        self.faviconURL = faviconURL
        self.bitrate = bitrate
        self.codec = codec
        self.homepageURL = homepageURL
        self.votes = votes
        self.clickCount = clickCount
        self.clickTrend = clickTrend
        self.isHLS = isHLS
        self.hasExtendedInfo = hasExtendedInfo
        self.hasSSLError = hasSSLError
        self.lastCheckOKAt = lastCheckOKAt
        self.geoLatitude = geoLatitude
        self.geoLongitude = geoLongitude
    }
}

extension Station {
    init(favorite: FavoriteStation) {
        self.init(
            id: favorite.stationID,
            name: favorite.name,
            country: favorite.country,
            countryCode: favorite.countryCode,
            state: favorite.state,
            language: favorite.language,
            languageCodes: favorite.languageCodes,
            tags: favorite.tags,
            streamURL: favorite.streamURL,
            faviconURL: favorite.faviconURL,
            bitrate: favorite.bitrate,
            codec: favorite.codec,
            homepageURL: favorite.homepageURL,
            votes: favorite.votes,
            clickCount: favorite.clickCount,
            clickTrend: favorite.clickTrend,
            isHLS: favorite.isHLS,
            hasExtendedInfo: favorite.hasExtendedInfo,
            hasSSLError: favorite.hasSSLError,
            lastCheckOKAt: favorite.lastCheckOKAt,
            geoLatitude: favorite.geoLatitude,
            geoLongitude: favorite.geoLongitude
        )
    }

    init(recent: RecentStation) {
        self.init(
            id: recent.stationID,
            name: recent.name,
            country: recent.country,
            countryCode: recent.countryCode,
            state: recent.state,
            language: recent.language,
            languageCodes: recent.languageCodes,
            tags: recent.tags,
            streamURL: recent.streamURL,
            faviconURL: recent.faviconURL,
            bitrate: recent.bitrate,
            codec: recent.codec,
            homepageURL: recent.homepageURL,
            votes: recent.votes,
            clickCount: recent.clickCount,
            clickTrend: recent.clickTrend,
            isHLS: recent.isHLS,
            hasExtendedInfo: recent.hasExtendedInfo,
            hasSSLError: recent.hasSSLError,
            lastCheckOKAt: recent.lastCheckOKAt,
            geoLatitude: recent.geoLatitude,
            geoLongitude: recent.geoLongitude
        )
    }
}

extension Station {
    static let samples: [Station] = [
        Station(
            id: "groove-salad",
            name: "SomaFM Groove Salad",
            country: "United States",
            language: "English",
            tags: "ambient,chillout,electronic",
            streamURL: "https://ice1.somafm.com/groovesalad-128-mp3",
            faviconURL: nil,
            bitrate: 128,
            codec: "MP3",
            homepageURL: "https://somafm.com/groovesalad/"
        ),
        Station(
            id: "bbc-radio-1",
            name: "BBC Radio 1",
            country: "United Kingdom",
            language: "English",
            tags: "pop,charts,live",
            streamURL: "https://stream.live.vc.bbcmedia.co.uk/bbc_radio_one",
            faviconURL: nil,
            bitrate: 128,
            codec: "AAC",
            homepageURL: "https://www.bbc.co.uk/sounds/play/live:bbc_radio_one"
        ),
        Station(
            id: "los-40",
            name: "Los 40",
            country: "Spain",
            language: "Spanish",
            tags: "pop,latin,hits",
            streamURL: "https://25653.live.streamtheworld.com/LOS40.mp3",
            faviconURL: nil,
            bitrate: 128,
            codec: "MP3",
            homepageURL: "https://los40.com/"
        )
    ]

    var shortMeta: String {
        [country, language]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    var flagEmoji: String? {
        guard let countryCode, countryCode.count == 2 else { return nil }
        let base: UInt32 = 127397
        let scalars = countryCode.uppercased().unicodeScalars.compactMap { UnicodeScalar(base + $0.value) }
        guard scalars.count == 2 else { return nil }
        return String(String.UnicodeScalarView(scalars))
    }

    func cardDetailText(preferCountryName: Bool) -> String? {
        let normalizedLanguage = normalizedCardValue(language)
        let normalizedCountry = normalizedCardValue(country)

        if let normalizedLanguage, !normalizedLanguage.isEmpty {
            return normalizedLanguage
        }

        if preferCountryName, let normalizedCountry, !normalizedCountry.isEmpty {
            return normalizedCountry
        }

        if let normalizedCountry, !normalizedCountry.isEmpty {
            return normalizedCountry
        }

        return nil
    }

    var primaryDetailLine: String {
        [state, country, language]
            .compactMap { value in
                guard let value else { return nil }
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
            .joined(separator: " · ")
    }

    var normalizedTags: [String] {
        tags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var technicalBadges: [String] {
        var badges: [String] = []
        if let codec, !codec.isEmpty { badges.append(codec) }
        if let bitrate, bitrate > 0 { badges.append("\(bitrate) kbps") }
        if isHLS == true { badges.append("HLS") }
        if hasExtendedInfo == true { badges.append("Extended info") }
        return badges
    }

    var popularityBadges: [String] {
        var badges: [String] = []
        if let votes, votes > 0 { badges.append("\(votes) votes") }
        if let clickCount, clickCount > 0 { badges.append("\(clickCount) clicks") }
        if let clickTrend, clickTrend > 0 { badges.append("+\(clickTrend) trend") }
        return badges
    }

    var statusBadges: [String] {
        var badges: [String] = []
        if hasSSLError == true { badges.append("SSL issue") }
        if let lastCheckOKAt, !lastCheckOKAt.isEmpty { badges.append("Checked") }
        return badges
    }

    var initials: String {
        let parts = name
            .split(separator: " ")
            .prefix(2)
            .map { String($0.prefix(1)).uppercased() }
            .joined()

        return parts.isEmpty ? "AV" : parts
    }

    private func normalizedCardValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let localizedUnknowns = [
            L10n.string("stationService.fallback.unknownCountry"),
            L10n.string("stationService.fallback.unknownLanguage"),
            "Unknown country",
            "Unknown language",
            "País desconocido",
            "Idioma desconocido",
            "País desconegut",
            "Idioma desconegut",
            "Pays inconnu",
            "Langue inconnue",
            "Unbekanntes Land",
            "Unbekannte Sprache"
        ]
        .map {
            $0
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: L10n.locale)
                .lowercased()
        }

        let normalizedTrimmed = trimmed
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: L10n.locale)
            .lowercased()

        return localizedUnknowns.contains(normalizedTrimmed) ? nil : trimmed
    }

    var displayArtworkURL: URL? {
        if let faviconURL, !faviconURL.isEmpty, let url = URL(string: faviconURL) {
            return url
        }

        guard let homepageURL,
              !homepageURL.isEmpty,
              let url = URL(string: homepageURL) else {
            return nil
        }

        var components = URLComponents(string: "https://www.google.com/s2/favicons")
        components?.queryItems = [
            URLQueryItem(name: "sz", value: "256"),
            URLQueryItem(name: "domain_url", value: url.absoluteString)
        ]
        return components?.url
    }
}

@Model
final class FavoriteStation {
    @Attribute(.unique) var stationID: String
    var name: String
    var country: String
    var countryCode: String?
    var state: String?
    var language: String
    var languageCodes: String?
    var tags: String
    var streamURL: String
    var faviconURL: String?
    var bitrate: Int?
    var codec: String?
    var homepageURL: String?
    var votes: Int?
    var clickCount: Int?
    var clickTrend: Int?
    var isHLS: Bool?
    var hasExtendedInfo: Bool?
    var hasSSLError: Bool?
    var lastCheckOKAt: String?
    var geoLatitude: Double?
    var geoLongitude: Double?
    var createdAt: Date

    init(station: Station, createdAt: Date = .now) {
        self.stationID = station.id
        self.name = station.name
        self.country = station.country
        self.countryCode = station.countryCode
        self.state = station.state
        self.language = station.language
        self.languageCodes = station.languageCodes
        self.tags = station.tags
        self.streamURL = station.streamURL
        self.faviconURL = station.faviconURL
        self.bitrate = station.bitrate
        self.codec = station.codec
        self.homepageURL = station.homepageURL
        self.votes = station.votes
        self.clickCount = station.clickCount
        self.clickTrend = station.clickTrend
        self.isHLS = station.isHLS
        self.hasExtendedInfo = station.hasExtendedInfo
        self.hasSSLError = station.hasSSLError
        self.lastCheckOKAt = station.lastCheckOKAt
        self.geoLatitude = station.geoLatitude
        self.geoLongitude = station.geoLongitude
        self.createdAt = createdAt
    }
}

@Model
final class RecentStation {
    @Attribute(.unique) var stationID: String
    var name: String
    var country: String
    var countryCode: String?
    var state: String?
    var language: String
    var languageCodes: String?
    var tags: String
    var streamURL: String
    var faviconURL: String?
    var bitrate: Int?
    var codec: String?
    var homepageURL: String?
    var votes: Int?
    var clickCount: Int?
    var clickTrend: Int?
    var isHLS: Bool?
    var hasExtendedInfo: Bool?
    var hasSSLError: Bool?
    var lastCheckOKAt: String?
    var geoLatitude: Double?
    var geoLongitude: Double?
    var lastPlayedAt: Date

    init(station: Station, lastPlayedAt: Date = .now) {
        self.stationID = station.id
        self.name = station.name
        self.country = station.country
        self.countryCode = station.countryCode
        self.state = station.state
        self.language = station.language
        self.languageCodes = station.languageCodes
        self.tags = station.tags
        self.streamURL = station.streamURL
        self.faviconURL = station.faviconURL
        self.bitrate = station.bitrate
        self.codec = station.codec
        self.homepageURL = station.homepageURL
        self.votes = station.votes
        self.clickCount = station.clickCount
        self.clickTrend = station.clickTrend
        self.isHLS = station.isHLS
        self.hasExtendedInfo = station.hasExtendedInfo
        self.hasSSLError = station.hasSSLError
        self.lastCheckOKAt = station.lastCheckOKAt
        self.geoLatitude = station.geoLatitude
        self.geoLongitude = station.geoLongitude
        self.lastPlayedAt = lastPlayedAt
    }
}

@Model
final class AppSettings {
    var preferredCountry: String
    var preferredLanguage: String
    var preferredTag: String
    var lastPlayedStationID: String?
    var sleepTimerMinutes: Int?
    var updatedAt: Date

    init(
        preferredCountry: String = "",
        preferredLanguage: String = "",
        preferredTag: String = "",
        lastPlayedStationID: String? = nil,
        sleepTimerMinutes: Int? = nil,
        updatedAt: Date = .now
    ) {
        self.preferredCountry = preferredCountry
        self.preferredLanguage = preferredLanguage
        self.preferredTag = preferredTag
        self.lastPlayedStationID = lastPlayedStationID
        self.sleepTimerMinutes = sleepTimerMinutes
        self.updatedAt = updatedAt
    }
}
