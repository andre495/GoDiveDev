import SwiftData
import SwiftUI

/// Gates **`ContentView`** behind Sign in with Apple when no local profile session exists.
struct AppSessionRootView: View {
    @Environment(AccountSession.self) private var accountSession
    @Environment(\.modelContext) private var modelContext

    @State private var isHomeMediaWarmupComplete = false
    @State private var hasCompletedInitialBootstrap = false

    private var showsBootstrapOverlay: Bool {
        AppSessionBootstrapPresentation.showsLaunchOverlay(
            isRestoringSession: accountSession.isRestoringSession,
            isSignedIn: accountSession.isSignedIn,
            isHomeMediaWarmupComplete: isHomeMediaWarmupComplete
        )
    }

    var body: some View {
        ZStack {
            Group {
                if accountSession.isSignedIn {
                    ContentView()
                } else if !accountSession.isRestoringSession {
                    SignInView()
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
        .task {
            await runInitialSessionBootstrap()
            hasCompletedInitialBootstrap = true
        }
        .onChange(of: accountSession.isSignedIn) { _, isSignedIn in
            guard hasCompletedInitialBootstrap else { return }
            if isSignedIn {
                Task { await warmHomeMediaForSignedInUser() }
            } else {
                isHomeMediaWarmupComplete = true
            }
        }
    }

    private func runInitialSessionBootstrap() async {
        await accountSession.restoreSession(modelContext: modelContext)
        await warmHomeMediaForSignedInUser()
    }

    /// Preloads today's featured carousel picks before revealing Home (signed-in bootstrap only).
    private func warmHomeMediaForSignedInUser() async {
        guard accountSession.isSignedIn,
              let ownerProfileID = accountSession.currentProfile?.id else {
            isHomeMediaWarmupComplete = true
            return
        }

        isHomeMediaWarmupComplete = false
        await HomeMediaHighlightWarmup.warmFromStore(
            modelContext: modelContext,
            ownerProfileID: ownerProfileID
        )
        isHomeMediaWarmupComplete = true
    }
}

#Preview {
    AppSessionRootView()
        .environment(AccountSession.shared)
        .modelContainer(try! AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true))
}
