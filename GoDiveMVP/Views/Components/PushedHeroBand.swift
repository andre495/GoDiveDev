import SwiftUI

/// Fixed-height hero band for pushed buddy/trip pages — bleeds media/map under the status bar without shifting the sheet seam.
///
/// Matches **`LogOverviewView`** carousel order: negative top padding, **`ignoresSafeArea`**, then **`frame(height:)`** so the
/// **`VStack`** slot stays **`height`** while content draws into the top safe area.
struct PushedHeroBand<Content: View>: View {
    let height: CGFloat
    let topSafeAreaInset: CGFloat
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, -topSafeAreaInset)
            .ignoresSafeArea(edges: .top)
            .frame(height: height)
            .frame(maxWidth: .infinity)
    }
}
