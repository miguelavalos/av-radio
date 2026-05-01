import XCTest
@testable import Avradio

final class AccessLimitsTests: XCTestCase {
    func testAccessPolicyMatchesSharedContract() throws {
        let contract = try loadAccessPolicyContract()
        let expectedModes: [(mode: AccessMode, planTier: String)] = [
            (.guest, "free"),
            (.signedInFree, "free"),
            (.signedInPro, "pro")
        ]

        XCTAssertEqual(contract.appId, "avradio")
        XCTAssertEqual(contract.schemaVersion, 1)
        XCTAssertEqual(Set(contract.accessModes.keys), Set(expectedModes.map { $0.mode.rawValue }))

        for expectedMode in expectedModes {
            let contractMode = try XCTUnwrap(contract.accessModes[expectedMode.mode.rawValue])
            XCTAssertEqual(contractMode.planTier, expectedMode.planTier)
            XCTAssertEqual(AccessCapabilities.forMode(expectedMode.mode), contractMode.capabilities.avradioValue)
            XCTAssertEqual(AccessLimits.forMode(expectedMode.mode), contractMode.limits.avradioValue)
        }
    }

    func testGuestLimitsAllowSmallLocalPreviewOnly() {
        let limits = AccessLimits.forMode(.guest)

        XCTAssertEqual(limits.favoriteStations, 10)
        XCTAssertEqual(limits.recentStations, 12)
        XCTAssertEqual(limits.discoveredTracks, 25)
        XCTAssertEqual(limits.savedTracks, 10)
        XCTAssertEqual(limits.lyricsSearchesPerDay, 5)
        XCTAssertEqual(limits.youtubeSearchesPerDay, 5)
        XCTAssertEqual(limits.appleMusicSearchesPerDay, 5)
        XCTAssertEqual(limits.spotifySearchesPerDay, 5)
        XCTAssertEqual(limits.discoverySharesPerDay, 2)
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

    func testLibrarySyncPlannerPushesLocalWhenRemoteIsEmpty() {
        let local = librarySnapshot(favorites: [favoriteRecord()], updatedAt: "2026-04-30T10:00:00Z")
        let remote = libraryDocument(snapshot: nil, updatedAt: fixedDate("2026-04-30T09:00:00Z"))

        XCTAssertEqual(
            AVRadioLibrarySyncPlanner.decision(
                localSnapshot: local,
                localUpdatedAt: fixedDate("2026-04-30T10:00:00Z"),
                remoteDocument: remote
            ),
            .pushLocal
        )
    }

    func testLibrarySyncPlannerPullsRemoteWhenRemoteIsNewer() {
        let local = librarySnapshot(favorites: [favoriteRecord()], updatedAt: "2026-04-30T10:00:00Z")
        let remoteSnapshot = librarySnapshot(
            favorites: [favoriteRecord(id: "remote")],
            updatedAt: "2026-04-30T11:00:00Z"
        )
        let remote = libraryDocument(
            snapshot: remoteSnapshot,
            updatedAt: fixedDate("2026-04-30T11:00:00Z")
        )

        XCTAssertEqual(
            AVRadioLibrarySyncPlanner.decision(
                localSnapshot: local,
                localUpdatedAt: fixedDate("2026-04-30T10:00:00Z"),
                remoteDocument: remote
            ),
            .pullRemote(remoteSnapshot)
        )
    }

    func testLibrarySyncPlannerLeavesMatchingDocumentsCurrent() {
        let snapshot = librarySnapshot(favorites: [favoriteRecord()], updatedAt: "2026-04-30T10:00:00Z")
        let date = fixedDate("2026-04-30T10:00:00Z")

        XCTAssertEqual(
            AVRadioLibrarySyncPlanner.decision(
                localSnapshot: snapshot,
                localUpdatedAt: date,
                remoteDocument: libraryDocument(snapshot: snapshot, updatedAt: date)
            ),
            .alreadyCurrent
        )
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
        XCTAssertEqual(controller.dailyLimitState(for: .lyricsSearch).remaining, 5)

        controller.recordDailyFeatureUse(.lyricsSearch)
        controller.recordDailyFeatureUse(.lyricsSearch)
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
        XCTAssertEqual(controller.dailyLimitState(for: .youtubeSearch).remaining, 4)

        currentDate = fixedDate("2026-05-01T10:00:00Z")

        XCTAssertTrue(controller.canUseDailyFeature(.youtubeSearch))
        XCTAssertEqual(controller.dailyLimitState(for: .youtubeSearch).remaining, 5)
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
            XCTAssertEqual(controller.dailyLimitState(for: feature).remaining, 5)
        }

        controller.recordDailyFeatureUse(.lyricsSearch)
        controller.recordDailyFeatureUse(.lyricsSearch)
        controller.recordDailyFeatureUse(.youtubeSearch)

        XCTAssertEqual(controller.dailyLimitState(for: .lyricsSearch).remaining, 3)
        XCTAssertEqual(controller.dailyLimitState(for: .youtubeSearch).remaining, 4)
        XCTAssertEqual(controller.dailyLimitState(for: .appleMusicSearch).remaining, 5)
        XCTAssertEqual(controller.dailyLimitState(for: .spotifySearch).remaining, 5)
    }

