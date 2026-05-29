import SwiftData
import SwiftUI

/// Edit display name and DAN insurance on **Profile**.
struct ProfileEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var profile: UserProfile

    @State private var nameText = ""
    @State private var danText = ""
    @State private var validationMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name
        case dan
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text("Display name")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)

                    TextField("Your name", text: $nameText)
                        .font(.body)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .name)
                        .padding(AppTheme.Spacing.md)
                        .background(AppTheme.Colors.surfaceMuted.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityIdentifier("ProfileEditSheet.NameField")
                }

                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text("Diver Medical Insurance (DAN)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)

                    TextField("DAN member number (optional)", text: $danText)
                        .font(.body)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .focused($focusedField, equals: .dan)
                        .padding(AppTheme.Spacing.md)
                        .background(AppTheme.Colors.surfaceMuted.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityIdentifier("ProfileEditSheet.DanField")
                }

                if let validationMessage {
                    Text(validationMessage)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.tabUnselected)
                }

                Spacer(minLength: 0)
            }
            .padding(AppTheme.Spacing.lg)
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("ProfileEditSheet.Cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProfile()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("ProfileEditSheet.Save")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    if focusedField != nil {
                        Spacer()
                        Button("Done") {
                            focusedField = nil
                        }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.tabSelected)
                    }
                }
            }
            .onAppear {
                nameText = profile.displayName
                danText = profile.danInsuranceNumber ?? ""
            }
        }
        .profileEditSheetPresentation()
        .accessibilityIdentifier("ProfileEditSheet.Sheet")
    }

    private func saveProfile() {
        validationMessage = nil
        focusedField = nil

        let trimmedName = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            validationMessage = "Enter a display name."
            return
        }

        profile.displayName = trimmedName
        if profile.displayName != UserProfileStore.defaultDisplayName {
            UserProfileStore.cacheDisplayName(
                profile.displayName,
                forAppleUserIdentifier: profile.appleUserIdentifier
            )
        }
        profile.danInsuranceNumber = UserProfileStore.sanitizedDanInsuranceNumber(danText)

        do {
            try modelContext.save()
            requestPhotoLibraryAccessForAutoUploadIfNeeded()
            dismiss()
        } catch {
            validationMessage = "Could not save. Try again."
        }
    }

    /// Profile setup is a natural moment to ask for Photos access when auto-upload is on (prompts only once).
    private func requestPhotoLibraryAccessForAutoUploadIfNeeded() {
        Task { @MainActor in
            guard DiveLibraryMediaAutoAttach.shouldRequestPhotoAccessForAutoUpload(
                autoUploadEnabled: AppUserSettings.autoUploadMediaToActivities,
                authorizationResolved: DiveLibraryMediaAutoAttach.hasResolvedPhotoLibraryAuthorization
            ) else { return }
            _ = await DiveLibraryMediaAutoAttach.requestPhotoLibraryReadAccess()
        }
    }
}
