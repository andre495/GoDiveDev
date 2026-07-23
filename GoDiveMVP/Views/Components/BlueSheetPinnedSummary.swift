import SwiftUI

/// Shared pinned identity block for blue-sheet **detail** pages (accent → title → subtitle).
///
/// Pages supply text slots and optional **`topRow`** / **`leadingAccessory`** (buddy avatar inset, dive-site stars).
struct BlueSheetPinnedSummary<TopRow: View, LeadingAccessory: View>: View {
    var accent: String?
    var accentColor: Color = AppTheme.Colors.accent
    var accentFont: Font = BlueSheetPinnedSummaryPresentation.accentFont
    var accentAccessibilityIdentifier: String?

    let title: String
    var titleFont: Font = BlueSheetPinnedSummaryPresentation.titleFont
    var titleColor: Color = AppTheme.Colors.textPrimary
    var titleLineLimit: Int?
    var titleMinimumScaleFactor: CGFloat = 1
    var titleAccessibilityIdentifier: String?

    var subtitle: String?
    var subtitleFont: Font = BlueSheetPinnedSummaryPresentation.subtitleFont
    var subtitleColor: Color = AppTheme.Colors.secondaryText
    var subtitleLineLimit: Int = 2
    var subtitleAccessibilityIdentifier: String?

    var accessibilityIdentifier: String?

    var usesLeadingAccessoryLayout: Bool = false
    var contentVerticalOffset: CGFloat = 0
    /// Prefer **`BlueSheetDetailPagePinnedSummaryPresentation.bodyBottomPadding`** on detail pages — avoid one-off bottom gaps.
    var extraBottomPadding: CGFloat = 0

    @ViewBuilder var topRow: () -> TopRow
    @ViewBuilder var leadingAccessory: () -> LeadingAccessory

    var body: some View {
        Group {
            if usesLeadingAccessoryLayout {
                leadingAccessoryLayout
            } else {
                standardLayout
            }
        }
        .accessibilityElement(children: .contain)
        .optionalAccessibilityIdentifier(accessibilityIdentifier)
    }

