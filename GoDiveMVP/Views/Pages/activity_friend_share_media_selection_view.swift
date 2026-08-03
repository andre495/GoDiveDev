import SwiftData
import SwiftUI

/// Checkbox grid for per-activity friend-share media selection (dives + snorkels).
struct ActivityFriendShareMediaSelectionView: View {
    enum MediaSource {
        case dive([DiveMediaPhoto])
        case snorkel([SnorkelMediaPhoto])
    }

    let mediaSource: MediaSource
    @Binding var selectedMediaIDs: Set<UUID>
    let isEnabled: Bool

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: LinkedMediaGridPresentation.spacing),
            count: LinkedMediaGridPresentation.columnCount
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Text("Check the media friends can see for this activity.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isGalleryEmpty {
                    Text("No media on this activity yet.")
                        .font(.body)
                        .foregroundStyle(AppTheme.Colors.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("ActivityFriendShare.MediaSelection.Empty")
                } else {
                    LazyVGrid(columns: gridColumns, spacing: LinkedMediaGridPresentation.spacing) {
                        switch mediaSource {
                        case .dive(let items):
                            ForEach(items, id: \.id) { media in
                                diveCell(for: media)
                            }
                        case .snorkel(let items):
                            ForEach(items, id: \.id) { media in
                                snorkelCell(for: media)
                            }
                        }
                    }
                    .accessibilityIdentifier("ActivityFriendShare.MediaSelection.Grid")
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.md)
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .navigationTitle(ActivityFriendSharePresentation.selectMediaTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isGalleryEmpty: Bool {
        switch mediaSource {
        case .dive(let items): return items.isEmpty
        case .snorkel(let items): return items.isEmpty
        }
    }

    private func diveCell(for media: DiveMediaPhoto) -> some View {
        selectionCell(
            mediaID: media.id,
            thumbnail: {
                DiveActivityMediaThumbnailView(
                    media: media,
                    size: 0,
                    cornerRadius: 0,
                    prefersStoredPreviewOnly: true
                )
            }
        )
    }

    private func snorkelCell(for media: SnorkelMediaPhoto) -> some View {
        selectionCell(
            mediaID: media.id,
            thumbnail: {
                SnorkelActivityMediaThumbnailView(
                    media: media,
                    size: 0,
                    cornerRadius: 0,
                    prefersStoredPreviewOnly: true
                )
            }
        )
    }

    private func selectionCell<Thumbnail: View>(
        mediaID: UUID,
        @ViewBuilder thumbnail: () -> Thumbnail
    ) -> some View {
        let isSelected = selectedMediaIDs.contains(mediaID)
        return Button {
            guard isEnabled else { return }
            if isSelected {
                selectedMediaIDs.remove(mediaID)
            } else {
                selectedMediaIDs.insert(mediaID)
            }
        } label: {
            Color.clear
                .aspectRatio(LinkedMediaGridPresentation.cellAspectRatio, contentMode: .fit)
                .overlay { thumbnail() }
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: LinkedMediaGridPresentation.cornerRadius,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: LinkedMediaGridPresentation.cornerRadius,
                        style: .continuous
                    )
                    .strokeBorder(
                        isSelected ? AppTheme.Colors.accent : Color.clear,
                        lineWidth: 3
                    )
                }
                .overlay(alignment: .topTrailing) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3.weight(.semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, isSelected ? AppTheme.Colors.accent : .black.opacity(0.35))
                        .padding(6)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSelected ? "Shared with buddies" : "Not shared with buddies")
        .accessibilityIdentifier("ActivityFriendShare.MediaSelection.\(mediaID.uuidString)")
    }
}
