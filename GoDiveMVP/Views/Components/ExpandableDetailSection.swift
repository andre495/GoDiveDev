import SwiftUI

/// Collapsible section for long linked lists (dives on buddy / site / species detail).
struct ExpandableDetailSection<Content: View>: View {
    let title: String
    let itemCount: Int
    var isExpandedByDefault: Bool = false
    /// When **`true`**, expanded rows live in a **`ScrollView`** filling space below the section header (buddy **Dives together**).
    var scrollsExpandedContent: Bool = false
    /// After the first reveal, keep expanded content in the hierarchy (hidden when collapsed) for snappy re-expand.
    var keepsExpandedContentMountedAfterFirstReveal: Bool = false
    var accessibilityIdentifier: String?
    @ViewBuilder var content: () -> Content
    var emptyContent: (() -> AnyView)?

    @State private var isExpanded: Bool
    @State private var keepsExpandedContentMounted = false

    init(
        title: String,
        itemCount: Int,
        isExpandedByDefault: Bool = false,
        scrollsExpandedContent: Bool = false,
        keepsExpandedContentMountedAfterFirstReveal: Bool = false,
        accessibilityIdentifier: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.itemCount = itemCount
        self.isExpandedByDefault = isExpandedByDefault
        self.scrollsExpandedContent = scrollsExpandedContent
        self.keepsExpandedContentMountedAfterFirstReveal = keepsExpandedContentMountedAfterFirstReveal
        self.accessibilityIdentifier = accessibilityIdentifier
        self.content = content
        self.emptyContent = nil
        _isExpanded = State(initialValue: isExpandedByDefault && itemCount > 0)
    }

    init<Empty: View>(
        title: String,
        itemCount: Int,
        isExpandedByDefault: Bool = false,
        scrollsExpandedContent: Bool = false,
        keepsExpandedContentMountedAfterFirstReveal: Bool = false,
        accessibilityIdentifier: String? = nil,
        @ViewBuilder emptyContent: @escaping () -> Empty,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.itemCount = itemCount
        self.isExpandedByDefault = isExpandedByDefault
        self.scrollsExpandedContent = scrollsExpandedContent
        self.keepsExpandedContentMountedAfterFirstReveal = keepsExpandedContentMountedAfterFirstReveal
        self.accessibilityIdentifier = accessibilityIdentifier
        self.content = content
        self.emptyContent = { AnyView(emptyContent()) }
        _isExpanded = State(initialValue: isExpandedByDefault && itemCount > 0)
    }

    private var usesScrollFillExpandLayout: Bool {
        scrollsExpandedContent || keepsExpandedContentMountedAfterFirstReveal
    }

    private var shouldMountExpandedContent: Bool {
        itemCount > 0
            && (isExpanded || (keepsExpandedContentMountedAfterFirstReveal && keepsExpandedContentMounted))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            sectionHeader

            if itemCount == 0 {
                if let emptyContent {
                    emptyContent()
                }
            } else if usesScrollFillExpandLayout {
                if shouldMountExpandedContent {
                    scrollFillExpandedContent
                }
            } else if isExpanded {
                content()
            }
        }
        .frame(maxHeight: scrollsExpandedContent ? .infinity : nil, alignment: .top)
        .accessibilityElement(children: .contain)
        .modifier(ExpandableDetailSectionAccessibilityID(identifier: accessibilityIdentifier))
        .onAppear(perform: prewarmExpandedContentIfNeeded)
        .onChange(of: itemCount) { _, newCount in
            if newCount == 0 {
                keepsExpandedContentMounted = false
            } else {
                prewarmExpandedContentIfNeeded()
            }
        }
    }

    @ViewBuilder
    private var scrollFillExpandedContent: some View {
        Group {
            if scrollsExpandedContent {
                expandedContent
                    .frame(maxHeight: isExpanded ? .infinity : 0, alignment: .top)
            } else {
                expandedContent
                    .frame(maxHeight: isExpanded ? nil : 0, alignment: .top)
            }
        }
        .clipped()
        .opacity(isExpanded ? 1 : 0)
        .allowsHitTesting(isExpanded)
        .accessibilityHidden(!isExpanded)
        .animation(nil, value: isExpanded)
    }

    private func prewarmExpandedContentIfNeeded() {
        guard keepsExpandedContentMountedAfterFirstReveal, itemCount > 0 else { return }
        guard !keepsExpandedContentMounted else { return }
        Task { @MainActor in
            await Task.yield()
            keepsExpandedContentMounted = true
        }
    }

    @ViewBuilder
    private var expandedContent: some View {
        if scrollsExpandedContent {
            ScrollView {
                content()
            }
            .frame(maxHeight: .infinity, alignment: .top)
        } else {
            content()
        }
    }

    private var sectionHeader: some View {
        Button {
            guard ExpandableDetailSectionPresentation.showsExpandControl(itemCount: itemCount) else { return }
            if keepsExpandedContentMountedAfterFirstReveal, !keepsExpandedContentMounted {
                keepsExpandedContentMounted = true
            }
            isExpanded.toggle()
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
                        .animation(
                            .snappy(
                                duration: ExpandableDetailSectionPresentation.expandCollapseAnimationDuration
                            ),
                            value: isExpanded
                        )
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
