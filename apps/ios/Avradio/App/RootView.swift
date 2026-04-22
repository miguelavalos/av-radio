import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var accessController: AccessController
    @State private var authOptionsArePresented = false
    @State private var automaticGuestOnboardingIsPresented = false
    @State private var isShowingAccountOnboarding = false
    @State private var isShowingSplash = true

    private let launchContext = LaunchContext.current

    var body: some View {
        Group {
            if shouldShowOnboarding {
                AuthOnboardingView(
                    authOptionsArePresented: $authOptionsArePresented,
                    accountIsAvailable: accessController.accountIsAvailable,
                    onContinueWithApple: startAppleSignIn,
                    onContinueWithGoogle: startGoogleSignIn,
                    onSkip: {
                        automaticGuestOnboardingIsPresented = false
                        isShowingAccountOnboarding = false
                        accessController.skipForNow()
                    }
                )
            } else {
                AppShellView(
                    launchContext: launchContext,
                    startSignInFlow: startSignInFlow
                )
                    .environmentObject(accessController)
                    .overlay {
                        if isShowingSplash {
                            AvradioSplashView()
                                .transition(.opacity)
                                .zIndex(1)
                        }
                    }
                    .task(id: accessController.accessMode) {
                        isShowingSplash = true
                        try? await Task.sleep(for: .milliseconds(1150))

                        await MainActor.run {
                            withAnimation(.easeOut(duration: 0.35)) {
                                isShowingSplash = false
                            }
                        }
                }
            }
        }
        .tint(AvradioTheme.highlight)
        .task {
            await accessController.syncFromAccountProvider()
            presentAutomaticGuestOnboardingIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await accessController.syncFromAccountProvider()
                presentAutomaticGuestOnboardingIfNeeded()
            }
        }
        .onChange(of: accessController.accessMode) { _, _ in
            authOptionsArePresented = false

            if accessController.accessMode != .guest {
                automaticGuestOnboardingIsPresented = false
                isShowingAccountOnboarding = false
            }
        }
    }

    private var shouldShowOnboarding: Bool {
        isShowingAccountOnboarding || automaticGuestOnboardingIsPresented
    }

    private func startSignInFlow(showAuthOptions: Bool = false) {
        authOptionsArePresented = showAuthOptions
        isShowingAccountOnboarding = true
    }

    private func startAppleSignIn() async throws {
        try await accessController.accountService.signInWithApple()
        automaticGuestOnboardingIsPresented = false
        await accessController.syncFromAccountProvider()
        isShowingAccountOnboarding = false
    }

    private func startGoogleSignIn() async throws {
        try await accessController.accountService.signInWithGoogle()
        automaticGuestOnboardingIsPresented = false
        await accessController.syncFromAccountProvider()
        isShowingAccountOnboarding = false
    }

    private func presentAutomaticGuestOnboardingIfNeeded() {
        guard automaticGuestOnboardingIsPresented == false else { return }
        guard isShowingAccountOnboarding == false else { return }
        guard accessController.shouldAutoShowGuestOnboarding else { return }

        accessController.markGuestOnboardingPromptShown()
        automaticGuestOnboardingIsPresented = true
    }
}

struct MissingConfigurationView: View {
    var body: some View {
        ZStack {
            AvradioTheme.shellBackground.ignoresSafeArea()

            VStack(spacing: 18) {
                Image("BrandMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    .padding(14)
                    .background(AvradioTheme.cardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(AvradioTheme.borderSubtle, lineWidth: 1)
                    }

                Text(L10n.string("root.missingConfiguration.title"))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AvradioTheme.textPrimary)

                Text(L10n.string("root.missingConfiguration.message"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AvradioTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(AvradioTheme.cardSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(AvradioTheme.borderSubtle, lineWidth: 1)
                    }
            )
            .padding(24)
        }
    }
}

#Preview {
    MissingConfigurationView()
}
