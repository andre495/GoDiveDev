import SwiftUI

/// Logbook **+** — three full-height tiles (non-scrolling).
struct LogbookAddActivityHubView: View {
    var body: some View {
        AppPage(title: LogbookAddActivityPresentation.hubPageTitle, showsBackButton: true) {
            GeometryReader { geometry in
                let spacing = AppTheme.Spacing.sm
                let tileCount = CGFloat(LogbookAddActivityPresentation.hubOptions.count)
                let totalSpacing = spacing * max(0, tileCount - 1)
                let tileHeight = max(0, (geometry.size.height - totalSpacing) / tileCount)

                VStack(spacing: spacing) {
                    ForEach(LogbookAddActivityPresentation.hubOptions) { option in
                        NavigationLink(value: option.route) {
                            LogbookAddActivityHubTile(option: option)
                                .frame(height: tileHeight)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(option.accessibilityIdentifier)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.md)
        }
        .accessibilityIdentifier("Logbook.AddActivityHub.Root")
    }
}

private struct LogbookAddActivityHubTile: View {
    let option: LogbookAddActivityPresentation.HubOption

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
            hubIconBadge

            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text(option.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(option.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: AppTheme.Spacing.sm)

            Image(systemName: "chevron.right")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.tabUnselected)
        }
        .padding(AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background { tileBackground }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(option.title). \(option.subtitle)")
    }

    private var hubIconBadge: some View {
        Image(systemName: option.systemImage)
            .font(.system(size: 28, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 64, height: 64)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.Colors.accent,
                                AppTheme.Colors.accent.opacity(0.78),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .shadow(color: AppTheme.Colors.accent.opacity(0.28), radius: 8, y: 4)
    }

    private var tileBackground: some View {
        RoundedRectangle(cornerRadius: LogbookActivityRowLayout.cardCornerRadius, style: .continuous)
            .fill(AppTheme.Colors.surfaceElevated)
            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }
}
