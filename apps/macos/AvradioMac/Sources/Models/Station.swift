import Foundation

struct Station: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let country: String
    let countryCode: String?
    let state: String?
    let language: String
    let tags: String
    let streamURL: String
    let faviconURL: String?
    let bitrate: Int?
    let codec: String?
    let homepageURL: String?

    init(
        id: String,
        name: String,
        country: String,
        countryCode: String? = nil,
        state: String? = nil,
        language: String,
        tags: String,
        streamURL: String,
        faviconURL: String? = nil,
        bitrate: Int? = nil,
        codec: String? = nil,
        homepageURL: String? = nil
    ) {
        self.id = id
        self.name = name
        self.country = country
        self.countryCode = countryCode
        self.state = state
        self.language = language
        self.tags = tags
        self.streamURL = streamURL
        self.faviconURL = faviconURL
        self.bitrate = bitrate
        self.codec = codec
        self.homepageURL = homepageURL
    }
}

extension Station {
    static let samples: [Station] = [
        Station(
            id: "groove-salad",
            name: "SomaFM Groove Salad",
            country: "United States",
            countryCode: "US",
            language: "English",
            tags: "ambient,chillout,electronic",
            streamURL: "https://ice1.somafm.com/groovesalad-128-mp3",
            bitrate: 128,
            codec: "MP3",
            homepageURL: "https://somafm.com/groovesalad/"
        ),
        Station(
            id: "bbc-radio-1",
            name: "BBC Radio 1",
            country: "United Kingdom",
            countryCode: "GB",
            language: "English",
            tags: "pop,charts,live",
            streamURL: "https://stream.live.vc.bbcmedia.co.uk/bbc_radio_one",
            bitrate: 128,
            codec: "AAC",
            homepageURL: "https://www.bbc.co.uk/sounds/play/live:bbc_radio_one"
        ),
        Station(
            id: "los-40",
            name: "Los 40",
            country: "Spain",
            countryCode: "ES",
            language: "Spanish",
            tags: "pop,latin,hits",
            streamURL: "https://25653.live.streamtheworld.com/LOS40.mp3",
            bitrate: 128,
            codec: "MP3",
            homepageURL: "https://los40.com/"
        ),
        Station(
            id: "fip",
            name: "FIP",
            country: "France",
            countryCode: "FR",
            language: "French",
            tags: "eclectic,chill,jazz",
            streamURL: "https://icecast.radiofrance.fr/fip-hifi.aac",
            bitrate: 320,
            codec: "AAC",
            homepageURL: "https://www.radiofrance.fr/fip"
        )
    ]

    var shortMeta: String {
        [country, language].joined(separator: " · ")
    }

    var detailLine: String {
        [state, country, language]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: " · ")
    }

    var flagEmoji: String? {
        guard let countryCode, countryCode.count == 2 else { return nil }
        let base: UInt32 = 127397
        let scalars = countryCode.uppercased().unicodeScalars.compactMap { UnicodeScalar(base + $0.value) }
        guard scalars.count == 2 else { return nil }
        return String(String.UnicodeScalarView(scalars))
    }

    var tagsList: [String] {
        tags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
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

        guard let homepageURL, !homepageURL.isEmpty, let url = URL(string: homepageURL) else {
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
