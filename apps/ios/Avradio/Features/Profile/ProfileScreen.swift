import StoreKit
import SwiftUI

struct ProfileScreen: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var accessController: AccessController
    @EnvironmentObject private var languageController: AppLanguageController
    @EnvironmentObject private var libraryStore: LibraryStore

    let startSignInFlow: (Bool) -> Void
    let bottomContentPadding: CGFloat

    @State private var isClearingLocalData = false
    @State private var isShowingClearLocalDataAlert = false
    @State private var isSigningOut = false
    @State private var signOutErrorMessage = ""
    @State private var isShowingSignOutError = false
    @State private var isShowingManageSubscriptions = false
    @State private var isPurchasingSubscription = false
    @State private var isRestoringPurchases = false
    @State private var subscriptionMessage = ""
    @State private var isShowingSubscriptionMessage = false
    @State private var purchasingProductID: String?

    private let genreTags = ["rock", "pop", "jazz", "news", "electronic", "ambient"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ShellBrandHeader(statusTitle: L10n.string("profile.statusTitle.account"))

                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.string("profile.title"))
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(AvradioTheme.textPrimary)

                    Text(L10n.string("profile.subtitle"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AvradioTheme.textSecondary)
                }

                accountManagementCard
                subscriptionCard
                profileSummaryCard
                appPreferencesCard
                localDataCard
                helpAndLegalCard

                if accessController.accessMode != .guest {
                    accountSafetyCard
                }
            }
            .padding(24)
            .padding(.bottom, bottomContentPadding)
        }
        .scrollIndicators(.hidden)
        .background(AvradioTheme.shellBackground.ignoresSafeArea())
        .manageSubscriptionsSheet(isPresented: $isShowingManageSubscriptions)
        .alert(L10n.string("profile.alert.clearData.title"), isPresented: $isShowingClearLocalDataAlert) {
            Button(L10n.string("profile.alert.clearData.cancel"), role: .cancel) {}
            Button(L10n.string("profile.alert.clearData.confirm"), role: .destructive) {
                isClearingLocalData = true
                libraryStore.clearLocalData()
                if accessController.accessMode == .guest {
                    startSignInFlow(false)
                }
                isClearingLocalData = false
            }
        } message: {
            Text(L10n.string("profile.alert.clearData.message"))
        }
        .alert(L10n.string("profile.alert.signOutFailed.title"), isPresented: $isShowingSignOutError) {
            Button(L10n.string("profile.alert.close"), role: .cancel) {}
        } message: {
            Text(signOutErrorMessage)
        }
        .alert(L10n.string("profile.alert.subscription.title"), isPresented: $isShowingSubscriptionMessage) {
            Button(L10n.string("profile.alert.close"), role: .cancel) {}
        } message: {
            Text(subscriptionMessage)
        }
    }

    private var profileSummaryCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                ProfileAvatar(initials: accessController.accountUser?.initials ?? "AV")

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(AvradioTheme.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AvradioTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()
                .overlay(AvradioTheme.borderSubtle)

            VStack(alignment: .leading, spacing: 12) {
                ShellRow(
                    systemImage: "person.crop.circle",
                    title: L10n.string("profile.summary.account.title"),
                    detail: accountSummaryDetail
                )
                ShellRow(
                    systemImage: "sparkles.rectangle.stack",
                    title: L10n.string("profile.summary.plan.title"),
                    detail: planSummaryDetail
                )
            }
        }
        .padding(22)
        .background(profileCardBackground)
    }

    private var accountManagementCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(
                title: L10n.string("profile.account.title"),
                subtitle: accountCardSubtitle
            )

            VStack(alignment: .leading, spacing: 12) {
                ShellRow(
                    systemImage: "person.badge.key",
                    title: L10n.string("profile.account.status.title"),
                    detail: accountStatusDetail
                )

                if let emailAddress = accessController.accountUser?.emailAddress {
                    ShellRow(
                        systemImage: "envelope",
                        title: L10n.string("profile.account.email.title"),
                        detail: emailAddress
                    )
                }
            }

            if accessController.accessMode == .guest {
                ProfilePrimaryButton(
                    title: accessController.accountIsAvailable
                        ? L10n.string("profile.account.connect")
                        : L10n.string("profile.account.connectUnavailable"),
                    action: { startSignInFlow(true) }
                )
                .disabled(!accessController.accountIsAvailable)
            } else {
                if let accountManagementURL = AppConfig.accountManagementURL {
                    ProfilePrimaryButton(
                        title: L10n.string("profile.account.manage"),
                        action: { open(accountManagementURL) }
                    )
                }

                ProfileSecondaryButton(
                    title: isSigningOut
                        ? L10n.string("profile.actions.signingOut")
                        : L10n.string("profile.actions.signOut"),
                    isLoading: isSigningOut,
                    action: {
                        Task { await signOut() }
                    }
                )
                .disabled(isSigningOut)
            }
        }
        .padding(22)
        .background(profileCardBackground)
    }

    private var subscriptionCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(
                title: L10n.string("profile.subscription.title"),
                subtitle: L10n.string("profile.subscription.subtitle")
            )

            VStack(alignment: .leading, spacing: 12) {
                ShellRow(
                    systemImage: "creditcard",
                    title: L10n.string("profile.subscription.status.title"),
                    detail: subscriptionStatusDetail
                )
                ShellRow(
                    systemImage: "apple.logo",
                    title: L10n.string("profile.subscription.manageSource.title"),
                    detail: L10n.string("profile.subscription.manageSource.detail")
                )
            }

            if accessController.accessMode == .guest {
                ProfileSecondaryButton(
                    title: L10n.string("profile.subscription.connect"),
                    action: { startSignInFlow(true) }
                )
                .disabled(!accessController.accountIsAvailable)
            } else if accessController.planTier == .free {
                if accessController.subscriptionProductsAreLoading {
                    ShellRow(
                        systemImage: "clock.arrow.circlepath",
                        title: L10n.string("profile.subscription.loading.title"),
                        detail: L10n.string("profile.subscription.loading.detail")
                    )
                } else if !accessController.subscriptionProducts.isEmpty {
                    VStack(spacing: 12) {
                        ForEach(accessController.subscriptionProducts) { product in
                            SubscriptionOfferCard(
                                product: product,
                                isLoading: purchasingProductID == product.id,
                                action: {
                                    Task { await purchaseSubscription(productID: product.id) }
                                }
                            )
                            .disabled(isPurchasingSubscription || isRestoringPurchases)
                        }
                    }
                }

                ProfileSecondaryButton(
                    title: isRestoringPurchases
                        ? L10n.string("profile.subscription.restoring")
                        : L10n.string("profile.subscription.restore"),
                    isLoading: isRestoringPurchases,
                    action: {
                        Task { await restorePurchases() }
                    }
                )
                .disabled(!accessController.subscriptionIsAvailable || isPurchasingSubscription || isRestoringPurchases)
            } else {
                ProfilePrimaryButton(
                    title: L10n.string("profile.subscription.manage"),
                    action: { isShowingManageSubscriptions = true }
                )

                ProfileSecondaryButton(
                    title: isRestoringPurchases
                        ? L10n.string("profile.subscription.restoring")
                        : L10n.string("profile.subscription.restore"),
                    isLoading: isRestoringPurchases,
                    action: {
                        Task { await restorePurchases() }
                    }
                )
                .disabled(!accessController.subscriptionIsAvailable || isRestoringPurchases || isPurchasingSubscription)
            }

            if !accessController.subscriptionIsAvailable {
                ShellRow(
                    systemImage: "info.circle",
                    title: L10n.string("profile.subscription.unavailable.title"),
                    detail: L10n.string("profile.subscription.unavailable.detail")
                )
            }
        }
        .padding(22)
        .background(profileCardBackground)
    }

    private var appPreferencesCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(
                title: L10n.string("profile.preferences.title"),
                subtitle: L10n.string("profile.preferences.subtitle")
            )

            ShellRow(
                systemImage: "globe",
                title: L10n.string("profile.preferences.language.title"),
                detail: L10n.string("profile.preferences.language.detail")
            )

            Picker(L10n.string("profile.preferences.language.title"), selection: languageSelection) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.displayName)
                        .tag(language)
                }
            }
            .pickerStyle(.segmented)

            if accessController.accessMode == .guest {
                ShellRow(
                    systemImage: "sparkles",
                    title: L10n.string("profile.preferences.accountPerk.title"),
                    detail: L10n.string("profile.preferences.accountPerk.detail")
                )
            } else {
                ShellRow(
                    systemImage: "music.note.list",
                    title: L10n.string("profile.preferences.preferredGenre.title"),
                    detail: L10n.string(
                        "profile.preferences.preferredGenre.detail",
                        preferredGenreLabel
                    )
                )

                Picker(
                    L10n.string("profile.preferences.preferredGenre.title"),
                    selection: preferredGenreSelection
                ) {
                    Text(L10n.string("profile.preferences.preferredGenre.none"))
                        .tag("")

                    ForEach(genreTags, id: \.self) { tag in
                        Text(L10n.genreLabel(for: tag))
                            .tag(tag)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .padding(22)
        .background(profileCardBackground)
    }

    private var localDataCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(
                title: L10n.string("profile.local.title"),
                subtitle: L10n.string("profile.local.subtitle")
            )

            VStack(alignment: .leading, spacing: 12) {
                ShellRow(
                    systemImage: "heart.text.square",
                    title: L10n.string("shell.library.favorites.title"),
                    detail: L10n.plural(
                        singular: "profile.local.favorites.count.one",
                        plural: "profile.local.favorites.count.other",
                        count: libraryStore.favorites.count,
                        libraryStore.favorites.count
                    )
                )
                ShellRow(
                    systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                    title: L10n.string("shell.home.recents.title"),
                    detail: L10n.plural(
                        singular: "profile.local.recents.count.one",
                        plural: "profile.local.recents.count.other",
                        count: libraryStore.recents.count,
                        libraryStore.recents.count
                    )
                )
                ShellRow(
                    systemImage: "internaldrive",
                    title: L10n.string("profile.local.storagePolicy.title"),
                    detail: accessController.capabilities.isLocalOnly
                        ? L10n.string("profile.local.storagePolicy.local")
                        : L10n.string("profile.local.storagePolicy.remote")
                )
            }

            ProfileDangerButton(
                title: isClearingLocalData
                    ? L10n.string("profile.actions.clearingData")
                    : L10n.string("profile.actions.clearData"),
                action: { isShowingClearLocalDataAlert = true }
            )
            .disabled(isClearingLocalData)
        }
        .padding(22)
        .background(profileCardBackground)
    }

    private var helpAndLegalCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(
                title: L10n.string("profile.help.title"),
                subtitle: L10n.string("profile.help.subtitle")
            )

            VStack(spacing: 12) {
                if let supportURL = AppConfig.supportURL {
                    ProfileActionRow(
                        systemImage: "questionmark.bubble",
                        title: L10n.string("profile.help.support.title"),
                        detail: L10n.string("profile.help.support.detail"),
                        action: { open(supportURL) }
                    )
                }
                if let termsURL = AppConfig.termsURL {
                    ProfileActionRow(
                        systemImage: "doc.text",
                        title: L10n.string("profile.help.terms.title"),
                        detail: L10n.string("profile.help.terms.detail"),
                        action: { open(termsURL) }
                    )
                }
                if let privacyURL = AppConfig.privacyURL {
                    ProfileActionRow(
                        systemImage: "hand.raised",
                        title: L10n.string("profile.help.privacy.title"),
                        detail: L10n.string("profile.help.privacy.detail"),
                        action: { open(privacyURL) }
                    )
                }
            }
        }
        .padding(22)
        .background(profileCardBackground)
    }

    private var accountSafetyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: L10n.string("profile.safety.title"),
                subtitle: L10n.string("profile.safety.subtitle")
            )

            if let accountManagementURL = AppConfig.accountManagementURL {
                ProfileActionRow(
                    systemImage: "exclamationmark.shield",
                    title: L10n.string("profile.safety.delete.title"),
                    detail: L10n.string("profile.safety.delete.detail"),
                    action: { open(accountManagementURL) }
                )
            }
        }
        .padding(22)
        .background(profileCardBackground)
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AvradioTheme.textPrimary)

            Text(subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AvradioTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var profileCardBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(AvradioTheme.cardSurface)
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(AvradioTheme.borderSubtle, lineWidth: 1)
            }
    }

    private var displayName: String {
        accessController.accountUser?.displayName ?? L10n.string("profile.displayName.local")
    }

    private var subtitle: String {
        switch accessController.accessMode {
        case .guest:
            L10n.string("profile.subtitle.guest")
        case .signedInFree, .signedInPro:
            accessController.accountUser?.emailAddress
                ?? accessController.accountUser?.id
                ?? L10n.string("profile.subtitle.accountFallback")
        }
    }

    private var accountSummaryDetail: String {
        switch accessController.accessMode {
        case .guest:
            L10n.string("profile.summary.account.detail.guest")
        case .signedInFree, .signedInPro:
            L10n.string("profile.summary.account.detail.signedIn", displayName)
        }
    }

    private var planSummaryDetail: String {
        switch accessController.accessMode {
        case .guest:
            L10n.string("profile.summary.plan.detail.guest")
        case .signedInFree:
            L10n.string("profile.summary.plan.detail.free")
        case .signedInPro:
            L10n.string("profile.summary.plan.detail.pro")
        }
    }

    private var accountCardSubtitle: String {
        switch accessController.accessMode {
        case .guest:
            L10n.string("profile.account.subtitle.guest")
        case .signedInFree, .signedInPro:
            L10n.string("profile.account.subtitle.signedIn")
        }
    }

    private var accountStatusDetail: String {
        switch accessController.accessMode {
        case .guest:
            L10n.string("profile.account.status.guest")
        case .signedInFree, .signedInPro:
            L10n.string("profile.account.status.signedIn")
        }
    }

    private var subscriptionStatusDetail: String {
        switch accessController.accessMode {
        case .guest:
            L10n.string("profile.subscription.status.guest")
        case .signedInFree:
            L10n.string("profile.subscription.status.free")
        case .signedInPro:
            L10n.string("profile.subscription.status.pro")
        }
    }

    private var languageSelection: Binding<AppLanguage> {
        Binding(
            get: { languageController.currentLanguage },
            set: { languageController.select($0) }
        )
    }

    private var preferredGenreSelection: Binding<String> {
        Binding(
            get: { libraryStore.settings.preferredTag },
            set: { libraryStore.setPreferredTag($0.isEmpty ? nil : $0) }
        )
    }

    private var preferredGenreLabel: String {
        let preferredTag = libraryStore.settings.preferredTag
        guard !preferredTag.isEmpty else {
            return L10n.string("profile.preferences.preferredGenre.none")
        }

        return L10n.genreLabel(for: preferredTag)
    }

    private func open(_ url: URL?) {
        guard let url else { return }
        openURL(url)
    }

    private func signOut() async {
        guard isSigningOut == false else { return }
        isSigningOut = true

        do {
            try await accessController.signOut()
        } catch {
            signOutErrorMessage = error.localizedDescription
            isShowingSignOutError = true
        }

        isSigningOut = false
    }

    private func purchaseSubscription(productID: String) async {
        guard !isPurchasingSubscription else { return }
        isPurchasingSubscription = true
        purchasingProductID = productID

        do {
            let outcome = try await accessController.purchasePro(productID: productID)
            switch outcome {
            case .purchased:
                subscriptionMessage = L10n.string("profile.subscription.message.purchased")
                isShowingSubscriptionMessage = true
            case .pending:
                subscriptionMessage = L10n.string("profile.subscription.message.pending")
                isShowingSubscriptionMessage = true
            case .cancelled:
                break
            }
        } catch {
            subscriptionMessage = error.localizedDescription
            isShowingSubscriptionMessage = true
        }

        isPurchasingSubscription = false
        purchasingProductID = nil
    }

    private func restorePurchases() async {
        guard !isRestoringPurchases else { return }
        isRestoringPurchases = true

        do {
            let outcome = try await accessController.restorePurchases()
            switch outcome {
            case .restored:
                subscriptionMessage = L10n.string("profile.subscription.message.restored")
            case .nothingToRestore:
                subscriptionMessage = L10n.string("profile.subscription.message.nothingToRestore")
            }
            isShowingSubscriptionMessage = true
        } catch {
            subscriptionMessage = error.localizedDescription
            isShowingSubscriptionMessage = true
        }

        isRestoringPurchases = false
    }
}

