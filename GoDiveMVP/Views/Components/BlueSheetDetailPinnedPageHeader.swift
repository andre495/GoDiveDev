import SwiftUI

/// Non-scrolling content-area title row for blue-sheet detail pagers.
struct BlueSheetDetailPinnedPageHeader<Trailing: View>: View {
    let title: String
    var accessibilityIdentifier: String?
    @ViewBuilder var trailing: () -> Trailing

    init(
        title: String,
        accessibilityIdentifier: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.accessibilityIdentifier = accessibilityIdentifier
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(accessibilityIdentifier ?? "")

            trailing()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, BlueSheetDetailPagerPresentation.pinnedPageHeaderBottomSpacing)
    }
}

extension BlueSheetDetailPinnedPageHeader where Trailing == EmptyView {
    init(title: String, accessibilityIdentifier: String? = nil) {
        self.init(title: title, accessibilityIdentifier: accessibilityIdentifier) {
            EmptyView()
        }
    }
}
