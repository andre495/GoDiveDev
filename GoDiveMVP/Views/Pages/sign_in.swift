import AuthenticationServices
import SwiftData
import SwiftUI

struct SignInView: View {
    private enum Layout {
        /// Full-screen veil over **`WaterBubbleBackground`** so copy stays readable.
        static let bubbleScrimOpacity: CGFloat = 0.42
    }

    @Environment(AccountSession.self) private var accountSession
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext

    @State private var signInErrorMessage: String?

    var body: some View {
        AppHeaderlessPage {
            ZStack {
                if !GoDiveUITestConfiguration.isActive {
                    WaterBubbleBackground()
                    AppTheme.Colors.surface
                        .opacity(Layout.bubbleScrimOpacity)
                        .ignoresSafeArea()
                }

                VStack(spacing: AppTheme.Spacing.lg) {
                    Spacer(minLength: AppTheme.Spacing.lg)

                    VStack(spacing: AppTheme.Spacing.md) {
                        VStack(spacing: AppTheme.Spacing.lg) {
                            Image("GoDiveLogoPin")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 128, height: 128)
                                .accessibilityHidden(true)
                                .accessibilityIdentifier("SignIn.Logo")

                            Text("GoDive")
                                .font(.largeTitle.weight(.bold))
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                        }

                        Text("Log every dive. Explore marine life. Connect with buddies.")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppTheme.Spacing.lg)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        "GoDive. Log every dive. Explore marine life. Connect with buddies."
                    )

                    SignInWithAppleButton(.continue) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        handleSignInCompletion(result)
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 50)
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .accessibilityIdentifier("SignIn.AppleButton")

                    if let signInErrorMessage {
                        Text(signInErrorMessage)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Colors.tabUnselected)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppTheme.Spacing.lg)
                    }

                    Spacer()
                }
            }
        }
        .accessibilityIdentifier("SignIn.Root")
    }

    private func handleSignInCompletion(_ result: Result<ASAuthorization, Error>) {
        signInErrorMessage = nil
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                signInErrorMessage = "Could not read your Apple ID."
                return
            }
            do {
                try accountSession.completeSignIn(credential: credential, modelContext: modelContext)
            } catch {
                signInErrorMessage = "Could not save your profile. Try again."
                accountSession.recordSignInFailure(error)
            }
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled {
                return
            }
            signInErrorMessage = "Sign in was interrupted. Try again."
            accountSession.recordSignInFailure(error)
        }
    }
}

#Preview {
    SignInView()
        .environment(AccountSession.shared)
        .modelContainer(try! AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true))
}
