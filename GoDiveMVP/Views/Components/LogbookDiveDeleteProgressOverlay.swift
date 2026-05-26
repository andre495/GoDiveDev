import SwiftUI

/// Modal scrim + card with a single progress bar while a logbook dive delete runs (no caption).
struct LogbookDiveDeleteProgressOverlay: View {
    let progress: Double

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
                .accessibilityLabel("Deleting dive")
                .accessibilityValue("\(Int(progress * 100)) percent")
                .accessibilityAddTraits(.updatesFrequently)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityAddTraits(.isModal)
    }
}

#Preview {
    ZStack {
        AppTheme.Colors.screenBackgroundGradient.ignoresSafeArea()
        LogbookDiveDeleteProgressOverlay(progress: 0.45)
    }
}
