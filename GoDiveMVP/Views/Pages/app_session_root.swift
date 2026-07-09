import SwiftData
import SwiftUI

/// Gates **`ContentView`** behind Sign in with Apple when no local profile session exists.
struct AppSessionRootView: View {
    @Environment(AccountSession.self) private var accountSession
    @Environment(\.modelContext) private var modelContext

    private var showsBootstrapOverlay: Bool {
        AppSessionBootstrapPresentation.showsLaunchOverlay(
            isRestoringSession: accountSession.isRestoringSession
        )
    }

    var body: some View {
        ZStack {
            Group {
                if accountSession.isSignedIn {
                    if accountSession.showsPostSignUpProfileSetup {
                        PostSignUpProfileSetupView {
                            accountSession.completePostSignUpProfileSetup()
                        }
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
                    } else {
                        ContentView()
                            .transition(homeEntryTransition)
                            .onAppear {
                                guard accountSession.prefersHomeRevealFromBottom else { return }
                                Task { @MainActor in
                                    try? await Task.sleep(
                                        nanoseconds: UInt64(
                                            SignInCelebrationPresentation.homeRevealSpringResponse * 1_000_000_000
                                        )
                                    )
                                    accountSession.acknowledgeHomeRevealFromBottom()
                                }
                            }
                    }
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
        .animation(
            .spring(
                response: SignInCelebrationPresentation.homeRevealSpringResponse,
                dampingFraction: SignInCelebrationPresentation.homeRevealSpringDamping
            ),
            value: accountSession.showsSignInCelebration
        )
        .animation(.easeInOut(duration: 0.2), value: accountSession.prefersHomeRevealFromBottom)
        .task {
            await accountSession.restoreSession(modelContext: modelContext)
        }
    }

    private var homeEntryTransition: AnyTransition {
        if accountSession.prefersHomeRevealFromBottom {
            return .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .opacity
            )
        }
        return .opacity
    }
}

#Preview {
    AppSessionRootView()
        .environment(AccountSession.shared)
        .modelContainer(try! AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true))
}
