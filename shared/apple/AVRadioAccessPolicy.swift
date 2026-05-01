import Foundation

enum AccessMode: String, CaseIterable, Codable, Identifiable {
    case guest
    case signedInFree
    case signedInPro

    var id: String { rawValue }
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

struct AVRadioAccessLimitValues: Equatable {
    let favoriteStations: Int?
    let recentStations: Int?
    let discoveredTracks: Int?
    let savedTracks: Int?
    let lyricsSearchesPerDay: Int?
    let youtubeSearchesPerDay: Int?
    let appleMusicSearchesPerDay: Int?
    let spotifySearchesPerDay: Int?
    let discoverySharesPerDay: Int?
}

struct AVRadioAccessCapabilityValues: Equatable {
    let isSignedIn: Bool
    let canUseBackend: Bool
    let canAccessPremiumFeatures: Bool
    let canUseCloudSync: Bool
    let canManagePlan: Bool
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

enum AVRadioAccessPolicy {
    static func limits(for accessMode: String) -> AVRadioAccessLimitValues {
        switch accessMode {
        case "guest":
            AVRadioAccessLimitValues(
                favoriteStations: 10,
                recentStations: 12,
                discoveredTracks: 25,
                savedTracks: 10,
                lyricsSearchesPerDay: 5,
                youtubeSearchesPerDay: 5,
                appleMusicSearchesPerDay: 5,
                spotifySearchesPerDay: 5,
                discoverySharesPerDay: 2
            )
        case "signedInFree":
            AVRadioAccessLimitValues(
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
        case "signedInPro":
            AVRadioAccessLimitValues(
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
        default:
            limits(for: "guest")
        }
    }

    static func capabilities(for accessMode: String) -> AVRadioAccessCapabilityValues {
        switch accessMode {
        case "guest":
            AVRadioAccessCapabilityValues(
                isSignedIn: false,
                canUseBackend: false,
                canAccessPremiumFeatures: false,
                canUseCloudSync: false,
                canManagePlan: false
            )
        case "signedInFree":
            AVRadioAccessCapabilityValues(
                isSignedIn: true,
                canUseBackend: false,
                canAccessPremiumFeatures: false,
                canUseCloudSync: false,
                canManagePlan: true
            )
        case "signedInPro":
            AVRadioAccessCapabilityValues(
                isSignedIn: true,
                canUseBackend: true,
                canAccessPremiumFeatures: true,
                canUseCloudSync: true,
                canManagePlan: true
            )
        default:
            capabilities(for: "guest")
        }
    }
}
