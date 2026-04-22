import Foundation
import SwiftData

struct Station: Identifiable, Hashable {
    let id: String
    let name: String
    let country: String
    let language: String
    let tags: String
    let streamURL: String
    let faviconURL: String?
    let bitrate: Int?
    let codec: String?
    let homepageURL: String?
}

extension Station {
    init(favorite: FavoriteStation) {
        self.init(
            id: favorite.stationID,
            name: favorite.name,
            country: favorite.country,
            language: favorite.language,
            tags: favorite.tags,
            streamURL: favorite.streamURL,
            faviconURL: favorite.faviconURL,
            bitrate: favorite.bitrate,
            codec: favorite.codec,
            homepageURL: favorite.homepageURL
        )
    }

    init(recent: RecentStation) {
        self.init(
            id: recent.stationID,
            name: recent.name,
            country: recent.country,
            language: recent.language,
            tags: recent.tags,
            streamURL: recent.streamURL,
            faviconURL: recent.faviconURL,
            bitrate: recent.bitrate,
            codec: recent.codec,
            homepageURL: recent.homepageURL
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

    var initials: String {
        let parts = name
            .split(separator: " ")
            .prefix(2)
            .map { String($0.prefix(1)).uppercased() }
            .joined()

        return parts.isEmpty ? "AV" : parts
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
    var language: String
    var tags: String
    var streamURL: String
    var faviconURL: String?
    var bitrate: Int?
    var codec: String?
    var homepageURL: String?
    var createdAt: Date

    init(station: Station, createdAt: Date = .now) {
        self.stationID = station.id
        self.name = station.name
        self.country = station.country
        self.language = station.language
        self.tags = station.tags
        self.streamURL = station.streamURL
        self.faviconURL = station.faviconURL
        self.bitrate = station.bitrate
        self.codec = station.codec
        self.homepageURL = station.homepageURL
        self.createdAt = createdAt
    }
}

@Model
final class RecentStation {
    @Attribute(.unique) var stationID: String
    var name: String
    var country: String
    var language: String
    var tags: String
    var streamURL: String
    var faviconURL: String?
    var bitrate: Int?
    var codec: String?
    var homepageURL: String?
    var lastPlayedAt: Date

    init(station: Station, lastPlayedAt: Date = .now) {
        self.stationID = station.id
        self.name = station.name
        self.country = station.country
        self.language = station.language
        self.tags = station.tags
        self.streamURL = station.streamURL
        self.faviconURL = station.faviconURL
        self.bitrate = station.bitrate
        self.codec = station.codec
        self.homepageURL = station.homepageURL
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
