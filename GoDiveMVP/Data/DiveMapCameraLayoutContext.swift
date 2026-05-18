import CoreGraphics

/// Inputs that affect dive overview map camera framing (testable without SwiftUI).
struct DiveMapCameraLayoutContext: Equatable, Sendable {
    let coordinateIdentity: String
    let layoutHeight: CGFloat
    let bottomContentMargin: CGFloat
    let topObstructionHeight: CGFloat
    let cameraLayoutDetent: DiveActivityOverviewDetent

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.coordinateIdentity == rhs.coordinateIdentity
            && lhs.layoutHeight == rhs.layoutHeight
            && lhs.bottomContentMargin == rhs.bottomContentMargin
            && lhs.topObstructionHeight == rhs.topObstructionHeight
            && lhs.cameraLayoutDetent == rhs.cameraLayoutDetent
    }
}
