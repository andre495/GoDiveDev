#if DEBUG
import SwiftData
import SwiftUI

/// Small button for emulator test sign-in, shown only when the Firebase Auth emulator is active.
struct EmulatorTestSignInButton: View {
    @Environment(AccountSession.self) private var accountSession
    @Environment(\.modelContext) private var modelContext

    @State private var email = ""
    @State private var isSigningIn = false
    @State private var errorMessage: String?
    @State private var showsEmailEntry = false

    var body: some View {
        if GoDiveEmulatorTestSignIn.isAvailable {
            VStack(spacing: AppTheme.Spacing.sm) {
                if showsEmailEntry {
                    emailEntryView
                } else {
                    toggleButton
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
        }
    }

    private var toggleButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showsEmailEntry = true
            }
        } label: {
            HStack(spacing: AppTheme.Spacing.xs) {
                Image(systemName: "flask")
                Text("Emulator test sign-in")
            }
            .font(.footnote)
            .foregroundStyle(AppTheme.Colors.tabUnselected)
        }
        .accessibilityIdentifier("SignIn.EmulatorTestButton")
    }

    private var emailEntryView: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            HStack(spacing: AppTheme.Spacing.sm) {
                TextField("test@example.com", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .disabled(isSigningIn)
                    .accessibilityIdentifier("SignIn.EmulatorEmailField")

                Button {
                    Task { await signIn() }
                } label: {
                    if isSigningIn {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                    } else {
                        Text("Go")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSigningIn)
                .accessibilityIdentifier("SignIn.EmulatorSignInButton")
            }

            Button("Cancel") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showsEmailEntry = false
                    email = ""
                    errorMessage = nil
                }
            }
            .font(.footnote)
            .foregroundStyle(AppTheme.Colors.tabUnselected)
        }
    }

    private func signIn() async {
        guard GoDiveEmulatorTestSignIn.isAvailable else {
            errorMessage = "Emulator not available"
            return
        }

        isSigningIn = true
        errorMessage = nil

        do {
            try await GoDiveEmulatorTestSignIn.signIn(email: email, modelContext: modelContext)
        } catch {
            errorMessage = error.localizedDescription
        }

        isSigningIn = false
    }
}

#Preview {
    VStack {
        Spacer()
        EmulatorTestSignInButton()
            .environment(AccountSession.shared)
            .modelContainer(try! AppSwiftDataSchema.makeContainer(isStoredInMemoryOnly: true))
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black.opacity(0.9))
}
#endif