    @MainActor
    func testDailyFeatureUsageKeysOnlyCountUniqueUses() {
        let controller = AccessController(
            accountService: StubAccountService(user: nil),
            entitlementService: StubEntitlementService(access: .guest),
            userDefaults: isolatedUserDefaults(),
            now: { self.fixedDate("2026-04-30T10:00:00Z") }
        )

        let lyricsURL = "https://www.google.com/search?q=artist%20song%20lyrics"
        XCTAssertTrue(controller.canUseDailyFeature(.lyricsSearch, usageKey: lyricsURL))

        controller.recordDailyFeatureUse(.lyricsSearch, usageKey: lyricsURL)
        controller.recordDailyFeatureUse(.lyricsSearch, usageKey: lyricsURL)
        controller.recordDailyFeatureUse(.lyricsSearch, usageKey: "  \(lyricsURL.uppercased())  ")

        XCTAssertEqual(controller.dailyLimitState(for: .lyricsSearch).remaining, 4)

        controller.recordDailyFeatureUse(.lyricsSearch, usageKey: "https://www.google.com/search?q=other%20song%20lyrics")
        XCTAssertEqual(controller.dailyLimitState(for: .lyricsSearch).remaining, 3)
    }

    @MainActor
    func testPreviouslyUsedDailyFeatureKeyRemainsAllowedAfterLimitIsReached() {
        let controller = AccessController(
            accountService: StubAccountService(user: nil),
            entitlementService: StubEntitlementService(access: .guest),
            userDefaults: isolatedUserDefaults(),
            now: { self.fixedDate("2026-04-30T10:00:00Z") }
        )

        let usedURL = "https://www.google.com/search?q=artist%20song%20lyrics"
        let usageKeys = [
            usedURL,
            "https://www.google.com/search?q=artist%20song%202%20lyrics",
            "https://www.google.com/search?q=artist%20song%203%20lyrics",
            "https://www.google.com/search?q=artist%20song%204%20lyrics",
            "https://www.google.com/search?q=artist%20song%205%20lyrics"
        ]

        for usageKey in usageKeys {
            XCTAssertTrue(controller.canUseDailyFeature(.lyricsSearch, usageKey: usageKey))
            controller.recordDailyFeatureUse(.lyricsSearch, usageKey: usageKey)
        }

        XCTAssertEqual(controller.dailyLimitState(for: .lyricsSearch).remaining, 0)
        XCTAssertTrue(controller.canUseDailyFeature(.lyricsSearch, usageKey: usedURL))
        XCTAssertFalse(controller.canUseDailyFeature(.lyricsSearch, usageKey: "https://www.google.com/search?q=new%20song%20lyrics"))
    }

