import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Equipment locker item hero — photo or archive placeholder behind the shared band contract.
struct EquipmentDetailHeroBand: View {
    let photoData: Data?

    var body: some View {
        BlueSheetDetailHeroBandFill(accessibilityIdentifier: "EquipmentDetails.Hero") {
            #if canImport(UIKit)
            if photoData != nil {
                GeometryReader { proxy in
                    GoDiveCachedBlobImageView(
                        data: photoData,
                        maxPixelEdge: max(proxy.size.width, proxy.size.height) * 2
                    ) {
                        heroPlaceholder
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                }
                .accessibilityLabel("Equipment photo")
            } else {
                heroPlaceholder
            }
            #else
            heroPlaceholder
            #endif
        }
    }

    private var heroPlaceholder: some View {
        BlueSheetDetailHeroPlaceholder(
            systemImage: "archivebox.fill",
            accessibilityLabel: "Equipment photo placeholder"
        )
    }
}
