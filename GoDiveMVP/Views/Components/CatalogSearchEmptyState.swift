import SwiftUI

/// Empty state when a catalog list search filters out every row.
struct CatalogSearchEmptyState: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer(minLength: AppTheme.Spacing.lg)

            Image(systemName: "magnifyingglass")
                .font(.system(size: 44))
                .foregroundStyle(AppTheme.Colors.accent.opacity(0.85))

            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.lg)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