private struct ProfileAvatar: View {
    let initials: String

    var body: some View {
        ZStack {
            Circle()
                .fill(AvradioTheme.highlight.opacity(0.14))
                .frame(width: 56, height: 56)

            Text(initials)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AvradioTheme.textPrimary)
        }
        .overlay {
            Circle()
                .stroke(AvradioTheme.highlight.opacity(0.16), lineWidth: 1)
        }
    }
}

private struct ProfilePrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AvradioTheme.brandBlack)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    AvradioTheme.highlight,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct ProfileSecondaryButton: View {
    let title: String
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))

                Spacer()

                if isLoading {
                    ProgressView()
                        .tint(AvradioTheme.textPrimary)
                }
            }
            .foregroundStyle(AvradioTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .padding(.horizontal, 18)
            .background(
                AvradioTheme.cardSurface,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AvradioTheme.borderSubtle, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ProfileDangerButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(red: 0.84, green: 0.16, blue: 0.22))

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .padding(.horizontal, 18)
            .background(
                AvradioTheme.cardSurface,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(red: 0.84, green: 0.16, blue: 0.22).opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ProfileActionRow: View {
    let systemImage: String
    let title: String
    let detail: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AvradioTheme.highlight)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AvradioTheme.textPrimary)

                    Text(detail)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AvradioTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AvradioTheme.textSecondary.opacity(0.7))
                    .padding(.top, 4)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AvradioTheme.shellBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(AvradioTheme.borderSubtle, lineWidth: 1)
                    }
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SubscriptionOfferCard: View {
    let product: SubscriptionProduct
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AvradioTheme.textPrimary)

                    Text(product.billingPeriod ?? L10n.string("profile.subscription.period.fallback"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AvradioTheme.textSecondary)
                }

                Spacer()

                if isLoading {
                    ProgressView()
                        .tint(AvradioTheme.brandBlack)
                } else {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(product.displayPrice)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(AvradioTheme.brandBlack)

                        Text(L10n.string("profile.subscription.subscribe"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AvradioTheme.brandBlack.opacity(0.72))
                    }
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(AvradioTheme.highlight.opacity(0.16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(AvradioTheme.highlight.opacity(0.26), lineWidth: 1)
                    }
            )
        }
        .buttonStyle(.plain)
    }
}
