import SwiftData
import SwiftUI

/// Gates **`ContentView`** behind Sign in with Apple when no local profile session exists.
struct AppSessionRootView: View {
    @Environment(AccountSession.self) private var accountSession
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if accountSession.isRestoringSession {
                sessionRestorePlaceholder
            } else if accountSession.isSignedIn {
                ContentView()
                    .sheet(isPresented: displayNameCapturePresented) {
                        if let profile = accountSession.currentProfile {
                            ProfileDisplayNameCaptureSheet(profile: profile) {
                                accountSession.finishDisplayNameCapture()
                            }
                        }
                    }
            } else {
                SignInView()
            }
        }
        .task {
            await accountSession.restoreSession(modelContext: modelContext)
        }
    }

    private var displayNameCapturePresented: Binding<Bool> {
        Binding(
            get: { accountSession.isAwaitingDisplayNameCapture },
            set: { presented in
                if !presented {
                    accountSession.finishDisplayNameCapture()
                }
            }
        )
    }

    private var sessionRestorePlaceholder: some View {
        ZStack {
            AppTheme.Colors.screenBackgroundGradient
                .ignoresSafeArea()
            ProgressView()
                .tint(AppTheme.Colors.accent)
        }
        .accessibilityIdentifier("AppSession.Restoring")
    }
}

#Preview {
    AppSessionRootView()
        .environment(AccountSession.shared)
        .modelContainer(try! AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true))
}