    @MainActor
    func testUpgradePromptUsesTheBlockedFeatureAndConfiguredLimit() {
        let controller = AccessController(
            accountService: StubAccountService(user: nil),
            entitlementService: StubEntitlementService(access: .guest),
            userDefaults: isolatedUserDefaults(),
            now: { self.fixedDate("2026-04-30T10:00:00Z") }
        )

        controller.presentUpgradePrompt(for: .youtubeSearch, currentUsage: 5)

        XCTAssertEqual(controller.upgradePrompt?.feature, .youtubeSearch)
        XCTAssertEqual(controller.upgradePrompt?.title, L10n.string("limits.upgrade.youtube.title"))
        XCTAssertEqual(controller.upgradePrompt?.message, L10n.string("limits.upgrade.youtube.message", 5))
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

    private func loadAccessPolicyContract() throws -> AccessPolicyContract {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let contractURL = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("shared/contracts/access-policy.json")
        let data = try Data(contentsOf: contractURL)
        return try JSONDecoder().decode(AccessPolicyContract.self, from: data)
    }

    private func fixedDate(_ iso8601: String) -> Date {
        ISO8601DateFormatter().date(from: iso8601)!
    }

    private func libraryDocument(
        snapshot: AVRadioLibrarySnapshot?,
        updatedAt: Date
    ) -> AVRadioLibraryDocument {
        AVRadioLibraryDocument(
            snapshot: snapshot,
            updatedAt: updatedAt,
            revision: 1,
            etag: "\"revision-1\""
        )
    }

    private func librarySnapshot(
        favorites: [FavoriteStationRecord] = [],
        updatedAt: String
    ) -> AVRadioLibrarySnapshot {
        AVRadioLibrarySnapshot(
            favorites: favorites,
            recents: [],
            discoveries: [],
            settings: AppSettingsRecord(
                preferredCountry: "",
                preferredLanguage: "",
                preferredTag: "",
                lastPlayedStationID: nil,
                sleepTimerMinutes: nil,
                updatedAt: updatedAt
            )
        )
    }

    private func favoriteRecord(id: String = "station") -> FavoriteStationRecord {
        FavoriteStationRecord(
            station: StationRecord(
                id: id,
                name: "Station \(id)",
                country: "Spain",
                countryCode: "ES",
                state: nil,
                language: "Spanish",
                languageCodes: "es",
                tags: "radio",
                streamURL: "https://example.com/\(id).mp3",
                faviconURL: nil,
                bitrate: 128,
                codec: "MP3",
                homepageURL: nil,
                votes: nil,
                clickCount: nil,
                clickTrend: nil,
                isHLS: false,
                hasExtendedInfo: false,
                hasSSLError: false,
                lastCheckOKAt: nil,
                geoLatitude: nil,
                geoLongitude: nil
            ),
            createdAt: "2026-04-30T10:00:00Z"
        )
    }
}

private struct AccessPolicyContract: Decodable {
    let appId: String
    let schemaVersion: Int
    let accessModes: [String: AccessPolicyModeContract]
}

private struct AccessPolicyModeContract: Decodable {
    let planTier: String
    let capabilities: AccessCapabilitiesContract
    let limits: AccessLimitsContract
}

private struct AccessCapabilitiesContract: Decodable {
    let isSignedIn: Bool
    let canUseBackend: Bool
    let canUsePremiumFeatures: Bool
    let canUseCloudSync: Bool
    let canManagePlan: Bool

    var avradioValue: AccessCapabilities {
        AccessCapabilities(
            isSignedIn: isSignedIn,
            canUseBackend: canUseBackend,
            canAccessPremiumFeatures: canUsePremiumFeatures,
            canUseCloudSync: canUseCloudSync,
            canManagePlan: canManagePlan
        )
    }
}

private struct AccessLimitsContract: Decodable {
    let favoriteStations: Int?
    let recentStations: Int?
    let discoveredTracks: Int?
    let savedTracks: Int?
    let lyricsSearchesPerDay: Int?
    let youtubeSearchesPerDay: Int?
    let appleMusicSearchesPerDay: Int?
    let spotifySearchesPerDay: Int?
    let discoverySharesPerDay: Int?

    var avradioValue: AccessLimits {
        AccessLimits(
            favoriteStations: favoriteStations,
            recentStations: recentStations,
            discoveredTracks: discoveredTracks,
            savedTracks: savedTracks,
            lyricsSearchesPerDay: lyricsSearchesPerDay,
            youtubeSearchesPerDay: youtubeSearchesPerDay,
            appleMusicSearchesPerDay: appleMusicSearchesPerDay,
            spotifySearchesPerDay: spotifySearchesPerDay,
            discoverySharesPerDay: discoverySharesPerDay
        )
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
