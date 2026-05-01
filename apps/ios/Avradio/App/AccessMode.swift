import Foundation

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
