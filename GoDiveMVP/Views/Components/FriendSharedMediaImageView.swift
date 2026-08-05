import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Progressive friend-shared still image — thumb first, optional crossfade to content.
struct FriendSharedMediaImageView: View {
    let item: FriendSharedMediaPresentation.DisplayItem
    var fidelity: Fidelity = .thumbnailOnly
    var showsVideoBadge: Bool = true
    /// Reports loaded still / poster aspect so Media heroes can match owner detent scaling.
    var onDisplayedImageAspectChange: ((CGFloat) -> Void)? = nil

    enum Fidelity: Equatable {
        case thumbnailOnly
        case progressive
    }

    #if canImport(UIKit)
    @State private var thumbnailImage: UIImage?
    @State private var contentImage: UIImage?
    @State private var loadGeneration = 0
    #endif

    var body: some View {
        #if canImport(UIKit)
        ZStack {
            AppTheme.Colors.surfaceElevated
            if let displayedImage {
                Image(uiImage: displayedImage)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity.animation(.easeInOut(duration: 0.25)))
            } else {
                ProgressView()
            }

            if showsVideoBadge, item.kind == .video {
                videoBadge
            }
        }
        .task(id: loadToken) {
            await loadImages()
        }
        .onChange(of: displayedImageAspectToken) { _, _ in
            reportDisplayedImageAspectIfNeeded()
        }
        .onAppear {
            reportDisplayedImageAspectIfNeeded()
        }
        #else
        AppTheme.Colors.surfaceElevated
        #endif
    }

    #if canImport(UIKit)
    private var loadToken: String {
        "\(item.mediaID)-\(fidelity)-\(item.thumbnailURL ?? "")-\(item.contentURL ?? "")-\(loadGeneration)"
    }

    private var displayedImage: UIImage? {
        if fidelity == .progressive, let contentImage { return contentImage }
        return thumbnailImage ?? contentImage
    }

    private var displayedImageAspectToken: String {
        guard let displayedImage else { return "nil" }
        return "\(displayedImage.size.width)x\(displayedImage.size.height)"
    }

    private func reportDisplayedImageAspectIfNeeded() {
        guard let displayedImage else { return }
        let height = max(displayedImage.size.height, 1)
        onDisplayedImageAspectChange?(displayedImage.size.width / height)
    }

    private var videoBadge: some View {
        Image(systemName: "play.circle.fill")
            .font(.title)
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, .black.opacity(0.35))
            .shadow(radius: 4)
            .allowsHitTesting(false)
    }

    @MainActor
    private func loadImages() async {
        let snapshot = AppNetworkConnectivitySnapshot.shared
        let allowsNetwork = AppNetworkConnectivityPresentation.allowsCloudMediaFetch(
            isConnected: snapshot.allowsCloudMediaFetch
        )
        let allowsConstrained = URLSession.shared.configuration.allowsConstrainedNetworkAccess
        let allowsContent = FriendSharedMediaPresentation.allowsContentDownload(
            isConnected: allowsNetwork,
            usesWiFi: snapshot.usesWiFiInterface,
            wifiOnly: AppUserSettings.downloadFriendMediaOnWiFiOnly(),
            allowsConstrainedNetworkAccess: allowsConstrained
        )

        if let thumbURL = item.thumbnailURL {
            let thumb = await GoDiveSharedMediaCache.shared.image(
                remoteURLString: thumbURL,
                tier: .thumb,
                allowsNetworkFetch: allowsNetwork
            )
            thumbnailImage = thumb
        }

        guard fidelity == .progressive,
              item.kind == .photo,
              allowsContent,
              let contentURL = item.contentURL
        else { return }

        let content = await GoDiveSharedMediaCache.shared.image(
            remoteURLString: contentURL,
            tier: .content,
            allowsNetworkFetch: true
        )
        if let content {
            withAnimation(.easeInOut(duration: 0.25)) {
                contentImage = content
            }
        }
    }
    #endif
}
