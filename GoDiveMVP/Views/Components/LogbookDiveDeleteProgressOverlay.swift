import SwiftUI

/// Modal scrim + card with a single progress bar while an activity delete runs (no caption).
struct ActivityDeleteProgressOverlay: View {
    let progress: Double
    var accessibilityLabel: String = "Deleting activity"

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .accessibilityHidden(true)

            ProgressView(value: min(max(progress, 0), 1), total: 1.0)
                .tint(AppTheme.Colors.accent)
                .padding(AppTheme.Spacing.lg)
                .frame(maxWidth: 280)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.Colors.surfaceElevated)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.Colors.tabUnselected.opacity(0.15), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel)
                .accessibilityValue("\(Int(progress * 100)) percent")
                .accessibilityAddTraits(.updatesFrequently)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityAddTraits(.isModal)
    }
}

/// Legacy name — logbook delete removed; kept for any stale references.
typealias LogbookDiveDeleteProgressOverlay = ActivityDeleteProgressOverlay

#Preview {
    ZStack {
        AppTheme.Colors.screenBackgroundGradient.ignoresSafeArea()
        ActivityDeleteProgressOverlay(progress: 0.45, accessibilityLabel: "Deleting dive")
    }
}
