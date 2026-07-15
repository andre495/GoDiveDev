import Foundation
import CoreGraphics

/// Hero band rules for **`ViewCertificationDetails`** (front/back card photos).
enum CertificationDetailHeroPresentation: Sendable {
    nonisolated static let heroModeToggleBottomPadding: CGFloat =
        DiveBuddyDetailPresentation.heroModeToggleBottomPadding

    nonisolated static let placeholderSystemImage = "seal.fill"

    nonisolated static let placeholderAccessibilityLabel = "Certification card photo placeholder"

    /// Bottom inset so the card sits on the **visible** blue-sheet seam (top of the rounded panel),
    /// not the absolute bottom of the hero band (which extends behind the sheet).
    nonisolated static var cardPhotoSeamBottomInset: CGFloat {
        HomeOverviewLayout.panelOverlap
    }

    /// Match full-bleed media / map heroes — no side inset.
    nonisolated static let cardPhotoHorizontalInset: CGFloat = 0

    /// Show front/back toggle only when **both** card faces have photos.
    nonisolated static func showsHeroSideToggle(hasFront: Bool, hasBack: Bool) -> Bool {
        hasFront && hasBack
    }

    nonisolated static func showsHeroSideToggle(
        frontPicture: Data?,
        backPicture: Data?
    ) -> Bool {
        showsHeroSideToggle(hasFront: frontPicture != nil, hasBack: backPicture != nil)
    }

    /// Prefer front when present; otherwise the only available side; default front when empty.
    nonisolated static func defaultHeroSide(hasFront: Bool, hasBack: Bool) -> CertificationDetailHeroSide {
        if hasFront { return .front }
        if hasBack { return .back }
        return .front
    }

    nonisolated static func defaultHeroSide(
        frontPicture: Data?,
        backPicture: Data?
    ) -> CertificationDetailHeroSide {
        defaultHeroSide(hasFront: frontPicture != nil, hasBack: backPicture != nil)
    }

    /// Photo data for the selected side (falls back to the other side when the selection is empty).
    nonisolated static func photoData(
        for side: CertificationDetailHeroSide,
        frontPicture: Data?,
        backPicture: Data?
    ) -> Data? {
        switch side {
        case .front:
            return frontPicture ?? backPicture
        case .back:
            return backPicture ?? frontPicture
        }
    }
}
