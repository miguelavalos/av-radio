import Foundation

enum AccessMode: String, Codable {
    case guest
    case signedInFree
    case signedInPro
}

enum PlanTier: String, Codable {
    case free
    case pro
}

enum LimitedFeature: String, CaseIterable, Codable {
    case favoriteStations
    case savedTracks
    case discoveredTracks
    case lyricsSearch
    case youtubeSearch
    case appleMusicSearch
    case spotifySearch
    case discoveryShare
}

struct AccessLimits: Codable, Equatable {
    let favoriteStations: Int?
    let recentStations: Int?
    let discoveredTracks: Int?
    let savedTracks: Int?
    let lyricsSearchesPerDay: Int?
    let youtubeSearchesPerDay: Int?
    let appleMusicSearchesPerDay: Int?
    let spotifySearchesPerDay: Int?
    let discoverySharesPerDay: Int?

    func limit(for feature: LimitedFeature) -> Int? {
        switch feature {
        case .favoriteStations:
            favoriteStations
        case .savedTracks:
            savedTracks
        case .discoveredTracks:
            discoveredTracks
        case .lyricsSearch:
            lyricsSearchesPerDay
        case .youtubeSearch:
            youtubeSearchesPerDay
        case .appleMusicSearch:
            appleMusicSearchesPerDay
        case .spotifySearch:
            spotifySearchesPerDay
        case .discoveryShare:
            discoverySharesPerDay
        }
    }

    static func forMode(_ accessMode: AccessMode) -> AccessLimits {
        switch accessMode {
        case .guest:
            AccessLimits(
                favoriteStations: 5,
                recentStations: 10,
                discoveredTracks: 20,
                savedTracks: 5,
                lyricsSearchesPerDay: 3,
                youtubeSearchesPerDay: 3,
                appleMusicSearchesPerDay: 3,
                spotifySearchesPerDay: 3,
                discoverySharesPerDay: 1
            )
        case .signedInFree:
            AccessLimits(
                favoriteStations: 15,
                recentStations: 25,
                discoveredTracks: 50,
                savedTracks: 20,
                lyricsSearchesPerDay: 10,
                youtubeSearchesPerDay: 10,
                appleMusicSearchesPerDay: 10,
                spotifySearchesPerDay: 10,
                discoverySharesPerDay: 3
            )
        case .signedInPro:
            AccessLimits(
                favoriteStations: 500,
                recentStations: 200,
                discoveredTracks: 1_000,
                savedTracks: 1_000,
                lyricsSearchesPerDay: nil,
                youtubeSearchesPerDay: nil,
                appleMusicSearchesPerDay: nil,
                spotifySearchesPerDay: nil,
                discoverySharesPerDay: nil
            )
        }
    }
}

struct FeatureLimitState: Equatable {
    let feature: LimitedFeature
    let currentUsage: Int
    let limit: Int?

    var isLimited: Bool {
        limit != nil
    }

    var isAllowed: Bool {
        guard let limit else { return true }
        return currentUsage < limit
    }

    var remaining: Int? {
        guard let limit else { return nil }
        return max(limit - currentUsage, 0)
    }
}

struct UpgradePrompt: Identifiable, Equatable {
    let id = UUID()
    let feature: LimitedFeature
    let title: String
    let message: String
}

struct ResolvedAccess: Equatable {
    let planTier: PlanTier
    let accessMode: AccessMode
    let capabilities: AccessCapabilities
    let limits: AccessLimits

    static let guest = ResolvedAccess(
        planTier: .free,
        accessMode: .guest,
        capabilities: .forMode(.guest),
        limits: .forMode(.guest)
    )
}

struct AccountSession: Equatable {
    let user: AccountUser
    let planTier: PlanTier
    let accessMode: AccessMode
    let capabilities: AccessCapabilities
}

struct AccountUser: Equatable {
    let id: String
    let displayName: String
    let emailAddress: String?

    var initials: String {
        let words = displayName.split(separator: " ").prefix(2)
        let letters = words.map { String($0.prefix(1)).uppercased() }.joined()
        return letters.isEmpty ? "AV" : letters
    }
}

struct AccessCapabilities: Codable, Equatable {
    let isSignedIn: Bool
    let canUseBackend: Bool
    let canAccessPremiumFeatures: Bool
    let canUseCloudSync: Bool
    let canManagePlan: Bool

    enum CodingKeys: String, CodingKey {
        case isSignedIn
        case canUseBackend
        case canAccessPremiumFeatures = "canUsePremiumFeatures"
        case canUseCloudSync
        case canManagePlan
    }

    var isLocalOnly: Bool {
        !canUseBackend && !canUseCloudSync
    }

    var usesBackend: Bool {
        canUseBackend || canUseCloudSync
    }

    var canManageAVAppsAccount: Bool {
        isSignedIn
    }

    var canUpgradeToPro: Bool {
        isSignedIn && !canAccessPremiumFeatures
    }

    static func forMode(_ accessMode: AccessMode) -> AccessCapabilities {
        switch accessMode {
        case .guest:
            AccessCapabilities(
                isSignedIn: false,
                canUseBackend: false,
                canAccessPremiumFeatures: false,
                canUseCloudSync: false,
                canManagePlan: false
            )
        case .signedInFree:
            AccessCapabilities(
                isSignedIn: true,
                canUseBackend: false,
                canAccessPremiumFeatures: false,
                canUseCloudSync: false,
                canManagePlan: true
            )
        case .signedInPro:
            AccessCapabilities(
                isSignedIn: true,
                canUseBackend: true,
                canAccessPremiumFeatures: true,
                canUseCloudSync: true,
                canManagePlan: true
            )
        }
    }
}
