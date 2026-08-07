import SwiftUI

/// Friend-profile shared media grid body (title is pager-pinned).
struct FriendProfileSharedMediaPanel: View {
    let items: [FriendSharedMediaPresentation.DisplayItem]
    let diveByMediaID: [String: GoDiveSharedDiveProjectionMapping.FriendVisibleDive]
    let isLoading: Bool
    @Binding var fullscreenSelectedMediaID: String?
    var onOpenActivity: ((GoDiveSharedDiveProjectionMapping.FriendVisibleDive) -> Void)? = nil

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: LinkedMediaGridPresentation.spacing),
        count: LinkedMediaGridPresentation.columnCount
    )

    var body: some View {
        Group {
            if isLoading {
                GoDiveRotateLoadingIndicator()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.Spacing.lg)
            } else if items.isEmpty {
                Text(FriendProfileContentPagerPresentation.sharedMediaEmptyMessage)
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier(
                        FriendProfileSharedMediaListPresentation.emptyAccessibilityIdentifier
                    )
            } else {
                LazyVGrid(columns: columns, spacing: LinkedMediaGridPresentation.spacing) {
                    ForEach(items) { item in
                        Button {
                            fullscreenSelectedMediaID = item.mediaID
                        } label: {
                            FriendSharedMediaImageView(item: item, fidelity: .thumbnailOnly)
                                .aspectRatio(
                                    LinkedMediaGridPresentation.cellAspectRatio,
                                    contentMode: .fit
                                )
                                .clipShape(
                                    RoundedRectangle(
                                        cornerRadius: LinkedMediaGridPresentation.cornerRadius,
                                        style: .continuous
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(item.kind == .video ? "Shared video" : "Shared photo")
                    }
                }
                .accessibilityIdentifier(
                    FriendProfileSharedMediaListPresentation.gridAccessibilityIdentifier
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier(
            FriendProfileSharedMediaListPresentation.sectionAccessibilityIdentifier
        )
        .fullScreenCover(isPresented: fullscreenPresented) {
            FriendSharedMediaFullscreenView(
                items: items,
                diveByMediaID: diveByMediaID,
                selectedMediaID: $fullscreenSelectedMediaID,
                onOpenActivity: onOpenActivity
            )
        }
    }

    private var fullscreenPresented: Binding<Bool> {
        Binding(
            get: { fullscreenSelectedMediaID != nil },
            set: { if !$0 { fullscreenSelectedMediaID = nil } }
        )
    }
}
