import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Shared accent ring for profile / buddy avatars (**`ProfileAvatarView`**, remote friend photos).
enum ProfileAvatarChrome {
    static func ringLineWidth(diameter: CGFloat) -> CGFloat {
        max(2, diameter / 24)
    }

    @ViewBuilder
    static func accentRingOverlay(diameter: CGFloat) -> some View {
        Circle()
            .strokeBorder(AppTheme.Colors.accentDeep, lineWidth: ringLineWidth(diameter: diameter))
    }
}

/// Circular profile image, optional initials placeholder, or default **person** icon.
struct ProfileAvatarView: View {
    enum PlaceholderBackground: Sendable {
        case surfaceElevated
        case translucentOnDarkBubble

        var color: Color {
            switch self {
            case .surfaceElevated:
                AppTheme.Colors.surfaceElevated
            case .translucentOnDarkBubble:
                Color.white.opacity(0.08)
            }
        }
    }

    let profilePhoto: Data?
    var diameter: CGFloat
    var iconFont: Font = .title3
    /// When **`profilePhoto`** is nil, show these initials instead of the person icon (buddy avatars).
    var placeholderInitials: String? = nil
    var placeholderBackground: PlaceholderBackground = .surfaceElevated

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
            ProfileAvatarChrome.accentRingOverlay(diameter: diameter)
        }
        #if canImport(UIKit)
        .task(id: profilePhotoCacheKey) {
            decodedImage = await ProfileAvatarImageCache.shared.image(for: profilePhoto)
        }
        #endif
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
            .foregroundStyle(
                placeholderBackground == .translucentOnDarkBubble
                    ? Color.white.opacity(0.85)
                    : AppTheme.Colors.accent
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(placeholderBackground.color)
    }

    private func initialsPlaceholder(_ initials: String) -> some View {
        Text(initials)
            .font(.system(size: diameter * 0.36, weight: .semibold, design: .rounded))
            .foregroundStyle(
                placeholderBackground == .translucentOnDarkBubble
                    ? Color.white.opacity(0.85)
                    : AppTheme.Colors.accent
            )
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(placeholderBackground.color)
            .accessibilityHidden(true)
    }
}
