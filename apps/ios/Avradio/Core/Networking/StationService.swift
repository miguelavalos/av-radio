import Foundation

struct StationService {
    struct SearchFilters {
        var query: String
        var country: String = ""
        var language: String = ""
        var tag: String = ""
        var limit: Int = 30
    }

    enum StationServiceError: LocalizedError {
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return L10n.string("stationService.error.invalidResponse")
            }
        }
    }

    private let baseURL = URL(string: "https://de1.api.radio-browser.info/json/stations/search")!
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func searchStations(filters: SearchFilters) async throws -> [Station] {
        let trimmedQuery = filters.query.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCountry = filters.country.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLanguage = filters.language.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTag = filters.tag.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedQuery.isEmpty || !trimmedCountry.isEmpty || !trimmedLanguage.isEmpty || !trimmedTag.isEmpty else {
            return []
        }

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "name", value: trimmedQuery.isEmpty ? nil : trimmedQuery),
            URLQueryItem(name: "country", value: trimmedCountry.isEmpty ? nil : trimmedCountry),
            URLQueryItem(name: "language", value: trimmedLanguage.isEmpty ? nil : trimmedLanguage),
            URLQueryItem(name: "tag", value: trimmedTag.isEmpty ? nil : trimmedTag),
            URLQueryItem(name: "hidebroken", value: "true"),
            URLQueryItem(name: "order", value: "clickcount"),
            URLQueryItem(name: "reverse", value: "true"),
            URLQueryItem(name: "limit", value: String(filters.limit))
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("AVRadio/0.1", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw StationServiceError.invalidResponse
        }

        let stations = try JSONDecoder().decode([RadioBrowserStationDTO].self, from: data)
        let resolvedStations = stations.compactMap(\.station)

        guard !trimmedTag.isEmpty else {
            return resolvedStations
        }

        let exactTagMatches = resolvedStations.filter { station in
            station.matchesTag(trimmedTag)
        }

        if !exactTagMatches.isEmpty {
            return Array(exactTagMatches.prefix(filters.limit))
        }

        return resolvedStations
    }
}

private extension Station {
    func matchesTag(_ rawTag: String) -> Bool {
        let requestedTag = normalizedTagToken(rawTag)
        guard !requestedTag.isEmpty else { return false }

        return tags
            .split(separator: ",")
            .map { normalizedTagToken(String($0)) }
            .contains(requestedTag)
    }

    func normalizedTagToken(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

private struct RadioBrowserStationDTO: Decodable {
    let stationuuid: String
    let name: String
    let country: String?
    let language: String?
    let tags: String?
    let url: String?
    let url_resolved: String?
    let favicon: String?
    let bitrate: Int?
    let codec: String?
    let homepage: String?
    let lastcheckok: Int?

    var station: Station? {
        let stream = (url_resolved?.isEmpty == false ? url_resolved : url) ?? ""
        guard !stream.isEmpty else { return nil }
        guard (lastcheckok ?? 1) == 1 else { return nil }

        return Station(
            id: stationuuid,
            name: normalized(name, fallback: L10n.string("stationService.fallback.unnamed")),
            country: normalized(country, fallback: L10n.string("stationService.fallback.unknownCountry")),
            language: normalized(language, fallback: L10n.string("stationService.fallback.unknownLanguage")),
            tags: normalized(tags, fallback: L10n.string("stationService.fallback.noTags")),
            streamURL: stream,
            faviconURL: normalizedOptionalURL(favicon),
            bitrate: bitrate,
            codec: normalizedOptional(codec),
            homepageURL: normalizedOptionalURL(homepage)
        )
    }

    private func normalized(_ value: String?, fallback: String) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func normalizedOptional(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func normalizedOptionalURL(_ value: String?) -> String? {
        guard let candidate = normalizedOptional(value), URL(string: candidate) != nil else {
            return nil
        }
        return candidate
    }
}
