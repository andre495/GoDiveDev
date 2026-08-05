import SwiftUI

/// Small buddy avatar for friend-shared activity map headers (remote Storage URL or initials).
struct FriendSharedMapOwnerAvatarView: View {
    let displayName: String
    let photoURL: String?
    let diameter: CGFloat
    /// Friend-shared owners are always GoDive users.
    var showsGoDiveUserPin: Bool = true

    var body: some View {
        Group {
            if let photoURL,
               let url = GoDiveRemoteURLPolicy.sanitizedFirebaseStorageURL(from: photoURL)
            {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        initialsPlaceholder
                    }
                }
                .frame(width: diameter, height: diameter)
                .clipShape(Circle())
                .overlay {
                    ProfileAvatarChrome.accentRingOverlay(diameter: diameter)
                }
            } else {
                initialsPlaceholder
            }
        }
        .goDiveUserAvatarPin(shows: showsGoDiveUserPin, avatarDiameter: diameter)
        .accessibilityHidden(true)
    }

    private var initialsPlaceholder: some View {
        ProfileAvatarView(
            profilePhoto: nil,
            diameter: diameter,
            iconFont: .caption.weight(.semibold),
            placeholderInitials: DiveBuddyPresentation.initials(from: displayName)
        )
    }
}
