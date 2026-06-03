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
            await accountSession.restoreSession(modelContext: modelContext)
        }
    }
}

#Preview {
    AppSessionRootView()
        .environment(AccountSession.shared)
        .modelContainer(try! AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true))
}
