import SwiftUI

/// Soft trailing fade on horizontal chip `ScrollView`s so overflow does not hard-clip.
private struct HorizontalChipRowTrailingScrollFadeModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var fadeOpacity: CGFloat = 0

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
        } else {
            content
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    DiveActivityHorizontalChipRowScrollFadePresentation.trailingFadeOpacity(
                        contentWidth: geometry.contentSize.width,
                        containerWidth: geometry.containerSize.width,
                        contentOffsetX: geometry.contentOffset.x
                    )
                } action: { _, newOpacity in
                    fadeOpacity = newOpacity
                }
                .mask {
                    // When fadeOpacity is 0 the trailing band stays fully opaque so chips
                    // are not clipped; as opacity rises the right edge softens to clear.
                    HStack(spacing: 0) {
                        Color.black
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0),
                                .init(
                                    color: .black.opacity(1 - (0.28 * fadeOpacity)),
                                    location: 0.28
                                ),
                                .init(
                                    color: .black.opacity(1 - (0.72 * fadeOpacity)),
                                    location: 0.68
                                ),
                                .init(
                                    color: .black.opacity(1 - fadeOpacity),
                                    location: 1
                                ),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: DiveActivityHorizontalChipRowScrollFadePresentation.fadeWidth)
                    }
                }
        }
    }
}

extension View {
    /// Soft trailing edge on horizontal buddy / marine-life chip rows instead of a hard clip.
    func horizontalChipRowTrailingScrollFade() -> some View {
        modifier(HorizontalChipRowTrailingScrollFadeModifier())
    }
}
