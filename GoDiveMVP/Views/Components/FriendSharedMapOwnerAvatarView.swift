import SwiftUI

/// Small buddy avatar for friend-shared activity map headers (remote Storage URL or initials).
struct FriendSharedMapOwnerAvatarView: View {
    let displayName: String
    let photoURL: String?
    let diameter: CGFloat

    var body: some View {
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
            .accessibilityHidden(true)
        } else {
            initialsPlaceholder
                .accessibilityHidden(true)
        }
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
