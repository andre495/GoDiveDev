import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Circular profile image or default **person** icon (shared on Profile and Home).
struct ProfileAvatarView: View {
    let profilePhoto: Data?
    var diameter: CGFloat
    var iconFont: Font = .title3

    var body: some View {
        Group {
            #if canImport(UIKit)
            if let profilePhoto, let image = UIImage(data: profilePhoto) {
                Image(uiImage: image)
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
    }

    private var placeholder: some View {
        Image(systemName: "person.circle.fill")
            .font(iconFont)
            .foregroundStyle(AppTheme.Colors.accent)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.Colors.surfaceElevated)
    }
}
