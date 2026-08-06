import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Pinch-to-zoom still for friend-shared **`contentURL`** (falls back to thumb while loading).
struct FriendSharedMediaZoomableImageView: View {
    let item: FriendSharedMediaPresentation.DisplayItem

    #if canImport(UIKit)
    @State private var image: UIImage?
    @State private var zoomScale: CGFloat = 1
    @State private var steadyZoomScale: CGFloat = 1
    @State private var panOffset: CGSize = .zero
    @State private var steadyPanOffset: CGSize = .zero
    #endif

    var body: some View {
        #if canImport(UIKit)
        GeometryReader { geometry in
            ZStack {
                Color.black
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .scaleEffect(zoomScale)
                        .offset(panOffset)
                        .gesture(zoomGesture)
                        .simultaneousGesture(panGesture)
                        .onTapGesture(count: 2) {
                            resetZoom()
                        }
                } else {
                    GoDiveRotateLoadingIndicator(size: .compact, tint: .white)
                }
            }
        }
        .task(id: item.mediaID) {
            await loadImage()
        }
        #else
        Color.black
        #endif
    }

    #if canImport(UIKit)
    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                zoomScale = FriendSharedMediaFullscreenPresentation.clampedZoomScale(
                    steadyZoomScale * value
                )
            }
            .onEnded { value in
                steadyZoomScale = FriendSharedMediaFullscreenPresentation.clampedZoomScale(
                    steadyZoomScale * value
                )
                zoomScale = steadyZoomScale
                if steadyZoomScale <= FriendSharedMediaFullscreenPresentation.minZoomScale + 0.01 {
                    resetZoom()
                }
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard FriendSharedMediaFullscreenPresentation.allowsPanGesture(atZoomScale: zoomScale) else {
                    return
                }
                panOffset = CGSize(
                    width: steadyPanOffset.width + value.translation.width,
                    height: steadyPanOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                steadyPanOffset = panOffset
            }
    }

    private func resetZoom() {
        zoomScale = 1
        steadyZoomScale = 1
        panOffset = .zero
        steadyPanOffset = .zero
    }

    @MainActor
    private func loadImage() async {
        resetZoom()
        image = nil

        let snapshot = AppNetworkConnectivitySnapshot.shared
        let allowsNetwork = AppNetworkConnectivityPresentation.allowsCloudMediaFetch(
            isConnected: snapshot.allowsCloudMediaFetch
        )
        let allowsContent = FriendSharedMediaPresentation.allowsContentDownload(
            isConnected: allowsNetwork,
            usesWiFi: snapshot.usesWiFiInterface,
            wifiOnly: AppUserSettings.downloadFriendMediaOnWiFiOnly(),
            allowsConstrainedNetworkAccess: URLSession.shared.configuration.allowsConstrainedNetworkAccess
        )

        if allowsContent, let contentURL = item.contentURL {
            if let content = await GoDiveSharedMediaCache.shared.image(
                remoteURLString: contentURL,
                tier: .content,
                allowsNetworkFetch: true
            ) {
                image = content
                return
            }
        }

        if let thumbURL = item.thumbnailURL {
            image = await GoDiveSharedMediaCache.shared.image(
                remoteURLString: thumbURL,
                tier: .thumb,
                allowsNetworkFetch: allowsNetwork
            )
        }
    }
    #endif
}
