import SwiftUI

/// Full-screen scrim + progress card while a dive file import runs.
struct DiveImportProgressOverlayView: View {
    @Binding var overlay: DiveImportOverlayState

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                switch overlay {
                case .hidden:
                    EmptyView()
                case .importing(let milestone, let fraction):
                    ProgressView(value: fraction, total: 1.0)
                        .tint(AppTheme.Colors.accent)
                        .animation(.easeInOut(duration: 0.2), value: fraction)
                    Text(milestone.label)
                        .font(.body)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.2), value: milestone)
                case .failed(let message):
                    Text("Import failed")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text(message)
                        .font(.body)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Dismiss") {
                        overlay = .hidden
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.tabSelected)
                    .buttonStyle(.plain)
                    .padding(.top, AppTheme.Spacing.sm)
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
    }
}
