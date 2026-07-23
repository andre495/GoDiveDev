import SwiftData
import SwiftUI

/// Gates **`ContentView`** behind Sign in with Apple when no local profile session exists.
struct AppSessionRootView: View {
    /// **`false`** until **`ProductionAppRoot`** registers the live container + CloudKit reconnect handler.
    var isSessionRestoreAllowed = true

    @Environment(AccountSession.self) private var accountSession
    @Environment(\.modelContext) private var modelContext

    /// Defers hidden **`ContentView`** mount until after the celebration first frame paints.
    @State private var allowsCelebrationShellPrewarm = false
    @State private var pendingFriendInviteToken: String?
    @State private var didRunInitialSessionRestore = false

    private var showsBootstrapOverlay: Bool {
        AppSessionBootstrapPresentation.showsLaunchOverlay(
            isRestoringSession: accountSession.isRestoringSession,
            isPopulatingRemoteAccountData: accountSession.isPopulatingRemoteAccountData
        )
    }

    private var shouldMountMainAppShellUnderlay: Bool {
        AccountSessionMainShellPresentation.shouldMountMainAppShellUnderlay(
            isRestoringSession: accountSession.isRestoringSession,
            isPopulatingRemoteAccountData: accountSession.isPopulatingRemoteAccountData,
            isSignedIn: accountSession.isSignedIn,
            showsNewAccountWelcome: accountSession.showsNewAccountWelcome,
            showsPostSignUpInterests: accountSession.showsPostSignUpInterests,
            showsPostSignUpProfileSetup: accountSession.showsPostSignUpProfileSetup,
            showsPostSignUpPermissions: accountSession.showsPostSignUpPermissions,
            showsPostSignUpImportOffer: accountSession.showsPostSignUpImportOffer,
            showsPostSignUpOnboardingImport: accountSession.showsPostSignUpOnboardingImport,
            showsSignInCelebration: accountSession.showsSignInCelebration,
            allowsCelebrationShellPrewarm: allowsCelebrationShellPrewarm
        )
    }

