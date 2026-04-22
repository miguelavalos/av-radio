import Foundation

enum AccessMode: String {
    case guest
    case signedInFree
    case signedInPro
}

enum PlanTier: String {
    case free
    case pro
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

struct AccessCapabilities: Equatable {
    let isLocalOnly: Bool
    let usesBackend: Bool
    let canAccessPremiumFeatures: Bool
    let canManageAVAppsAccount: Bool
    let canUpgradeToPro: Bool

    static func forMode(_ accessMode: AccessMode) -> AccessCapabilities {
        switch accessMode {
        case .guest:
            AccessCapabilities(
                isLocalOnly: true,
                usesBackend: false,
                canAccessPremiumFeatures: false,
                canManageAVAppsAccount: false,
                canUpgradeToPro: false
            )
        case .signedInFree:
            AccessCapabilities(
                isLocalOnly: true,
                usesBackend: false,
                canAccessPremiumFeatures: false,
                canManageAVAppsAccount: true,
                canUpgradeToPro: true
            )
        case .signedInPro:
            AccessCapabilities(
                isLocalOnly: false,
                usesBackend: true,
                canAccessPremiumFeatures: true,
                canManageAVAppsAccount: true,
                canUpgradeToPro: false
            )
        }
    }
}
