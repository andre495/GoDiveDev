import SwiftUI

/// Read-only Settings row — title, dynamic subtitle, and detail alert (iCloud dive log status).
struct SettingsStatusRow: View {
    let title: String
    let subtitle: String
    let infoMessage: String
    let detailMessage: String

    @State private var showsInfo = false
    @State private var showsDetail = false

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            Button {
                showsDetail = true
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                }
            }
            .buttonStyle(.plain)

            settingsInfoButton
        }
        .alert(title, isPresented: $showsInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(infoMessage)
        }
        .alert(title, isPresented: $showsDetail) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(detailMessage)
        }
        .accessibilityElement(children: .contain)
    }

    private var settingsInfoButton: some View {
        Button {
            showsInfo = true
        } label: {
            Image(systemName: "info.circle")
                .font(.body)
                .foregroundStyle(AppTheme.Colors.accent)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(SettingsPresentation.infoAccessibilityLabel(forSettingTitle: title))
    }
}