    var body: some View {
        ZStack {
            Group {
                if accountSession.isSignedIn {
                    signedInShell
                } else if !accountSession.isRestoringSession {
                    if AppLoggedOutOnboardingPresentation.shouldPresentOnboarding() {
                        LoggedOutOnboardingView()
                    } else {
                        SignInView()
                    }
                } else {
                    Color.clear
                }
            }

            if showsBootstrapOverlay {
                AppLaunchOverlay(showsProgressIndicator: true)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showsBootstrapOverlay)
        .animation(.easeInOut(duration: 0.2), value: accountSession.showsNewAccountWelcome)
        .animation(.easeInOut(duration: 0.35), value: accountSession.showsPostSignUpInterests)
        .animation(.easeInOut(duration: 0.35), value: accountSession.showsPostSignUpProfileSetup)
        .animation(.easeInOut(duration: 0.35), value: accountSession.showsPostSignUpPermissions)
        .animation(.easeInOut(duration: 0.35), value: accountSession.showsPostSignUpImportOffer)
        .animation(.easeInOut(duration: 0.35), value: accountSession.showsPostSignUpOnboardingImport)
        .animation(nil, value: accountSession.showsSignInCelebration)
        .animation(.easeInOut(duration: 0.25), value: allowsCelebrationShellPrewarm)
        .task(id: isSessionRestoreAllowed) {
            guard isSessionRestoreAllowed else { return }
            guard !didRunInitialSessionRestore else { return }
            didRunInitialSessionRestore = true
            await accountSession.restoreSession(modelContext: modelContext)
            presentPendingFriendInviteIfNeeded()
        }
        .onOpenURL { url in
            GoDiveFriendInviteDeepLinkStore.shared.handleIncomingURL(url)
            presentPendingFriendInviteIfNeeded()
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            guard let url = activity.webpageURL else { return }
            GoDiveFriendInviteDeepLinkStore.shared.handleIncomingURL(url)
            presentPendingFriendInviteIfNeeded()
        }
        .onChange(of: accountSession.showsMainAppShell) { _, showsShell in
            if showsShell {
                presentPendingFriendInviteIfNeeded()
            }
        }
        .sheet(item: Binding(
            get: { pendingFriendInviteToken.map(FriendInviteTokenBox.init) },
            set: { pendingFriendInviteToken = $0?.token }
        )) { box in
            FriendInviteRedeemSheet(token: box.token) {
                pendingFriendInviteToken = nil
                GoDiveFriendInviteDeepLinkStore.shared.clear()
            }
            .appSheetPresentationChrome()
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: accountSession.showsSignInCelebration) { _, showsCelebration in
            if showsCelebration {
                SignInCelebrationTransitionDiagnostics.mark("AppSessionRoot_showsSignInCelebration_true")
                #if canImport(GoogleMaps)
                GoogleMapsWarmup.warmUpIfNeeded(includeHiddenMapView: false)
                #endif
                scheduleCelebrationShellPrewarm()
            } else {
                allowsCelebrationShellPrewarm = false
                SignInCelebrationTransitionDiagnostics.mark("AppSessionRoot_showsSignInCelebration_false")
            }
        }
    }

    @ViewBuilder
    private var signedInShell: some View {
        ZStack {
            if shouldMountMainAppShellUnderlay {
                ContentView()
                    .environment(
                        \.isCelebrationShellPrewarmActive,
                        accountSession.showsSignInCelebration
                    )
                    .opacity(accountSession.showsSignInCelebration ? 0 : 1)
                    .animation(nil, value: accountSession.showsSignInCelebration)
                    .allowsHitTesting(!accountSession.showsSignInCelebration)
                    .accessibilityHidden(accountSession.showsSignInCelebration)
                    .onAppear {
                        SignInCelebrationTransitionDiagnostics.mark("ContentView_onAppear")
                    }
            }

            postSignUpOverlay
        }
    }

    @ViewBuilder
    private var postSignUpOverlay: some View {
        if accountSession.showsPostSignUpInterests {
            PostSignUpInterestsView { selection in
                try? accountSession.completePostSignUpInterests(
                    selection: selection,
                    modelContext: modelContext
                )
            }
            .transition(.opacity)
        } else if accountSession.showsPostSignUpProfileSetup {
            PostSignUpProfileSetupView(
                onComplete: {
                    accountSession.completePostSignUpProfileSetup()
                }
            )
            .transition(.opacity)
        } else if accountSession.showsPostSignUpPermissions {
            PostSignUpPermissionsView {
                accountSession.completePostSignUpPermissions()
            }
            .transition(.opacity)
        } else if accountSession.showsPostSignUpImportOffer {
            PostSignUpImportOfferView(
                onImport: {
                    accountSession.completePostSignUpImportOffer(choseImport: true)
                },
                onSkip: {
                    accountSession.completePostSignUpImportOffer(choseImport: false)
                }
            )
            .transition(.opacity)
        } else if accountSession.showsPostSignUpOnboardingImport {
            PostSignUpOnboardingImportView(
                onComplete: { followsBulkImport in
                    accountSession.completePostSignUpOnboardingImport(followsBulkImport: followsBulkImport)
                }
            )
            .transition(.opacity)
        } else if accountSession.showsSignInCelebration {
            SignInCelebrationView {
                accountSession.completeSignInCelebration()
            }
            .transition(.opacity)
        } else if accountSession.showsNewAccountWelcome {
            NewAccountWelcomeView(
                displayName: accountSession.currentProfile?.displayName,
                onContinue: {
                    accountSession.completeNewAccountWelcome()
                }
            )
        }
    }

    private func scheduleCelebrationShellPrewarm() {
        allowsCelebrationShellPrewarm = false
        let delayNanoseconds = accountSession.celebrationFollowsBulkImport
            ? CelebrationShellPrewarmPresentation.postBulkImportDelayNanoseconds
            : CelebrationShellPrewarmPresentation.defaultDelayNanoseconds
        let delayMs = Double(delayNanoseconds) / 1_000_000
        SignInCelebrationTransitionDiagnostics.mark(
            "celebration_shell_prewarm_scheduled delayMs=\(Int(delayMs)) bulkImport=\(accountSession.celebrationFollowsBulkImport)"
        )

        Task { @MainActor in
            let signpostID = SignInCelebrationTransitionDiagnostics.begin(.celebrationShellPrewarm)
            await Task.yield()
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard accountSession.showsSignInCelebration else {
                SignInCelebrationTransitionDiagnostics.end(.celebrationShellPrewarm, signpostID: signpostID)
                return
            }
            allowsCelebrationShellPrewarm = true
            SignInCelebrationTransitionDiagnostics.mark("celebration_shell_prewarm_enabled")
            SignInCelebrationTransitionDiagnostics.end(.celebrationShellPrewarm, signpostID: signpostID)
        }
    }

    private func presentPendingFriendInviteIfNeeded() {
        guard accountSession.isSignedIn,
              accountSession.showsMainAppShell,
              pendingFriendInviteToken == nil
        else { return }
        if let token = GoDiveFriendInviteDeepLinkStore.shared.consumePendingToken() {
            pendingFriendInviteToken = token
        }
    }
}

private struct FriendInviteTokenBox: Identifiable {
    var id: String { token }
    let token: String
}

#Preview {
    AppSessionRootView()
        .environment(AccountSession.shared)
        .modelContainer(try! AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true))
}
