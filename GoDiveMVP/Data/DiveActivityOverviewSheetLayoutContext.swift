import CoreGraphics
#if canImport(UIKit)
import UIKit
#endif

/// Layout inputs for resolving dive / snorkel overview sheet height (large detent matches blue sheet pages).
struct DiveActivityOverviewSheetLayoutContext: Sendable, Equatable {
    var layoutHeight: CGFloat
    var screenWidth: CGFloat
    var topSafeInset: CGFloat
    var bottomSafeInset: CGFloat

    nonisolated static let presentationReference = Self(
        layoutHeight: DiveActivityOverviewDetent.presentationReferenceScreenHeight,
        screenWidth: DiveActivityOverviewDetent.presentationReferenceScreenWidth,
        topSafeInset: 59,
        bottomSafeInset: DiveActivityOverviewDetent.presentationReferenceBottomSafeInset
    )

    /// Key-window metrics so modal sheets can match the embedded overview **large** detent height.
    @MainActor
    static func currentWindowContext() -> Self {
        #if canImport(UIKit)
        if let window = keyWindow {
            let bounds = window.bounds
            let insets = window.safeAreaInsets
            if bounds.height > 1, bounds.width > 1 {
                return Self(
                    layoutHeight: bounds.height,
                    screenWidth: bounds.width,
                    topSafeInset: insets.top,
                    bottomSafeInset: insets.bottom
                )
            }
        }
        #endif
        return .presentationReference
    }

    #if canImport(UIKit)
    @MainActor
    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first
    }
    #endif
}
