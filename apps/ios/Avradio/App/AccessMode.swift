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

struct ResolvedAccess: Equatable {
    let planTier: PlanTier
    let accessMode: AccessMode
    let capabilities: AccessCapabilities

    static let guest = ResolvedAccess(
        planTier: .free,
        accessMode: .guest,
        capabilities: .forMode(.guest)
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
