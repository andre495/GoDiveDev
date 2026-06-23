import SwiftUI

/// Shared **`TabView`** page chrome for buddy + trip detail horizontal pagers.
enum PushedDetailContentPagerLayout: Sendable {

    /// Each page must claim exactly one horizontal container slot so page swipes do not overshoot or settle off-center.
    @ViewBuilder
    static func tabPage<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .containerRelativeFrame(.horizontal, count: 1, span: 1, spacing: 0)
    }
}
