import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Circular profile image or default **person** icon (shared on Profile and Home).
struct ProfileAvatarView: View {
    let profilePhoto: Data?
    var diameter: CGFloat
    var iconFont: Font = .title3

    #if canImport(UIKit)
    @State private var decodedImage: UIImage?
    #endif

    private var profilePhotoCacheKey: String {
        guard let profilePhoto else { return "nil" }
        return ProfileAvatarImageCachePresentation.cacheKey(for: profilePhoto)
    }

    var body: some View {
        Group {
            #if canImport(UIKit)
            if let decodedImage {
                Image(uiImage: decodedImage)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
            #else
            placeholder
            #endif
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .overlay {
            Circle()
                .strokeBorder(AppTheme.Colors.accentDeep, lineWidth: ringLineWidth)
        }
        #if canImport(UIKit)
        .task(id: profilePhotoCacheKey) {
            decodedImage = await ProfileAvatarImageCache.shared.image(for: profilePhoto)
        }
        #endif
    }

    private var ringLineWidth: CGFloat {
        max(2, diameter / 24)
    }

    private var placeholder: some View {
        Image(systemName: "person.circle.fill")
            .font(iconFont)
            .foregroundStyle(AppTheme.Colors.accent)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.Colors.surfaceElevated)
    }
}
