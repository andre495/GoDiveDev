import SwiftUI

/// Modal progress while **Settings → Auto-upload media** scans the library for existing dives.
struct DiveLibraryMediaBackfillProgressOverlay: View {
    let state: DiveLibraryMediaBackfillOverlayState
    let onDismiss: () -> Void
    var onCancel: (() -> Void)?

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .accessibilityHidden(true)

            card
                .accessibilityAddTraits(.isModal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("DiveLibraryMediaBackfill.Overlay")
    }

    @ViewBuilder
    private var card: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            switch state {
            case .hidden:
                EmptyView()
            case .running(let completed, let total, let stage):
                Text(DiveLibraryMediaAutoAttachPresentation.overlayTitle)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                ProgressView(
                    value: DiveLibraryMediaAutoAttachPresentation.progressFraction(
                        completed: completed,
                        total: total
                    ),
                    total: 1.0
                )
                .tint(AppTheme.Colors.accent)
                if total > 0 {
                    Text(DiveLibraryMediaAutoAttachPresentation.countLabel(completed: completed, total: total))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.linear(duration: 0.08), value: completed)
                }
                Text(stage)
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if let onCancel {
                    Button("Cancel", action: onCancel)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.tabSelected)
                        .buttonStyle(.plain)
                        .padding(.top, AppTheme.Spacing.sm)
                        .accessibilityIdentifier("DiveLibraryMediaBackfill.Cancel")
                }
            case .finished(let outcome):
                Text(
                    outcome.authorizationDenied
                        ? DiveLibraryMediaAutoAttachPresentation.authorizationDeniedTitle
                        : DiveLibraryMediaAutoAttachPresentation.finishedTitle
                )
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                Text(DiveLibraryMediaAutoAttachPresentation.finishedMessage(for: outcome))
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                dismissButton
            case .cancelled:
                Text(DiveLibraryMediaAutoAttachPresentation.overlayTitle)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text(DiveLibraryMediaAutoAttachPresentation.cancelledMessage)
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                dismissButton
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
    }

    private var dismissButton: some View {
        Button("Dismiss", action: onDismiss)
            .font(.body.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.tabSelected)
            .buttonStyle(.plain)
            .padding(.top, AppTheme.Spacing.sm)
            .accessibilityIdentifier("DiveLibraryMediaBackfill.Dismiss")
    }
}
