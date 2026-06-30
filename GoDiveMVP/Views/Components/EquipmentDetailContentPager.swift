import SwiftData
import SwiftUI

/// Single-tab equipment detail pager — metadata sections under shared pager chrome.
struct EquipmentDetailContentPager: View {
    @Bindable var item: EquipmentItem
    let bottomScrollInset: CGFloat

    @State private var selectedPage: EquipmentDetailContentPage =
        EquipmentDetailContentPagerPresentation.defaultPage

    var body: some View {
        BlueSheetDetailPager(
            pagerAccessibilityIdentifier: "EquipmentDetails.ContentPager",
            pages: EquipmentDetailContentPagerPresentation.pages,
            selection: $selectedPage,
            bottomScrollInset: bottomScrollInset,
            pageLayout: EquipmentDetailContentPagerPresentation.pagerPageLayout(for:),
            pageContent: pageContent(for:)
        )
    }

    @ViewBuilder
    private func pageContent(for page: EquipmentDetailContentPage) -> some View {
        switch page {
        case .details:
            EquipmentDetailMetadataView(item: item)
                .accessibilityIdentifier("EquipmentDetails.Details")
        }
    }
}
