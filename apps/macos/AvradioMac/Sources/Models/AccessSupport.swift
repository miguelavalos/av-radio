import Foundation

enum AccessMode: String, CaseIterable, Codable, Identifiable {
    case guest
    case signedInFree
    case signedInPro

    var id: String { rawValue }

    var title: String {
        switch self {
        case .guest:
            return "Guest"
        case .signedInFree:
            return "Signed-in Free"
        case .signedInPro:
            return "Pro"
        }
    }
}

enum LimitedFeature: String, Codable {
    case savedTracks
    case lyricsSearch
    case youtubeSearch
    case appleMusicSearch
    case spotifySearch
    case discoveryShare
}

struct AccessCapabilities: Codable, Equatable {
    let isSignedIn: Bool
    let canUseBackend: Bool
    let canAccessPremiumFeatures: Bool
    let canUseCloudSync: Bool
    let canManagePlan: Bool

    var isLocalOnly: Bool {
        !canUseBackend && !canUseCloudSync
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

struct AccessLimits: Equatable {
    let favoriteStations: Int?
    let recentStations: Int?
    let discoveredTracks: Int?
    let savedTracks: Int?
    let lyricsPerDay: Int?
    let youtubePerDay: Int?
    let appleMusicPerDay: Int?
    let spotifyPerDay: Int?
    let discoverySharesPerDay: Int?

    func limit(for feature: LimitedFeature) -> Int? {
        switch feature {
        case .savedTracks:
            return savedTracks
        case .lyricsSearch:
            return lyricsPerDay
        case .youtubeSearch:
            return youtubePerDay
        case .appleMusicSearch:
            return appleMusicPerDay
        case .spotifySearch:
            return spotifyPerDay
        case .discoveryShare:
            return discoverySharesPerDay
        }
    }

    static func forMode(_ accessMode: AccessMode) -> AccessLimits {
        let values = AVRadioAccessPolicy.limits(for: accessMode.rawValue)
        return AccessLimits(
            favoriteStations: values.favoriteStations,
            recentStations: values.recentStations,
            discoveredTracks: values.discoveredTracks,
            savedTracks: values.savedTracks,
            lyricsPerDay: values.lyricsSearchesPerDay,
            youtubePerDay: values.youtubeSearchesPerDay,
            appleMusicPerDay: values.appleMusicSearchesPerDay,
            spotifyPerDay: values.spotifySearchesPerDay,
            discoverySharesPerDay: values.discoverySharesPerDay
        )
    }
}

struct UpgradePromptContext: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let benefit: String
    let progressText: String?

    static func favorites(current: Int, limit: Int) -> UpgradePromptContext {
        UpgradePromptContext(
            title: "Favorite station limit reached",
            message: "You have saved \(current) of \(limit) favorite stations.",
            benefit: "Pro unlocks a larger radio library, cloud sync, and richer discovery history.",
            progressText: "\(current) of \(limit) favorites used"
        )
    }

    static func dailyFeature(_ feature: LimitedFeature, current: Int, limit: Int) -> UpgradePromptContext {
        let featureName: String
        switch feature {
        case .savedTracks:
            featureName = "saved tracks"
        case .lyricsSearch:
            featureName = "lyrics searches"
        case .youtubeSearch:
            featureName = "YouTube opens"
        case .appleMusicSearch:
            featureName = "Apple Music opens"
        case .spotifySearch:
            featureName = "Spotify opens"
        case .discoveryShare:
            featureName = "discovery shares"
        }

        return UpgradePromptContext(
            title: "Daily \(featureName) limit reached",
            message: "You have used \(current) of today's \(limit) \(featureName).",
            benefit: "Pro unlocks practical unlimited music lookups and cloud-backed discovery history.",
            progressText: "\(current) of \(limit) used today"
        )
    }
}
