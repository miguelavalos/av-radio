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
        let values = AVRadioAccessPolicy.limits(for: accessMode.rawValue)
        return AccessLimits(
            favoriteStations: values.favoriteStations,
            recentStations: values.recentStations,
            discoveredTracks: values.discoveredTracks,
            savedTracks: values.savedTracks,
            lyricsSearchesPerDay: values.lyricsSearchesPerDay,
            youtubeSearchesPerDay: values.youtubeSearchesPerDay,
            appleMusicSearchesPerDay: values.appleMusicSearchesPerDay,
            spotifySearchesPerDay: values.spotifySearchesPerDay,
            discoverySharesPerDay: values.discoverySharesPerDay
        )
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
        let values = AVRadioAccessPolicy.capabilities(for: accessMode.rawValue)
        return AccessCapabilities(
            isSignedIn: values.isSignedIn,
            canUseBackend: values.canUseBackend,
            canAccessPremiumFeatures: values.canAccessPremiumFeatures,
            canUseCloudSync: values.canUseCloudSync,
            canManagePlan: values.canManagePlan
        )
    }
}
