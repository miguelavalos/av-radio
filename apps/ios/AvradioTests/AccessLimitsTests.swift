import XCTest
@testable import Avradio

final class AccessLimitsTests: XCTestCase {
    func testGuestLimitsAllowSmallLocalPreviewOnly() {
        let limits = AccessLimits.forMode(.guest)

        XCTAssertEqual(limits.favoriteStations, 5)
        XCTAssertEqual(limits.recentStations, 10)
        XCTAssertEqual(limits.discoveredTracks, 20)
        XCTAssertEqual(limits.savedTracks, 5)
        XCTAssertEqual(limits.lyricsSearchesPerDay, 3)
        XCTAssertEqual(limits.youtubeSearchesPerDay, 3)
        XCTAssertEqual(limits.appleMusicSearchesPerDay, 3)
        XCTAssertEqual(limits.spotifySearchesPerDay, 3)
        XCTAssertEqual(limits.discoverySharesPerDay, 1)
    }

    func testSignedInFreeLimitsAreHigherButStillLocalOnly() {
        let limits = AccessLimits.forMode(.signedInFree)
        let capabilities = AccessCapabilities.forMode(.signedInFree)

        XCTAssertEqual(limits.favoriteStations, 15)
        XCTAssertEqual(limits.recentStations, 25)
        XCTAssertEqual(limits.discoveredTracks, 50)
        XCTAssertEqual(limits.savedTracks, 20)
        XCTAssertEqual(limits.lyricsSearchesPerDay, 10)
        XCTAssertEqual(limits.youtubeSearchesPerDay, 10)
        XCTAssertEqual(limits.appleMusicSearchesPerDay, 10)
        XCTAssertEqual(limits.spotifySearchesPerDay, 10)
        XCTAssertEqual(limits.discoverySharesPerDay, 3)
        XCTAssertTrue(capabilities.isSignedIn)
        XCTAssertTrue(capabilities.isLocalOnly)
        XCTAssertFalse(capabilities.canUseBackend)
        XCTAssertFalse(capabilities.canUseCloudSync)
        XCTAssertFalse(capabilities.canAccessPremiumFeatures)
    }

    func testProKeepsLibraryLargeAndDailyMusicActionsUnlimited() {
        let limits = AccessLimits.forMode(.signedInPro)
        let capabilities = AccessCapabilities.forMode(.signedInPro)

        XCTAssertEqual(limits.favoriteStations, 500)
        XCTAssertEqual(limits.recentStations, 200)
        XCTAssertEqual(limits.discoveredTracks, 1_000)
        XCTAssertEqual(limits.savedTracks, 1_000)
        XCTAssertNil(limits.lyricsSearchesPerDay)
        XCTAssertNil(limits.youtubeSearchesPerDay)
        XCTAssertNil(limits.appleMusicSearchesPerDay)
        XCTAssertNil(limits.spotifySearchesPerDay)
        XCTAssertNil(limits.discoverySharesPerDay)
        XCTAssertTrue(capabilities.usesBackend)
        XCTAssertTrue(capabilities.canUseCloudSync)
        XCTAssertTrue(capabilities.canAccessPremiumFeatures)
    }

    func testFeatureLimitStateBlocksAtLimitAndReportsRemainingUsage() {
        let allowed = FeatureLimitState(feature: .favoriteStations, currentUsage: 4, limit: 5)
        let blocked = FeatureLimitState(feature: .favoriteStations, currentUsage: 5, limit: 5)
        let unlimited = FeatureLimitState(feature: .lyricsSearch, currentUsage: 10_000, limit: nil)

        XCTAssertTrue(allowed.isLimited)
        XCTAssertTrue(allowed.isAllowed)
        XCTAssertEqual(allowed.remaining, 1)

        XCTAssertTrue(blocked.isLimited)
        XCTAssertFalse(blocked.isAllowed)
        XCTAssertEqual(blocked.remaining, 0)

        XCTAssertFalse(unlimited.isLimited)
        XCTAssertTrue(unlimited.isAllowed)
        XCTAssertNil(unlimited.remaining)
    }

    func testLimitLookupMapsEveryLimitedFeatureToItsConfiguredValue() {
        let limits = AccessLimits.forMode(.guest)

        XCTAssertEqual(limits.limit(for: .favoriteStations), limits.favoriteStations)
        XCTAssertEqual(limits.limit(for: .savedTracks), limits.savedTracks)
        XCTAssertEqual(limits.limit(for: .discoveredTracks), limits.discoveredTracks)
        XCTAssertEqual(limits.limit(for: .lyricsSearch), limits.lyricsSearchesPerDay)
        XCTAssertEqual(limits.limit(for: .youtubeSearch), limits.youtubeSearchesPerDay)
        XCTAssertEqual(limits.limit(for: .appleMusicSearch), limits.appleMusicSearchesPerDay)
        XCTAssertEqual(limits.limit(for: .spotifySearch), limits.spotifySearchesPerDay)
        XCTAssertEqual(limits.limit(for: .discoveryShare), limits.discoverySharesPerDay)
    }

    @MainActor
    func testDailyFeatureCountersBlockAtGuestLimit() {
        let userDefaults = isolatedUserDefaults()
        let controller = AccessController(
            accountService: StubAccountService(user: nil),
            entitlementService: StubEntitlementService(access: .guest),
            userDefaults: userDefaults,
            now: { self.fixedDate("2026-04-30T10:00:00Z") }
        )

        XCTAssertTrue(controller.canUseDailyFeature(.lyricsSearch))
        XCTAssertEqual(controller.dailyLimitState(for: .lyricsSearch).remaining, 3)

        controller.recordDailyFeatureUse(.lyricsSearch)
        controller.recordDailyFeatureUse(.lyricsSearch)
        controller.recordDailyFeatureUse(.lyricsSearch)

        XCTAssertFalse(controller.canUseDailyFeature(.lyricsSearch))
        XCTAssertEqual(controller.dailyLimitState(for: .lyricsSearch).remaining, 0)
    }

