import Foundation

@MainActor
final class AccessController: ObservableObject {
    @Published private(set) var accessMode: AccessMode
    @Published private(set) var planTier: PlanTier
    @Published private(set) var capabilities: AccessCapabilities
    @Published private(set) var accountUser: AccountUser?
    @Published private(set) var accountSession: AccountSession?
    @Published private(set) var subscriptionProducts: [SubscriptionProduct]
    @Published private(set) var subscriptionProductsAreLoading: Bool

    let accountService: AVAppsAccountService

    private let entitlementService: EntitlementService
    private let userDefaults: UserDefaults
    private let guestOnboardingPolicy: GuestOnboardingPolicy
    private let now: () -> Date
    private let guestOnboardingLastPromptAtKey = "avradio.guestOnboarding.lastPromptAt"

    init(
        accountService: AVAppsAccountService = DefaultAVAppsAccountService(),
        entitlementService: EntitlementService? = nil,
        userDefaults: UserDefaults = .standard,
        guestOnboardingPolicy: GuestOnboardingPolicy = GuestOnboardingPolicy(),
        now: @escaping () -> Date = Date.init
    ) {
        let currentUser = accountService.currentUser

        self.accountService = accountService
        self.entitlementService = entitlementService ?? StoreKitEntitlementService(userDefaults: userDefaults)
        self.userDefaults = userDefaults
        self.guestOnboardingPolicy = guestOnboardingPolicy
        self.now = now
        self.accountUser = currentUser
        self.planTier = .free
        self.capabilities = AccessCapabilities.forMode(.guest)
        self.accountSession = nil
        self.subscriptionProducts = []
        self.subscriptionProductsAreLoading = false
        self.accessMode = .guest
        resolveAccessState()
    }

    var isSignedIn: Bool {
        accountUser != nil
    }

    var isLocalOnly: Bool {
        capabilities.isLocalOnly
    }

    var accountIsAvailable: Bool {
        accountService.isAvailable
    }

    var subscriptionIsAvailable: Bool {
        entitlementService.isSubscriptionConfigured
    }

    var shouldAutoShowGuestOnboarding: Bool {
        guard accessMode == .guest else { return false }
        return guestOnboardingPolicy.shouldShowAutomatically(
            lastPromptAt: userDefaults.object(forKey: guestOnboardingLastPromptAtKey) as? Date,
            now: now()
        )
    }

    func syncFromAccountProvider() async {
        accountUser = accountService.currentUser
        resolveAccessState()
        let refreshedTier = await entitlementService.refreshPlanTier(for: accountUser)
        applyResolvedPlanTier(refreshedTier)
        await refreshSubscriptionProducts()
    }

    func skipForNow() {
        markGuestOnboardingPromptShown()
    }

    func purchasePro(productID: String) async throws -> SubscriptionPurchaseOutcome {
        guard let accountUser else {
            throw EntitlementServiceError.accountRequired
        }

        let outcome = try await entitlementService.purchasePro(for: accountUser, productID: productID)
        resolveAccessState()
        return outcome
    }

    func restorePurchases() async throws -> RestorePurchasesOutcome {
        guard let accountUser else {
            throw EntitlementServiceError.accountRequired
        }

        let outcome = try await entitlementService.restorePurchases(for: accountUser)
        resolveAccessState()
        return outcome
    }

    func signOut() async throws {
        try await accountService.signOut()
        accountUser = nil
        resolveAccessState()
    }

    func markGuestOnboardingPromptShown() {
        userDefaults.set(now(), forKey: guestOnboardingLastPromptAtKey)
    }

    func refreshSubscriptionProducts() async {
        guard subscriptionIsAvailable else {
            subscriptionProducts = []
            subscriptionProductsAreLoading = false
            return
        }

        subscriptionProductsAreLoading = true
        defer { subscriptionProductsAreLoading = false }

        do {
            subscriptionProducts = try await entitlementService.loadSubscriptionProducts()
        } catch {
            subscriptionProducts = []
        }
    }

    private func resolveAccessState() {
        guard let accountUser else {
            planTier = .free
            accessMode = .guest
            capabilities = AccessCapabilities.forMode(.guest)
            accountSession = nil
            return
        }

        applyResolvedPlanTier(entitlementService.resolvePlanTier(for: accountUser))
    }

    private func applyResolvedPlanTier(_ resolvedPlanTier: PlanTier) {
        guard let accountUser else {
            planTier = .free
            accessMode = .guest
            capabilities = AccessCapabilities.forMode(.guest)
            accountSession = nil
            return
        }

        planTier = resolvedPlanTier
        accessMode = planTier == .pro ? .signedInPro : .signedInFree
        capabilities = AccessCapabilities.forMode(accessMode)
        accountSession = AccountSession(
            user: accountUser,
            planTier: planTier,
            accessMode: accessMode,
            capabilities: capabilities
        )
    }
}

struct GuestOnboardingPolicy {
    static let defaultCooldown: TimeInterval = 10 * 24 * 60 * 60

    let cooldown: TimeInterval

    init(cooldown: TimeInterval = defaultCooldown) {
        self.cooldown = cooldown
    }

    func shouldShowAutomatically(lastPromptAt: Date?, now: Date) -> Bool {
        guard let lastPromptAt else { return true }
        return now >= lastPromptAt.addingTimeInterval(cooldown)
    }
}
