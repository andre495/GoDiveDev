import SwiftData
import SwiftUI

/// Shown when Sign in with Apple did not supply a name (Apple only sends **`fullName`** once per app).
struct ProfileDisplayNameCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var profile: UserProfile
    var onSaved: () -> Void

    @State private var nameText = ""
    @State private var validationMessage: String?
    @FocusState private var isNameFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                Text("What should we call you?")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text("Apple didn’t share your name this time. Add one so it appears on your profile.")
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                TextField("Your name", text: $nameText)
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($isNameFocused)
                    .padding(AppTheme.Spacing.md)
                    .background(AppTheme.Colors.surfaceMuted.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityIdentifier("ProfileDisplayNameCapture.NameField")

                if let validationMessage {
                    Text(validationMessage)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.tabUnselected)
                }

                Spacer()

                Button("Continue") {
                    saveName()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.Colors.accent)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("ProfileDisplayNameCapture.Continue")
            }
            .padding(AppTheme.Spacing.lg)
            .navigationTitle("Your name")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled()
            .onAppear {
                isNameFocused = true
            }
        }
        .accessibilityIdentifier("ProfileDisplayNameCapture.Sheet")
    }

    private func saveName() {
        validationMessage = nil
        guard let sanitized = UserProfileStore.sanitizedUserEnteredDisplayName(nameText) else {
            validationMessage = "Enter your name to continue."
            return
        }
        profile.displayName = sanitized
        UserProfileStore.cacheDisplayName(sanitized, forAppleUserIdentifier: profile.appleUserIdentifier)
        do {
            try modelContext.save()
            onSaved()
            dismiss()
        } catch {
            validationMessage = "Could not save. Try again."
        }
    }
}
