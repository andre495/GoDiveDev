import SwiftUI

/// Modal scrim + card while dive **Media** items import from the photo picker.
struct DiveMediaImportProgressOverlay: View {
    let state: DiveMediaImportOverlayState
    var onDismiss: (() -> Void)?

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                switch state {
                case .hidden:
                    EmptyView()
                case .importing(let completed, let total, let stage):
                    Text("Adding media")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    ProgressView(
                        value: DiveMediaImportProgressPresentation.progressFraction(
                            completed: completed,
                            total: total
                        ),
                        total: 1.0
                    )
                    .tint(AppTheme.Colors.accent)
                    Text(DiveMediaImportProgressPresentation.countLabel(completed: completed, total: total))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.linear(duration: 0.08), value: completed)
                    Text(stage)
                        .font(.body)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                case .failed(let message):
                    Text("Could not add media")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text(message)
                        .font(.body)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Dismiss") {
                        onDismiss?()
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.tabSelected)
                    .buttonStyle(.plain)
                    .padding(.top, AppTheme.Spacing.sm)
                    .accessibilityIdentifier("DiveMediaImport.Dismiss")
                }
            }
            .padding(AppTheme.Spacing.lg)
            .frame(maxWidth: 320, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.Colors.surfaceElevated)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.Colors.tabUnselected.opacity(0.15), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.28), radius: 14, y: 8)
            .accessibilityAddTraits(.isModal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("DiveMediaImport.Overlay")
    }
}
