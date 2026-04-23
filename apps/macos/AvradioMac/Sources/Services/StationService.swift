import Foundation

struct StationService {
    struct SearchFilters {
        var query: String
        var countryCode: String = ""
        var tag: String = ""
        var limit: Int = 30
        var allowsEmptySearch: Bool = false
    }

    enum StationServiceError: LocalizedError {
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "The station service returned an invalid response."
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
        let trimmedCountryCode = filters.countryCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTag = filters.tag.trimmingCharacters(in: .whitespacesAndNewlines)

        guard filters.allowsEmptySearch || !trimmedQuery.isEmpty || !trimmedCountryCode.isEmpty || !trimmedTag.isEmpty else {
            return []
        }

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "name", value: trimmedQuery.isEmpty ? nil : trimmedQuery),
            URLQueryItem(name: "countrycode", value: trimmedCountryCode.isEmpty ? nil : trimmedCountryCode),
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
        request.setValue("AVRadioMac/0.1", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw StationServiceError.invalidResponse
        }

        let stations = try JSONDecoder().decode([RadioBrowserStationDTO].self, from: data)
        return stations.compactMap(\.station)
    }
}

private struct RadioBrowserStationDTO: Decodable {
    let stationuuid: String
    let name: String
    let country: String?
    let countrycode: String?
    let state: String?
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
            name: normalized(name, fallback: "Unnamed station"),
            country: normalized(country, fallback: "Unknown country"),
            countryCode: normalizedOptional(countrycode),
            state: normalizedOptional(state),
            language: normalized(language, fallback: "Unknown language"),
            tags: normalized(tags, fallback: "radio"),
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
