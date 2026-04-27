import Foundation

struct MeAccessResponse: Decodable {
    let apps: [AppAccess]
}

struct AppAccess: Decodable {
    let appId: String
    let accessMode: AccessMode
    let planTier: PlanTier
    let capabilities: AccessCapabilities
}

enum AVAppsAPIClientError: LocalizedError {
    case missingToken
    case missingBaseURL
    case requestFailed(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .missingToken:
            "Missing AV Apps account token."
        case .missingBaseURL:
            "Missing AV Apps API base URL."
        case .requestFailed(let statusCode):
            "AV Apps API request failed with status \(statusCode)."
        }
    }
}

@MainActor
final class AVAppsAPIClient {
    private let getToken: () async throws -> String?
    private let urlSession: URLSession
    private let decoder: JSONDecoder

    init(
        getToken: @escaping () async throws -> String?,
        urlSession: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.getToken = getToken
        self.urlSession = urlSession
        self.decoder = decoder
    }

    func isConfigured() -> Bool {
        AppConfig.avAppsAPIBaseURL != nil
    }

    func fetchMeAccess() async throws -> MeAccessResponse {
        try await request(path: "/v1/me/access")
    }

    func request<T: Decodable>(
        path: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> T {
        guard let token = try await getToken(), !token.isEmpty else {
            throw AVAppsAPIClientError.missingToken
        }

        guard let baseURL = AppConfig.avAppsAPIBaseURL else {
            throw AVAppsAPIClientError.missingBaseURL
        }

        let sanitizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let url = baseURL.appending(path: sanitizedPath)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AVAppsAPIClientError.requestFailed(statusCode: httpResponse.statusCode)
        }

        return try decoder.decode(T.self, from: data)
    }
}
