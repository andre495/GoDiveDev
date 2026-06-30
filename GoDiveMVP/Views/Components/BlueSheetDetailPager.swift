import SwiftUI

/// Per-page layout for **`BlueSheetDetailPager`** (static vs scroll, insets, a11y).
struct BlueSheetDetailPagerPageLayout: Sendable {
    var usesStaticLayout: Bool = false
    var staticContentAlignment: Alignment = .top
    var scrollBottomInsetExtra: CGFloat = 0
    var accessibilityLabel: String = ""
    var accessibilityIdentifier: String = ""
}

/// Swipable **`TabView`** pager chrome for blue-sheet **detail** pages.
struct BlueSheetDetailPager<Page: Hashable & Identifiable, PageContent: View>: View {
    let pagerAccessibilityIdentifier: String
    let pages: [Page]
    @Binding var selectedPage: Page
    let bottomScrollInset: CGFloat
    var usesLazyMount: Bool
    var onPageFirstMounted: ((Page) -> Void)?
    let pageLayout: (Page) -> BlueSheetDetailPagerPageLayout
    @ViewBuilder let pageContent: (Page) -> PageContent

    @State private var mountedPages: Set<Page>

    init(
        pagerAccessibilityIdentifier: String,
        pages: [Page],
        selection: Binding<Page>,
        bottomScrollInset: CGFloat,
        usesLazyMount: Bool = true,
        onPageFirstMounted: ((Page) -> Void)? = nil,
        pageLayout: @escaping (Page) -> BlueSheetDetailPagerPageLayout,
        @ViewBuilder pageContent: @escaping (Page) -> PageContent
    ) {
        self.pagerAccessibilityIdentifier = pagerAccessibilityIdentifier
        self.pages = pages
        _selectedPage = selection
        self.bottomScrollInset = bottomScrollInset
        self.usesLazyMount = usesLazyMount
        self.onPageFirstMounted = onPageFirstMounted
        self.pageLayout = pageLayout
        self.pageContent = pageContent
        _mountedPages = State(
            initialValue: usesLazyMount ? [selection.wrappedValue] : Set(pages)
        )
    }

    var body: some View {
        TabView(selection: $selectedPage) {
            ForEach(pages) { page in
                PushedDetailContentPagerLayout.tabPage {
                    pagerPage(page)
                }
                .tag(page)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(edges: .bottom)
        .accessibilityIdentifier(pagerAccessibilityIdentifier)
        .onAppear {
            notePageFirstMounted(selectedPage)
        }
        .onChange(of: selectedPage) { _, page in
            notePageFirstMounted(page)
        }
    }

    private func notePageFirstMounted(_ page: Page) {
        if usesLazyMount {
            let inserted = mountedPages.insert(page).inserted
            guard inserted else { return }
        }
        onPageFirstMounted?(page)
    }

    @ViewBuilder
    private func resolvedPageContent(for page: Page) -> some View {
        if usesLazyMount, !mountedPages.contains(page) {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(true)
        } else {
            pageContent(page)
        }
    }

    @ViewBuilder
    private func pagerPage(_ page: Page) -> some View {
        let layout = pageLayout(page)

        Group {
            if layout.usesStaticLayout {
                VStack(spacing: 0) {
                    resolvedPageContent(for: page)
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity,
                            alignment: layout.staticContentAlignment
                        )

                    Color.clear
                        .frame(height: bottomScrollInset)
                        .accessibilityHidden(true)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: BlueSheetDetailPagerPresentation.scrollPageSpacing) {
                        resolvedPageContent(for: page)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Color.clear
                            .frame(height: bottomScrollInset + layout.scrollBottomInsetExtra)
                            .accessibilityHidden(true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollClipDisabled(false)
                .scrollDismissesKeyboard(.interactively)
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .homeSheetPanelBottomScrollFade()
        .accessibilityLabel(layout.accessibilityLabel)
        .accessibilityIdentifier(layout.accessibilityIdentifier)
    }
}