    private var standardLayout: some View {
        VStack(alignment: .leading, spacing: BlueSheetPinnedSummaryPresentation.rowSpacing) {
            topRow()

            if let accent, !accent.isEmpty {
                Text(accent)
                    .font(accentFont)
                    .foregroundStyle(accentColor)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .optionalAccessibilityIdentifier(accentAccessibilityIdentifier)
            }

            Text(title)
                .font(titleFont)
                .foregroundStyle(titleColor)
                .multilineTextAlignment(.leading)
                .lineLimit(titleLineLimit)
                .minimumScaleFactor(titleMinimumScaleFactor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
                .optionalAccessibilityIdentifier(titleAccessibilityIdentifier)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(subtitleFont)
                    .foregroundStyle(subtitleColor)
                    .multilineTextAlignment(.leading)
                    .lineLimit(subtitleLineLimit)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .optionalAccessibilityIdentifier(subtitleAccessibilityIdentifier)
            }
        }
        .padding(.bottom, extraBottomPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var leadingAccessoryLayout: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
            leadingAccessory()

            VStack(alignment: .leading, spacing: BlueSheetPinnedSummaryPresentation.rowSpacing) {
                Text(title)
                    .font(titleFont)
                    .foregroundStyle(titleColor)
                    .multilineTextAlignment(.leading)
                    .lineLimit(titleLineLimit)
                    .minimumScaleFactor(titleMinimumScaleFactor)
                    .accessibilityAddTraits(.isHeader)
                    .optionalAccessibilityIdentifier(titleAccessibilityIdentifier)

                if let accent, !accent.isEmpty {
                    Text(accent)
                        .font(accentFont)
                        .foregroundStyle(accentColor)
                        .multilineTextAlignment(.leading)
                        .optionalAccessibilityIdentifier(accentAccessibilityIdentifier)
                }
            }
            .offset(y: contentVerticalOffset)

            Spacer(minLength: 0)
        }
        .padding(.bottom, extraBottomPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension BlueSheetPinnedSummary where TopRow == EmptyView, LeadingAccessory == EmptyView {
    init(
        accent: String? = nil,
        accentColor: Color = AppTheme.Colors.accent,
        accentFont: Font = BlueSheetPinnedSummaryPresentation.accentFont,
        accentAccessibilityIdentifier: String? = nil,
        title: String,
        titleFont: Font = BlueSheetPinnedSummaryPresentation.titleFont,
        titleColor: Color = AppTheme.Colors.textPrimary,
        titleLineLimit: Int? = nil,
        titleMinimumScaleFactor: CGFloat = 1,
        titleAccessibilityIdentifier: String? = nil,
        subtitle: String? = nil,
        subtitleFont: Font = BlueSheetPinnedSummaryPresentation.subtitleFont,
        subtitleColor: Color = AppTheme.Colors.secondaryText,
        subtitleLineLimit: Int = 2,
        subtitleAccessibilityIdentifier: String? = nil,
        accessibilityIdentifier: String? = nil,
        usesLeadingAccessoryLayout: Bool = false,
        contentVerticalOffset: CGFloat = 0,
        extraBottomPadding: CGFloat = 0
    ) {
        self.accent = accent
        self.accentColor = accentColor
        self.accentFont = accentFont
        self.accentAccessibilityIdentifier = accentAccessibilityIdentifier
        self.title = title
        self.titleFont = titleFont
        self.titleColor = titleColor
        self.titleLineLimit = titleLineLimit
        self.titleMinimumScaleFactor = titleMinimumScaleFactor
        self.titleAccessibilityIdentifier = titleAccessibilityIdentifier
        self.subtitle = subtitle
        self.subtitleFont = subtitleFont
        self.subtitleColor = subtitleColor
        self.subtitleLineLimit = subtitleLineLimit
        self.subtitleAccessibilityIdentifier = subtitleAccessibilityIdentifier
        self.accessibilityIdentifier = accessibilityIdentifier
        self.usesLeadingAccessoryLayout = usesLeadingAccessoryLayout
        self.contentVerticalOffset = contentVerticalOffset
        self.extraBottomPadding = extraBottomPadding
        self.topRow = { EmptyView() }
        self.leadingAccessory = { EmptyView() }
    }
}

extension BlueSheetPinnedSummary where TopRow == EmptyView {
    init(
        accent: String? = nil,
        accentColor: Color = AppTheme.Colors.accent,
        accentFont: Font = BlueSheetPinnedSummaryPresentation.accentFont,
        accentAccessibilityIdentifier: String? = nil,
        title: String,
        titleFont: Font = BlueSheetPinnedSummaryPresentation.titleFont,
        titleColor: Color = AppTheme.Colors.textPrimary,
        titleLineLimit: Int? = nil,
        titleMinimumScaleFactor: CGFloat = 1,
        titleAccessibilityIdentifier: String? = nil,
        subtitle: String? = nil,
        subtitleFont: Font = BlueSheetPinnedSummaryPresentation.subtitleFont,
        subtitleColor: Color = AppTheme.Colors.secondaryText,
        subtitleLineLimit: Int = 2,
        subtitleAccessibilityIdentifier: String? = nil,
        accessibilityIdentifier: String? = nil,
        usesLeadingAccessoryLayout: Bool = false,
        contentVerticalOffset: CGFloat = 0,
        extraBottomPadding: CGFloat = 0,
        @ViewBuilder leadingAccessory: @escaping () -> LeadingAccessory
    ) {
        self.accent = accent
        self.accentColor = accentColor
        self.accentFont = accentFont
        self.accentAccessibilityIdentifier = accentAccessibilityIdentifier
        self.title = title
        self.titleFont = titleFont
        self.titleColor = titleColor
        self.titleLineLimit = titleLineLimit
        self.titleMinimumScaleFactor = titleMinimumScaleFactor
        self.titleAccessibilityIdentifier = titleAccessibilityIdentifier
        self.subtitle = subtitle
        self.subtitleFont = subtitleFont
        self.subtitleColor = subtitleColor
        self.subtitleLineLimit = subtitleLineLimit
        self.subtitleAccessibilityIdentifier = subtitleAccessibilityIdentifier
        self.accessibilityIdentifier = accessibilityIdentifier
        self.usesLeadingAccessoryLayout = usesLeadingAccessoryLayout
        self.contentVerticalOffset = contentVerticalOffset
        self.extraBottomPadding = extraBottomPadding
        self.topRow = { EmptyView() }
        self.leadingAccessory = leadingAccessory
    }
}

extension BlueSheetPinnedSummary where LeadingAccessory == EmptyView {
    init(
        accent: String? = nil,
        accentColor: Color = AppTheme.Colors.accent,
        accentFont: Font = BlueSheetPinnedSummaryPresentation.accentFont,
        accentAccessibilityIdentifier: String? = nil,
        title: String,
        titleFont: Font = BlueSheetPinnedSummaryPresentation.titleFont,
        titleColor: Color = AppTheme.Colors.textPrimary,
        titleLineLimit: Int? = nil,
        titleMinimumScaleFactor: CGFloat = 1,
        titleAccessibilityIdentifier: String? = nil,
        subtitle: String? = nil,
        subtitleFont: Font = BlueSheetPinnedSummaryPresentation.subtitleFont,
        subtitleColor: Color = AppTheme.Colors.secondaryText,
        subtitleLineLimit: Int = 2,
        subtitleAccessibilityIdentifier: String? = nil,
        accessibilityIdentifier: String? = nil,
        usesLeadingAccessoryLayout: Bool = false,
        contentVerticalOffset: CGFloat = 0,
        extraBottomPadding: CGFloat = 0,
        @ViewBuilder topRow: @escaping () -> TopRow
    ) {
        self.accent = accent
        self.accentColor = accentColor
        self.accentFont = accentFont
        self.accentAccessibilityIdentifier = accentAccessibilityIdentifier
        self.title = title
        self.titleFont = titleFont
        self.titleColor = titleColor
        self.titleLineLimit = titleLineLimit
        self.titleMinimumScaleFactor = titleMinimumScaleFactor
        self.titleAccessibilityIdentifier = titleAccessibilityIdentifier
        self.subtitle = subtitle
        self.subtitleFont = subtitleFont
        self.subtitleColor = subtitleColor
        self.subtitleLineLimit = subtitleLineLimit
        self.subtitleAccessibilityIdentifier = subtitleAccessibilityIdentifier
        self.accessibilityIdentifier = accessibilityIdentifier
        self.usesLeadingAccessoryLayout = usesLeadingAccessoryLayout
        self.contentVerticalOffset = contentVerticalOffset
        self.extraBottomPadding = extraBottomPadding
        self.topRow = topRow
        self.leadingAccessory = { EmptyView() }
    }
}

private extension View {
    @ViewBuilder
    func optionalAccessibilityIdentifier(_ identifier: String?) -> some View {
        if let identifier {
            accessibilityIdentifier(identifier)
        } else {
            self
        }
    }
}
