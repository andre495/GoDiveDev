import SwiftUI

/// Full-screen friend activity media — horizontal browse, pinch-zoom photos, streaming video.
struct FriendSharedMediaFullscreenView: View {
    let items: [FriendSharedMediaPresentation.DisplayItem]
    @Binding var selectedMediaID: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if items.isEmpty {
                Text(GoDiveFriendsPresentation.mediaHiddenLabel)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.8))
            } else {
                TabView(selection: $selectedMediaID) {
                    ForEach(items) { item in
                        pageContent(for: item)
                            .tag(Optional(item.mediaID))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: items.count > 1 ? .automatic : .never))
            }

            chromeOverlay
        }
        .accessibilityIdentifier(FriendSharedMediaFullscreenPresentation.rootAccessibilityIdentifier)
        .onAppear {
            if selectedMediaID == nil {
                selectedMediaID = items.first?.mediaID
            }
        }
        .task(id: prefetchToken) {
            await prefetchAdjacentContent()
        }
        .onChange(of: selectedMediaID) { _, newValue in
            Task {
                await prefetchContent(around: newValue)
            }
        }
    }

    private var prefetchToken: String {
        items.map(\.mediaID).joined(separator: "-")
    }

    private var chromeOverlay: some View {
        VStack {
            HStack {
                if items.count > 1,
                   let selectedMediaID,
                   let index = items.firstIndex(where: { $0.mediaID == selectedMediaID }) {
                    Text(
                        FriendSharedMediaFullscreenPresentation.chromeTitle(
                            pageIndex: index,
                            pageCount: items.count
                        )
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.45), in: Capsule())
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.45), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
                .accessibilityIdentifier(FriendSharedMediaFullscreenPresentation.closeAccessibilityIdentifier)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.top, AppTheme.Spacing.sm)
            Spacer()
        }
    }

    @ViewBuilder
    private func pageContent(for item: FriendSharedMediaPresentation.DisplayItem) -> some View {
        if item.kind == .video {
            FriendSharedRemoteVideoPlayerView(item: item, isPlaybackActive: true)
        } else {
            FriendSharedMediaZoomableImageView(item: item)
        }
    }

    private func prefetchAdjacentContent() async {
        let contentURLs = FriendSharedMediaPresentation.detailContentPrefetchURLs(
            items: items,
            selectedMediaID: selectedMediaID
        )
        await prefetchContentURLs(contentURLs)
    }

    private func prefetchContent(around selectedID: String?) async {
        let contentURLs = FriendSharedMediaPresentation.detailContentPrefetchURLs(
            items: items,
            selectedMediaID: selectedID
        )
        await prefetchContentURLs(contentURLs)
    }

    private func prefetchContentURLs(_ urls: [String]) async {
        let snapshot = AppNetworkConnectivitySnapshot.shared
        let allowsContent = AppNetworkConnectivityPresentation.allowsFriendSharedMediaContentDownload(
            isConnected: snapshot.allowsCloudMediaFetch,
            usesWiFi: snapshot.usesWiFiInterface,
            wifiOnly: AppUserSettings.downloadFriendMediaOnWiFiOnly(),
            allowsConstrainedNetworkAccess: URLSession.shared.configuration.allowsConstrainedNetworkAccess
        )
        guard allowsContent else { return }
        await GoDiveSharedMediaCache.shared.prefetch(
            remoteURLStrings: urls,
            tier: .content,
            allowsNetworkFetch: true
        )
    }
}
