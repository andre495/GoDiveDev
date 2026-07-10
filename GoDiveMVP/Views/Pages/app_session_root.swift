import SwiftData
import SwiftUI

/// Gates **`ContentView`** behind Sign in with Apple when no local profile session exists.
struct AppSessionRootView: View {
    @Environment(AccountSession.self) private var accountSession
    @Environment(\.modelContext) private var modelContext

    /// Defers hidden **`ContentView`** mount until after the celebration first frame paints.
    @State private var allowsCelebrationShellPrewarm = false

    private var showsBootstrapOverlay: Bool {
        AppSessionBootstrapPresentation.showsLaunchOverlay(
            isRestoringSession: accountSession.isRestoringSession
        )
    }

    private var shouldMountMainAppShellUnderlay: Bool {
        AccountSessionMainShellPresentation.shouldMountMainAppShellUnderlay(
            isSignedIn: accountSession.isSignedIn,
            showsNewAccountWelcome: accountSession.showsNewAccountWelcome,
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
        .animation(.easeInOut(duration: 0.35), value: accountSession.showsPostSignUpProfileSetup)
        .animation(.easeInOut(duration: 0.35), value: accountSession.showsPostSignUpPermissions)
        .animation(.easeInOut(duration: 0.35), value: accountSession.showsPostSignUpImportOffer)
        .animation(.easeInOut(duration: 0.35), value: accountSession.showsPostSignUpOnboardingImport)
        .animation(nil, value: accountSession.showsSignInCelebration)
        .animation(.easeInOut(duration: 0.25), value: allowsCelebrationShellPrewarm)
        .task {
            await accountSession.restoreSession(modelContext: modelContext)
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
        if accountSession.showsPostSignUpProfileSetup {
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
}

#Preview {
    AppSessionRootView()
        .environment(AccountSession.shared)
        .modelContainer(try! AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true))
}
