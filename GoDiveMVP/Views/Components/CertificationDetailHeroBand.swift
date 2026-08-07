import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Certification card hero — front/back photo letterboxed on the ocean gradient.
/// Width matches full-bleed media heroes; bottom edge sits on the blue-sheet seam.
struct CertificationDetailHeroBand: View {
    let photoData: Data?

    var body: some View {
        BlueSheetDetailHeroBandFill(accessibilityIdentifier: "CertificationDetails.Hero") {
            ZStack(alignment: .bottom) {
                AppTheme.Colors.screenBackgroundGradient
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                #if canImport(UIKit)
                if photoData != nil {
                    GoDiveCachedBlobImageView(
                        data: photoData,
                        maxPixelEdge: 1_200,
                        contentMode: .fit
                    ) {
                        heroPlaceholder
                    }
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, CertificationDetailHeroPresentation.cardPhotoHorizontalInset)
                    .padding(
                        .bottom,
                        CertificationDetailHeroPresentation.cardPhotoSeamBottomInset
                    )
                    .accessibilityLabel("Certification card photo")
                } else {
                    heroPlaceholder
                }
                #else
                heroPlaceholder
                #endif
            }
        }
    }

    private var heroPlaceholder: some View {
        BlueSheetDetailHeroPlaceholder(
            systemImage: CertificationDetailHeroPresentation.placeholderSystemImage,
            accessibilityLabel: CertificationDetailHeroPresentation.placeholderAccessibilityLabel
        )
    }
}
