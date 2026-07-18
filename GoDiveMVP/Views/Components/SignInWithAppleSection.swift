import AuthenticationServices
import SwiftData
import SwiftUI

/// Shared Sign in with Apple control + error line (sign-in screen and logged-out onboarding).
struct SignInWithAppleSection: View {
    @Environment(AccountSession.self) private var accountSession
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext

    var buttonAccessibilityIdentifier = "SignIn.AppleButton"

    @State private var signInErrorMessage: String?
    @State private var currentNonce: String?

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            SignInWithAppleButton(.continue) { request in
                let nonce = GoDiveFirebaseAppleNonce.randomNonce()
                currentNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = GoDiveFirebaseAppleNonce.sha256Nonce(nonce)
            } onCompletion: { result in
                handleSignInCompletion(result)
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 50)
            .accessibilityIdentifier(buttonAccessibilityIdentifier)

            if let signInErrorMessage {
                Text(signInErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
                    .multilineTextAlignment(.center)
            }
        }
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
                try accountSession.completeSignIn(
                    credential: credential,
                    rawNonce: currentNonce,
                    modelContext: modelContext
                )
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
