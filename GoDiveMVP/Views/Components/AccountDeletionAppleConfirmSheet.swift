import AuthenticationServices
import SwiftData
import SwiftUI

/// Second checkpoint after Settings “Are you sure?” — Apple Sign in supplies the authorization code for revoke + Firebase delete.
struct AccountDeletionAppleConfirmSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext

    let profile: UserProfile

    @State private var currentNonce: String?
    @State private var isDeleting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.Spacing.lg) {
                Text(AccountDeletionPresentation.appleConfirmMessage)
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.lg)

                SignInWithAppleButton(.continue) { request in
                    let nonce = GoDiveFirebaseAppleNonce.randomNonce()
                    currentNonce = nonce
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = GoDiveFirebaseAppleNonce.sha256Nonce(nonce)
                } onCompletion: { result in
                    handleAppleCompletion(result)
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 50)
                .disabled(isDeleting)
                .accessibilityIdentifier("Settings.DeleteAccount.AppleConfirm")
                .padding(.horizontal, AppTheme.Spacing.lg)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppTheme.Spacing.lg)
                }

                Spacer()
            }
            .padding(.top, AppTheme.Spacing.lg)
            .navigationTitle(AccountDeletionPresentation.appleConfirmTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AccountDeletionPresentation.cancelButtonTitle) {
                        dismiss()
                    }
                    .disabled(isDeleting)
                }
            }
            .overlay {
                if isDeleting {
                    ZStack {
                        Color.black.opacity(0.35).ignoresSafeArea()
                        ProgressView(AccountDeletionPresentation.progressTitle)
                            .padding(AppTheme.Spacing.lg)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .appSheetPresentationChrome()
        .interactiveDismissDisabled(isDeleting)
    }

    private func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        errorMessage = nil
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Could not read your Apple ID."
                return
            }
            guard let rawNonce = currentNonce, !rawNonce.isEmpty else {
                errorMessage = "Missing sign-in nonce. Try again."
                return
            }
            isDeleting = true
            Task { @MainActor in
                do {
                    try await GoDiveAccountDeletion.perform(
                        profile: profile,
                        appleCredential: credential,
                        rawNonce: rawNonce,
                        modelContext: modelContext
                    )
                    dismiss()
                } catch {
                    isDeleting = false
                    errorMessage = error.localizedDescription
                }
            }
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled {
                return
            }
            errorMessage = error.localizedDescription
        }
    }
}
