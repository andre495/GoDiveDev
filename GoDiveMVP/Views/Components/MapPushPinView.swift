import SwiftUI

/// Map pin shaped like a push pin: colored head, metallic stem, sharp tip.
///
/// The tip sits on the bottom edge of the rendered image so MapKit annotations can anchor
/// coordinates at **`MapPushPinMetrics.tipDistanceFromTop`** (equals rendered height).
struct MapPushPinView: View {
    var headColor: Color

    var body: some View {
        VStack(spacing: Layout.stemToPointOverlap) {
            head
                .shadow(color: .black.opacity(0.22), radius: 2, y: 1)

            RoundedRectangle(cornerRadius: Layout.stemWidth / 2, style: .continuous)
                .fill(Layout.stemGradient)
                .frame(width: Layout.stemWidth, height: Layout.stemHeight)
                .overlay {
                    RoundedRectangle(cornerRadius: Layout.stemWidth / 2, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 0.5)
                }

            MapPushPinPoint()
                .fill(Layout.pointGradient)
                .frame(width: Layout.pointWidth, height: Layout.pointHeight)
        }
        .frame(width: Layout.totalWidth, height: Layout.totalHeight, alignment: .bottom)
        .overlay(alignment: .bottom) {
            groundShadow
                .offset(y: -(Layout.pointHeight + 2))
        }
        .accessibilityHidden(true)
    }

    private var head: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: Layout.headOuterDiameter, height: Layout.headOuterDiameter)

            Circle()
                .fill(headColor)
                .frame(width: Layout.headDiameter, height: Layout.headDiameter)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.5), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: Layout.headDiameter * 0.42, height: Layout.headDiameter * 0.42)
                .offset(x: -Layout.headDiameter * 0.14, y: -Layout.headDiameter * 0.18)
        }
        .frame(height: Layout.headBlockHeight)
    }

    private var groundShadow: some View {
        Ellipse()
            .fill(Color.black.opacity(0.16))
            .frame(width: 10, height: 4)
    }
}

/// Layout constants for rendered pins and MapKit anchor math.
enum MapPushPinMetrics {
    static let renderedWidth: CGFloat = 28
    static let renderedHeight: CGFloat = 46

    /// **`MKAnnotationView.image`** height: pin in the top half, tip on the vertical center line.
    static let mapAnnotationImageHeight = renderedHeight * 2

    /// Tip Y within the map-annotation asset and within a pin-only annotation view.
    static let tipYInAnnotationView = renderedHeight

    /// Tip Y within **`makeMapAnnotationPinImage`** (vertical center of the asset).
    static let tipYInMapAnnotationImage = mapAnnotationImageHeight * 0.5
}

private extension MapPushPinView {
    enum Layout {
        static let totalWidth = MapPushPinMetrics.renderedWidth
        static let totalHeight = MapPushPinMetrics.renderedHeight
        static let headDiameter: CGFloat = 20
        static let headOuterDiameter: CGFloat = 24
        static let headBlockHeight: CGFloat = 22
        static let stemWidth: CGFloat = 3.5
        static let stemHeight: CGFloat = 10
        static let stemToPointOverlap: CGFloat = -3
        static let pointWidth: CGFloat = 5.5
        static let pointHeight: CGFloat = 9

        static var stemGradient: LinearGradient {
            LinearGradient(
                colors: [Color(white: 0.78), Color(white: 0.45)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }

        static var pointGradient: LinearGradient {
            LinearGradient(
                colors: [Color(white: 0.55), Color(white: 0.32)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

/// Sharp tip below the push-pin stem; **`maxY`** is the coordinate anchor.
private struct MapPushPinPoint: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
