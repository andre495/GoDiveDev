import SwiftUI

/// Collapsible section for long linked lists (dives on buddy / site / species detail).
struct ExpandableDetailSection<Content: View>: View {
    let title: String
    let itemCount: Int
    var isExpandedByDefault: Bool = false
    var accessibilityIdentifier: String?
    @ViewBuilder var content: () -> Content
    var emptyContent: (() -> AnyView)?

    @State private var isExpanded: Bool

    init(
        title: String,
        itemCount: Int,
        isExpandedByDefault: Bool = false,
        accessibilityIdentifier: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.itemCount = itemCount
        self.isExpandedByDefault = isExpandedByDefault
        self.accessibilityIdentifier = accessibilityIdentifier
        self.content = content
        self.emptyContent = nil
        _isExpanded = State(initialValue: isExpandedByDefault && itemCount > 0)
    }

    init<Empty: View>(
        title: String,
        itemCount: Int,
        isExpandedByDefault: Bool = false,
        accessibilityIdentifier: String? = nil,
        @ViewBuilder emptyContent: @escaping () -> Empty,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.itemCount = itemCount
        self.isExpandedByDefault = isExpandedByDefault
        self.accessibilityIdentifier = accessibilityIdentifier
        self.content = content
        self.emptyContent = { AnyView(emptyContent()) }
        _isExpanded = State(initialValue: isExpandedByDefault && itemCount > 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            sectionHeader

            if itemCount == 0 {
                if let emptyContent {
                    emptyContent()
                }
            } else if isExpanded {
                content()
            }
        }
        .accessibilityElement(children: .contain)
        .modifier(ExpandableDetailSectionAccessibilityID(identifier: accessibilityIdentifier))
    }

    private var sectionHeader: some View {
        Button {
            guard ExpandableDetailSectionPresentation.showsExpandControl(itemCount: itemCount) else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: AppTheme.Spacing.sm)

                if itemCount > 0 {
                    Text("\(itemCount)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.Colors.secondaryText)

                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.tabUnselected)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!ExpandableDetailSectionPresentation.showsExpandControl(itemCount: itemCount))
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(
            ExpandableDetailSectionPresentation.headerAccessibilityLabel(
                title: title,
                itemCount: itemCount,
                isExpanded: isExpanded
            )
        )
        .accessibilityHint(
            itemCount > 0
                ? (isExpanded ? "Collapse list" : "Expand list")
                : ""
        )
    }
}

private struct ExpandableDetailSectionAccessibilityID: ViewModifier {
    let identifier: String?

    func body(content: Content) -> some View {
        if let identifier, !identifier.isEmpty {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}
