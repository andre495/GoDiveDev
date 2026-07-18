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
            Form {
                Section {
                    TextField("Your name", text: $nameText)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .name)
                        .listRowBackground(Color.clear)
                        .accessibilityIdentifier("ProfileEditSheet.NameField")
                } header: {
                    Text("Display name")
                }

                Section {
                    TextField("DAN member number (optional)", text: $danText)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .focused($focusedField, equals: .dan)
                        .listRowBackground(Color.clear)
                        .accessibilityIdentifier("ProfileEditSheet.DanField")
                } header: {
                    Text("Diver Medical Insurance (DAN)")
                }

                if let validationMessage {
                    Section {
                        Text(validationMessage)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Colors.tabUnselected)
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    AppGlassToolbarCancelButton(
                        action: { dismiss() },
                        accessibilityIdentifier: ProfilePresentation.editSheetCancelAccessibilityIdentifier
                    )
                }
                ToolbarItem(placement: .confirmationAction) {
                    AppGlassProminentDoneButton(
                        action: saveProfile,
                        accessibilityIdentifier: ProfilePresentation.editSheetDoneAccessibilityIdentifier
                    )
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
            AccountSession.shared.pushFirestoreSocialProfileEdits(uploadPhoto: false)
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
