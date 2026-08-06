import SwiftUI

/// Avatar with first-name caption for a dive buddy on overview / details.
/// Loads local roster JPEG when present, otherwise the linked / friend-graph Storage URL.
struct DiveActivityBuddyAvatarChip: View {
    let displayName: String
    let profilePhoto: Data?
    var photoURL: String? = nil
    var avatarDiameter: CGFloat = 56
    var showsGoDiveUserPin: Bool = false

    private var firstName: String {
        DiveBuddyPresentation.firstName(from: displayName)
    }

    private var accessibilityLabelText: String {
        if showsGoDiveUserPin {
            return "\(displayName), \(GoDiveUserAvatarPinPresentation.accessibilityLabel)"
        }
        return displayName
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            FriendSharedMapOwnerAvatarView(
                displayName: displayName,
                photoURL: photoURL,
                diameter: avatarDiameter,
                showsGoDiveUserPin: showsGoDiveUserPin,
                localProfilePhoto: profilePhoto
            )
            Text(firstName)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(width: max(avatarDiameter, 52))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelText)
    }
}
