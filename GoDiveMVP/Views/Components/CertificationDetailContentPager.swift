import SwiftData
import SwiftUI

/// Two-tab certification detail pager — Details → Instructor & shop.
struct CertificationDetailContentPager: View {
    @Bindable var certification: Certification
    let divesLoggedSinceAttainedCount: Int
    let bottomScrollInset: CGFloat

    @State private var selectedPage: CertificationDetailContentPage =
        CertificationDetailContentPagerPresentation.defaultPage

    var body: some View {
        BlueSheetDetailPager(
            pagerAccessibilityIdentifier: "CertificationDetails.ContentPager",
            pages: CertificationDetailContentPagerPresentation.pages,
            selection: $selectedPage,
            bottomScrollInset: bottomScrollInset,
            pageLayout: CertificationDetailContentPagerPresentation.pagerPageLayout(for:),
            pageContent: pageContent(for:)
        )
    }

    @ViewBuilder
    private func pageContent(for page: CertificationDetailContentPage) -> some View {
        switch page {
        case .details:
            CertificationDetailDetailsMetadataView(
                certification: certification,
                divesLoggedSinceAttainedCount: divesLoggedSinceAttainedCount
            )
        case .instructorAndShop:
            CertificationDetailInstructorMetadataView(certification: certification)
        }
    }
}
