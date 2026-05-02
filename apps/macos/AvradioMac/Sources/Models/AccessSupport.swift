import Foundation

extension AccessMode {
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
        case .favoriteStations:
            featureName = "favorite stations"
        case .savedTracks:
            featureName = "saved tracks"
        case .discoveredTracks:
            featureName = "discovered tracks"
        case .lyricsSearch:
            featureName = "lyrics searches"
        case .webSearch:
            featureName = "web searches"
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
