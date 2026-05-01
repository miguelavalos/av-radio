import Foundation

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

enum AVRadioAccessPolicy {
    static func limits(for accessMode: String) -> AVRadioAccessLimitValues {
        switch accessMode {
        case "guest":
            AVRadioAccessLimitValues(
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
