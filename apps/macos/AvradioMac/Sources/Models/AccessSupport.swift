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
        switch accessMode {
        case .guest:
            AccessLimits(
                favoriteStations: 5,
                recentStations: 10,
                discoveredTracks: 20,
                savedTracks: 5,
                lyricsPerDay: 3,
                youtubePerDay: 3,
                appleMusicPerDay: 3,
                spotifyPerDay: 3,
                discoverySharesPerDay: 1
            )
        case .signedInFree:
            AccessLimits(
                favoriteStations: 15,
                recentStations: 25,
                discoveredTracks: 50,
                savedTracks: 20,
                lyricsPerDay: 10,
                youtubePerDay: 10,
                appleMusicPerDay: 10,
                spotifyPerDay: 10,
                discoverySharesPerDay: 3
            )
        case .signedInPro:
            AccessLimits(
                favoriteStations: nil,
                recentStations: 200,
                discoveredTracks: 1000,
                savedTracks: nil,
                lyricsPerDay: nil,
                youtubePerDay: nil,
                appleMusicPerDay: nil,
                spotifyPerDay: nil,
                discoverySharesPerDay: nil
            )
        }
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