    @MainActor
    func testDailyFeatureCountersResetOnNextDay() {
        let userDefaults = isolatedUserDefaults()
        var currentDate = fixedDate("2026-04-30T10:00:00Z")
        let controller = AccessController(
            accountService: StubAccountService(user: nil),
            entitlementService: StubEntitlementService(access: .guest),
            userDefaults: userDefaults,
            now: { currentDate }
        )

        controller.recordDailyFeatureUse(.youtubeSearch)
        XCTAssertEqual(controller.dailyLimitState(for: .youtubeSearch).remaining, 2)

        currentDate = fixedDate("2026-05-01T10:00:00Z")

        XCTAssertTrue(controller.canUseDailyFeature(.youtubeSearch))
        XCTAssertEqual(controller.dailyLimitState(for: .youtubeSearch).remaining, 3)
    }

    @MainActor
    func testDailyMusicActionCountersAreIndependent() {
        let controller = AccessController(
            accountService: StubAccountService(user: nil),
            entitlementService: StubEntitlementService(access: .guest),
            userDefaults: isolatedUserDefaults(),
            now: { self.fixedDate("2026-04-30T10:00:00Z") }
        )

        let musicActions: [LimitedFeature] = [
            .lyricsSearch,
            .youtubeSearch,
            .appleMusicSearch,
            .spotifySearch
        ]

        for feature in musicActions {
            XCTAssertEqual(controller.dailyLimitState(for: feature).remaining, 3)
        }

        controller.recordDailyFeatureUse(.lyricsSearch)
        controller.recordDailyFeatureUse(.lyricsSearch)
        controller.recordDailyFeatureUse(.youtubeSearch)

        XCTAssertEqual(controller.dailyLimitState(for: .lyricsSearch).remaining, 1)
        XCTAssertEqual(controller.dailyLimitState(for: .youtubeSearch).remaining, 2)
        XCTAssertEqual(controller.dailyLimitState(for: .appleMusicSearch).remaining, 3)
        XCTAssertEqual(controller.dailyLimitState(for: .spotifySearch).remaining, 3)
    }

    @MainActor
    func testUpgradePromptUsesTheBlockedFeatureAndConfiguredLimit() {
        let controller = AccessController(
            accountService: StubAccountService(user: nil),
            entitlementService: StubEntitlementService(access: .guest),
            userDefaults: isolatedUserDefaults(),
            now: { self.fixedDate("2026-04-30T10:00:00Z") }
        )

        controller.presentUpgradePrompt(for: .youtubeSearch, currentUsage: 3)

        XCTAssertEqual(controller.upgradePrompt?.feature, .youtubeSearch)
        XCTAssertEqual(controller.upgradePrompt?.title, L10n.string("limits.upgrade.youtube.title"))
        XCTAssertEqual(controller.upgradePrompt?.message, L10n.string("limits.upgrade.youtube.message", 3))
    }

    @MainActor
    func testProDailyFeaturesRemainAllowedWithoutDailyLimit() {
        let user = AccountUser(id: "pro-user", displayName: "Pro User", emailAddress: "pro@example.com")
        let controller = AccessController(
            accountService: StubAccountService(user: user),
            entitlementService: StubEntitlementService(access: ResolvedAccess(
                planTier: .pro,
                accessMode: .signedInPro,
                capabilities: .forMode(.signedInPro),
                limits: .forMode(.signedInPro)
            )),
            userDefaults: isolatedUserDefaults(),
            now: { self.fixedDate("2026-04-30T10:00:00Z") }
        )

        for _ in 0..<25 {
            controller.recordDailyFeatureUse(.appleMusicSearch)
        }

        XCTAssertTrue(controller.canUseDailyFeature(.appleMusicSearch))
        XCTAssertNil(controller.dailyLimitState(for: .appleMusicSearch).remaining)
    }

    private func isolatedUserDefaults() -> UserDefaults {
        let suiteName = "AccessLimitsTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        return userDefaults
    }

    private func fixedDate(_ iso8601: String) -> Date {
        ISO8601DateFormatter().date(from: iso8601)!
    }
}

@MainActor
private struct StubAccountService: AVAppsAccountService {
    let user: AccountUser?

    var isAvailable: Bool { true }
    var currentUser: AccountUser? { user }

    func getToken() async throws -> String? {
        nil
    }

    func signInWithApple() async throws {}

    func signInWithGoogle() async throws {}

    func signOut() async throws {}
}

@MainActor
private struct StubEntitlementService: EntitlementService {
    let access: ResolvedAccess

    var isSubscriptionConfigured: Bool { true }

    func loadSubscriptionProducts() async throws -> [SubscriptionProduct] {
        []
    }

    func resolveAccess(for user: AccountUser?) -> ResolvedAccess {
        user == nil ? .guest : access
    }

    func refreshAccess(for user: AccountUser?) async -> ResolvedAccess {
        resolveAccess(for: user)
    }

    func purchasePro(for user: AccountUser, productID: String) async throws -> SubscriptionPurchaseOutcome {
        .purchased
    }

    func restorePurchases(for user: AccountUser) async throws -> RestorePurchasesOutcome {
        .restored
    }
}
