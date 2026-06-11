import SwiftUI

/// Tags block at the bottom of the map overview sheet.
struct DiveActivityTagsSectionView: View {
    let tags: [ActivityTag]
    let canAddTags: Bool
    let onAddTags: () -> Void

    var body: some View {
        ActivityTagsOutlinedSection(appliesLogbookOuterMargins: false) {
            if canAddTags {
                DiveActivitySectionHeaderActionButton(
                    systemImage: "plus",
                    accessibilityLabel: "Add tags",
                    action: onAddTags
                )
                .accessibilityIdentifier("DiveOverview.Tags.Add")
            }
        } content: {
            if tags.isEmpty {
                Text(canAddTags ? "No tags yet. Tap + to add one." : "Sign in to add tags.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.tabUnselected)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                DiveActivityTagChipFlow(tagNames: tags.map(\.name))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("DiveOverview.TagsSection")
    }
}
