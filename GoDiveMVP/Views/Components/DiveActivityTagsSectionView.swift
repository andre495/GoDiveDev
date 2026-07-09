import SwiftUI

/// Tags block at the bottom of the map overview sheet.
struct DiveActivityTagsSectionView: View {
    let tags: [ActivityTag]
    let canAddTags: Bool
    let onAddTags: () -> Void

    private let columns = [GridItem(.adaptive(minimum: 88), spacing: AppTheme.Spacing.sm)]

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
                LazyVGrid(columns: columns, alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    ForEach(tags, id: \.id) { tag in
                        NavigationLink {
                            ActivityTagDetailView(tag: tag)
                                .hidesBottomTabBarWhenPushed()
                        } label: {
                            ActivityTagOvalChipLabel(title: tag.name)
                        }
                        .buttonStyle(.plain)
                        .navigationLinkIndicatorVisibility(.hidden)
                        .accessibilityHint("Opens tag details")
                        .accessibilityIdentifier("DiveOverview.Tags.\(tag.id.uuidString)")
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("DiveOverview.TagsSection")
    }
}
