import CryptoKit
import Foundation
import StoreKit

enum SubscriptionPurchaseOutcome {
    case purchased
    case pending
    case cancelled
}

enum RestorePurchasesOutcome {
    case restored
    case nothingToRestore
}

enum EntitlementServiceError: LocalizedError {
    case accountRequired
    case subscriptionUnavailable
    case productUnavailable
    case purchaseVerificationFailed

    var errorDescription: String? {
        switch self {
        case .accountRequired:
            L10n.string("subscription.error.accountRequired")
        case .subscriptionUnavailable:
            L10n.string("subscription.error.unavailable")
        case .productUnavailable:
            L10n.string("subscription.error.productUnavailable")
        case .purchaseVerificationFailed:
            L10n.string("subscription.error.verificationFailed")
        }
    }
}

struct SubscriptionProduct: Identifiable, Equatable {
    let id: String
    let displayName: String
    let displayPrice: String
    let billingPeriod: String?
}

@MainActor
protocol EntitlementService {
    var isSubscriptionConfigured: Bool { get }

    func loadSubscriptionProducts() async throws -> [SubscriptionProduct]
    func resolvePlanTier(for user: AccountUser?) -> PlanTier
    func refreshPlanTier(for user: AccountUser?) async -> PlanTier
    func purchasePro(for user: AccountUser, productID: String) async throws -> SubscriptionPurchaseOutcome
    func restorePurchases(for user: AccountUser) async throws -> RestorePurchasesOutcome
}

@MainActor
final class StoreKitEntitlementService: EntitlementService {
    private let premiumProductIDs: [String]
    private let userDefaults: UserDefaults
    private let planTierCachePrefix = "avradio.planTier."

    init(
        premiumProductIDs: [String] = AppConfig.premiumProductIDs,
        userDefaults: UserDefaults = .standard
    ) {
        self.premiumProductIDs = premiumProductIDs
        self.userDefaults = userDefaults
    }

    var isSubscriptionConfigured: Bool {
        !premiumProductIDs.isEmpty
    }

    func loadSubscriptionProducts() async throws -> [SubscriptionProduct] {
        guard isSubscriptionConfigured else { return [] }

        let products = try await Product.products(for: premiumProductIDs)
        let productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })

        return premiumProductIDs.compactMap { productID in
            guard let product = productsByID[productID] else { return nil }

            return SubscriptionProduct(
                id: product.id,
                displayName: product.displayName,
                displayPrice: product.displayPrice,
                billingPeriod: billingPeriodText(for: product)
            )
        }
    }

    func resolvePlanTier(for user: AccountUser?) -> PlanTier {
        guard let user else { return .free }
        let cached = userDefaults.string(forKey: cacheKey(for: user.id)) ?? ""
        return PlanTier(rawValue: cached) ?? .free
    }

    func refreshPlanTier(for user: AccountUser?) async -> PlanTier {
        guard let user else { return .free }
        guard isSubscriptionConfigured else {
            cache(.free, for: user.id)
            return .free
        }

        let accountToken = appAccountToken(for: user)
        var resolvedTier: PlanTier = .free

        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }
            guard premiumProductIDs.contains(transaction.productID) else { continue }
            guard transaction.appAccountToken == accountToken else { continue }

            resolvedTier = .pro
            break
        }

        cache(resolvedTier, for: user.id)
        return resolvedTier
    }

    func purchasePro(for user: AccountUser, productID: String) async throws -> SubscriptionPurchaseOutcome {
        guard isSubscriptionConfigured else {
            throw EntitlementServiceError.subscriptionUnavailable
        }

        let product = try await loadProduct(id: productID)
        let result = try await product.purchase(options: [.appAccountToken(appAccountToken(for: user))])

        switch result {
        case .success(let verification):
            let transaction = try verifiedTransaction(from: verification)
            await transaction.finish()
            _ = await refreshPlanTier(for: user)
            return .purchased
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    func restorePurchases(for user: AccountUser) async throws -> RestorePurchasesOutcome {
        guard isSubscriptionConfigured else {
            throw EntitlementServiceError.subscriptionUnavailable
        }

        try await AppStore.sync()
        let refreshedTier = await refreshPlanTier(for: user)
        return refreshedTier == .pro ? .restored : .nothingToRestore
    }

    private func loadProduct(id: String) async throws -> Product {
        let products = try await Product.products(for: premiumProductIDs)
        guard let product = products.first(where: { $0.id == id }) else {
            throw EntitlementServiceError.productUnavailable
        }

        return product
    }

    private func verifiedTransaction(from verification: VerificationResult<Transaction>) throws -> Transaction {
        switch verification {
        case .verified(let transaction):
            transaction
        case .unverified:
            throw EntitlementServiceError.purchaseVerificationFailed
        }
    }

    private func cache(_ planTier: PlanTier, for userID: String) {
        userDefaults.set(planTier.rawValue, forKey: cacheKey(for: userID))
    }

    private func cacheKey(for userID: String) -> String {
        planTierCachePrefix + userID
    }

    private func appAccountToken(for user: AccountUser) -> UUID {
        let digest = SHA256.hash(data: Data(user.id.utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80

        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private func billingPeriodText(for product: Product) -> String? {
        guard let subscription = product.subscription else { return nil }
        let period = subscription.subscriptionPeriod
        return L10n.string("subscription.period.format", period.value, period.unit.localizedLabel)
    }
}

private extension Product.SubscriptionPeriod.Unit {
    var localizedLabel: String {
        switch self {
        case .day:
            L10n.string("subscription.period.unit.day")
        case .week:
            L10n.string("subscription.period.unit.week")
        case .month:
            L10n.string("subscription.period.unit.month")
        case .year:
            L10n.string("subscription.period.unit.year")
        @unknown default:
            L10n.string("subscription.period.unit.month")
        }
    }
}
