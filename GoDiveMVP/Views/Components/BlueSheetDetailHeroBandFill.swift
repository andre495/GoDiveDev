import SwiftUI

/// Hero **fill** inside **`PushedHeroBand`** — expands to the band slot without re-applying **`heroHeight`**.
///
/// Height and top safe-area bleed come from **`PushedHeroBand`** / **`BlueSheetHeaderPageLayout`** only.
struct BlueSheetDetailHeroBandFill<Content: View>: View {
    var accessibilityIdentifier: String?
    var clipsContent: Bool = true
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .modifier(BlueSheetDetailHeroBandClipModifier(enabled: clipsContent))
            .accessibilityElement(children: .contain)
            .optionalHeroBandAccessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct BlueSheetDetailHeroBandClipModifier: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.clipped()
        } else {
            content
        }
    }
}

private extension View {
    @ViewBuilder
    func optionalHeroBandAccessibilityIdentifier(_ identifier: String?) -> some View {
        if let identifier {
            accessibilityIdentifier(identifier)
        } else {
            self
        }
    }
}
