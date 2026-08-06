import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Small buddy avatar (remote Storage URL, local Profile JPEG, or initials).
/// Remote loads use **`GoDiveRemoteAvatarImageCache`**; local uses **`ProfileAvatarImageCache`**.
struct FriendSharedMapOwnerAvatarView: View {
    let displayName: String
    let photoURL: String?
    let diameter: CGFloat
    /// Friend-shared owners are always GoDive users.
    var showsGoDiveUserPin: Bool = true
    /// Local Profile / roster JPEG — preferred for the current user when remote is unavailable.
    var localProfilePhoto: Data? = nil

    #if canImport(UIKit)
    @State private var remoteImage: UIImage?
    @State private var localImage: UIImage?
    #endif

    private var loadToken: String {
        let remote = photoURL ?? ""
        let localKey = ProfileAvatarImageCachePresentation.cacheKey(for: localProfilePhoto ?? Data())
        return "\(remote)|\(localKey)|\(diameter)"
    }

    var body: some View {
        Group {
            #if canImport(UIKit)
            // Prefer local Profile JPEG when present (matches Settings / Profile for "me").
            if let localImage {
                Image(uiImage: localImage)
                    .resizable()
                    .scaledToFill()
            } else if let remoteImage {
                Image(uiImage: remoteImage)
                    .resizable()
                    .scaledToFill()
            } else {
                initialsPlaceholder
            }
            #else
            initialsPlaceholder
            #endif
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .overlay {
            ProfileAvatarChrome.accentRingOverlay(diameter: diameter)
        }
        .goDiveUserAvatarPin(shows: showsGoDiveUserPin, avatarDiameter: diameter)
        .accessibilityHidden(true)
        #if canImport(UIKit)
        .task(id: loadToken) {
            await loadAvatarImages()
        }
        #endif
    }

    private var initialsPlaceholder: some View {
        ProfileAvatarView(
            profilePhoto: nil,
            diameter: diameter,
            iconFont: .caption.weight(.semibold),
            placeholderInitials: DiveBuddyPresentation.initials(from: displayName)
        )
    }

    #if canImport(UIKit)
    @MainActor
    private func loadAvatarImages() async {
        if let localProfilePhoto, !localProfilePhoto.isEmpty {
            localImage = await ProfileAvatarImageCache.shared.image(for: localProfilePhoto)
        } else {
            localImage = nil
        }

        guard photoURL != nil else {
            remoteImage = nil
            return
        }
        if let cached = GoDiveRemoteAvatarImageCache.shared.cachedImage(for: photoURL) {
            remoteImage = cached
            return
        }
        let allowsNetwork = AppNetworkConnectivityPresentation.allowsCloudMediaFetch(
            isConnected: AppNetworkConnectivitySnapshot.shared.allowsCloudMediaFetch
        )
        remoteImage = await GoDiveRemoteAvatarImageCache.shared.image(
            for: photoURL,
            allowsNetworkFetch: allowsNetwork
        )
    }
    #endif
}
