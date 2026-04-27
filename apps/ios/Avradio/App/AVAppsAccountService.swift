import ClerkKit
import Foundation

@MainActor
protocol AVAppsAccountService {
    var isAvailable: Bool { get }
    var currentUser: AccountUser? { get }

    func getToken() async throws -> String?
    func signInWithApple() async throws
    func signInWithGoogle() async throws
    func signOut() async throws
}

enum AVAppsAccountServiceError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unavailable:
            L10n.string("account.error.unavailable")
        }
    }
}

struct DefaultAVAppsAccountService: AVAppsAccountService {
    var isAvailable: Bool {
        AppConfig.isAVAppsAccountAvailable
    }

    var currentUser: AccountUser? {
        guard isAvailable, let user = Clerk.shared.user else {
            return nil
        }

        let displayName =
            [user.firstName, user.lastName]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: " ")

        return AccountUser(
            id: user.id,
            displayName: displayName.isEmpty ? L10n.string("account.displayName.listener") : displayName,
            emailAddress: user.primaryEmailAddress?.emailAddress
        )
    }

    func getToken() async throws -> String? {
        guard isAvailable, let session = Clerk.shared.session else {
            return nil
        }

        return try await session.getToken()
    }

    func signInWithApple() async throws {
        guard isAvailable else {
            throw AVAppsAccountServiceError.unavailable
        }

        _ = try await Clerk.shared.auth.signInWithApple()
    }

    func signInWithGoogle() async throws {
        guard isAvailable else {
            throw AVAppsAccountServiceError.unavailable
        }

        _ = try await Clerk.shared.auth.signInWithOAuth(provider: .google)
    }

    func signOut() async throws {
        guard isAvailable else { return }
        try await Clerk.shared.auth.signOut()
    }
}
