import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Circular profile image, optional initials placeholder, or default **person** icon.
struct ProfileAvatarView: View {
    let profilePhoto: Data?
    var diameter: CGFloat
    var iconFont: Font = .title3
    /// When **`profilePhoto`** is nil, show these initials instead of the person icon (buddy avatars).
    var placeholderInitials: String? = nil

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

    @ViewBuilder
    private var placeholder: some View {
        if profilePhoto == nil, let placeholderInitials, !placeholderInitials.isEmpty {
            initialsPlaceholder(placeholderInitials)
        } else {
            personIconPlaceholder
        }
    }

    private var personIconPlaceholder: some View {
        Image(systemName: "person.circle.fill")
            .font(iconFont)
            .foregroundStyle(AppTheme.Colors.accent)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.Colors.surfaceElevated)
    }

    private func initialsPlaceholder(_ initials: String) -> some View {
        Text(initials)
            .font(.system(size: diameter * 0.36, weight: .semibold, design: .rounded))
            .foregroundStyle(AppTheme.Colors.accent)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.Colors.surfaceElevated)
            .accessibilityHidden(true)
    }
}
