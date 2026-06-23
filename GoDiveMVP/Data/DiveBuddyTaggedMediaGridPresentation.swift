import CoreGraphics
import Foundation

/// Grid layout for buddy tagged media on **`ViewDiveBuddyDetails`**.
enum DiveBuddyTaggedMediaGridPresentation: Sendable {
    nonisolated static var columnCount: Int { LinkedMediaGridPresentation.columnCount }
    nonisolated static var spacing: CGFloat { LinkedMediaGridPresentation.spacing }
    nonisolated static var cornerRadius: CGFloat { LinkedMediaGridPresentation.cornerRadius }

    nonisolated static func cellSideLength(containerWidth: CGFloat) -> CGFloat {
        LinkedMediaGridPresentation.cellSideLength(containerWidth: containerWidth)
    }
}
