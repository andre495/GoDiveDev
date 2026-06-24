import SwiftUI

/// Garmin FIT or UDDF import options on a pushed **AppPage** before the file picker.
struct DiveFileImportOptionsView: View {
    let mode: DiveFileImporterPresentation.PickerMode
    @Binding var createDiveSitesFromImport: Bool
    @Binding var attachMediaFromPhotoLibrary: Bool
    let onChooseFile: () -> Void
    var onOpenMacDiveGuide: (() -> Void)?

    private var isUddf: Bool { mode.isUddf }
    private var idPrefix: String { DiveFileImportOptionsPresentation.accessibilityPrefix(for: mode) }

    var body: some View {
        AppPage(
            title: DiveFileImportOptionsPresentation.pageTitle(for: mode),
            showsBackButton: true
        ) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                Text(DiveFileImportOptionsPresentation.intro(for: mode))
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if isUddf, let onOpenMacDiveGuide {
                    macDiveImportButton(action: onOpenMacDiveGuide)
                }

                Toggle(isOn: $createDiveSitesFromImport) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Create dive sites from import")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Text("Adds local-only catalog sites for unmatched import names. OpenDiveMap reference matching always runs when a dive has a site name or GPS.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(AppTheme.Colors.accent)
                .accessibilityIdentifier("\(idPrefix).CreateSitesToggle")

                Toggle(isOn: $attachMediaFromPhotoLibrary) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(SettingsPresentation.BulkUddfImport.attachMediaTitle)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Text(SettingsPresentation.BulkUddfImport.attachMediaSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(AppTheme.Colors.accent)
                .accessibilityIdentifier("\(idPrefix).AttachMediaToggle")

                Spacer(minLength: 0)

                Button(DiveFileImportOptionsPresentation.chooseFileTitle(for: mode)) {
                    onChooseFile()
                }
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Spacing.md)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.Colors.accent)
                }
                .foregroundStyle(.white)
                .accessibilityIdentifier("\(idPrefix).ChooseFile")
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .hidesBottomTabBarWhenPushed()
        .onAppear {
            attachMediaFromPhotoLibrary = AppUserSettings.autoUploadMediaToActivities
        }
    }

    private func macDiveImportButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: "laptopcomputer.and.iphone")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.accent)
                    .frame(width: 44, height: 44)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppTheme.Colors.accent.opacity(0.12))
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text("MacDive Import")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text("Step-by-step export guide before you choose your file.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: AppTheme.Spacing.sm)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
            }
            .padding(AppTheme.Spacing.md)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.Colors.surfaceElevated)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.Colors.accent.opacity(0.22), lineWidth: 1)
                    }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(AddActivityCardButtonStyle())
        .accessibilityIdentifier("ActivityUpload.BulkUddf.MacDiveImport")
    }
}

#Preview("UDDF") {
    NavigationStack {
        DiveFileImportOptionsView(
            mode: .uddf,
            createDiveSitesFromImport: .constant(true),
            attachMediaFromPhotoLibrary: .constant(false),
            onChooseFile: {},
            onOpenMacDiveGuide: {}
        )
    }
}
