import SwiftUI

/// Notification-style selectable row for tagging / multi-select picker sheets.
struct TaggingSheetSelectionRow<Leading: View, Accessory: View>: View {
    let title: String
    var subtitle: String?
    let isSelected: Bool
    let accessibilityValueSelected: String
    let accessibilityValueUnselected: String
    let onTap: () -> Void
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var accessory: () -> Accessory

    init(
        title: String,
        subtitle: String? = nil,
        isSelected: Bool,
        accessibilityValueSelected: String = "Selected",
        accessibilityValueUnselected: String = "Not selected",
        onTap: @escaping () -> Void,
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.accessibilityValueSelected = accessibilityValueSelected
        self.accessibilityValueUnselected = accessibilityValueUnselected
        self.onTap = onTap
        self.leading = leading
        self.accessory = accessory
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
                leading()
                    .frame(
                        width: TaggingSheetSelectionPresentation.leadingArtDiameter,
                        height: TaggingSheetSelectionPresentation.leadingArtDiameter
                    )
                    .clipped()

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(TaggingSheetSelectionPresentation.titleLineLimit)
                        .truncationMode(.tail)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .multilineTextAlignment(.leading)
                            .lineLimit(TaggingSheetSelectionPresentation.subtitleLineLimit)
                            .truncationMode(.tail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                accessory()

                Image(systemName: TaggingSheetSelectionPresentation.selectionSystemName(isSelected: isSelected))
                    .font(.title3)
                    .foregroundStyle(
                        isSelected
                            ? AppTheme.Colors.tabSelected
                            : AppTheme.Colors.secondaryText
                    )
                    .accessibilityHidden(true)
            }
            .padding(.vertical, AppTheme.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? accessibilityValueSelected : accessibilityValueUnselected)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// Compact SF Symbol leading art for rows without a photo (tags, sites).
struct TaggingSheetSymbolLeadingArt: View {
    let systemName: String

    var body: some View {
        ZStack {
            Circle()
                .fill(AppTheme.Colors.surfaceElevated)
            Image(systemName: systemName)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.tabSelected)
        }
        .frame(
            width: TaggingSheetSelectionPresentation.leadingArtDiameter,
            height: TaggingSheetSelectionPresentation.leadingArtDiameter
        )
        .accessibilityHidden(true)
    }
}

/// Flag emoji centered in the standard leading slot.
struct TaggingSheetFlagLeadingArt: View {
    let flagEmoji: String?

    var body: some View {
        ZStack {
            Circle()
                .fill(AppTheme.Colors.surfaceElevated)
            if let flagEmoji, !flagEmoji.isEmpty {
                Text(flagEmoji)
                    .font(.title2)
            } else {
                Image(systemName: TaggingSheetSelectionPresentation.countryPlaceholderSystemName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.tabSelected)
            }
        }
        .frame(
            width: TaggingSheetSelectionPresentation.leadingArtDiameter,
            height: TaggingSheetSelectionPresentation.leadingArtDiameter
        )
        .accessibilityHidden(true)
    }
}
