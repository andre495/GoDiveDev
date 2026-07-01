import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Minimal list row chrome for global search — Apple Music–style title/subtitle with full-width hairlines.
enum GlobalSearchResultListRowLayout: Sendable {
    /// Compact row density (~60% of the original search list height).
    nonisolated static let compactScale: CGFloat = 0.6
    nonisolated static let artworkSize: CGFloat = 30
    nonisolated static let artworkCornerRadius: CGFloat = 4
    nonisolated static let rowVerticalPadding: CGFloat = 10
    nonisolated static let rowContentSpacing: CGFloat = AppTheme.Spacing.sm
    nonisolated static let textSpacing: CGFloat = 1
    nonisolated static let separatorOpacity: CGFloat = 0.14
    nonisolated static let subtitleOpacity: CGFloat = 0.55
    nonisolated static let separatorHeight: CGFloat = 0.5
}

struct GlobalSearchResultListRowHairline: View {
    var body: some View {
        Rectangle()
            .fill(.white.opacity(GlobalSearchResultListRowLayout.separatorOpacity))
            .frame(maxWidth: .infinity)
            .frame(height: GlobalSearchResultListRowLayout.separatorHeight)
    }
}

struct GlobalSearchResultListRow<Leading: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let leading: () -> Leading

    var body: some View {
        VStack(spacing: 0) {
            GlobalSearchResultListRowHairline()

            HStack(alignment: .center, spacing: GlobalSearchResultListRowLayout.rowContentSpacing) {
                leading()
                    .frame(
                        width: GlobalSearchResultListRowLayout.artworkSize,
                        height: GlobalSearchResultListRowLayout.artworkSize
                    )

                VStack(alignment: .leading, spacing: GlobalSearchResultListRowLayout.textSpacing) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(GlobalSearchResultListRowLayout.subtitleOpacity))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, GlobalSearchResultListRowLayout.rowVerticalPadding)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.clear)
        .contentShape(Rectangle())
    }
}

struct GlobalSearchResultSymbolArtwork: View {
    let systemName: String

    var body: some View {
        RoundedRectangle(
            cornerRadius: GlobalSearchResultListRowLayout.artworkCornerRadius,
            style: .continuous
        )
        .fill(.white.opacity(0.08))
        .overlay {
            Image(systemName: systemName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}

struct GlobalSearchResultMediaArtwork: View {
    let photoID: UUID

    var body: some View {
        LogbookRowMediaPreviewView(
            photoID: photoID,
            extent: GlobalSearchResultListRowLayout.artworkSize,
            placeholderStyle: .translucentOnDarkBubble,
            allowsCompactExtent: true
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: GlobalSearchResultListRowLayout.artworkCornerRadius,
                style: .continuous
            )
        )
    }
}

struct GlobalSearchResultSpeciesArtwork: View {
    let snapshot: MarineLifeCatalogSnapshot

    var body: some View {
        FieldGuideMarineLifeCatalogImage(
            imageURLString: snapshot.featureImageURL,
            bundleResourceName: snapshot.featureImageResourceName,
            placement: .mediaSheetHero(
                height: GlobalSearchResultListRowLayout.artworkSize,
                cornerRadius: GlobalSearchResultListRowLayout.artworkCornerRadius
            )
        )
    }
}

struct GlobalSearchResultAvatarArtwork: View {
    let profilePhoto: Data?
    let initials: String

    var body: some View {
        ProfileAvatarView(
            profilePhoto: profilePhoto,
            diameter: GlobalSearchResultListRowLayout.artworkSize,
            iconFont: .caption,
            placeholderInitials: initials,
            placeholderBackground: .translucentOnDarkBubble
        )
    }
}

#if canImport(UIKit)
struct GlobalSearchResultPhotoArtwork: View {
    let photoData: Data?
    let placeholderSystemName: String

    var body: some View {
        Group {
            if let photoData, let image = UIImage(data: photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                GlobalSearchResultSymbolArtwork(systemName: placeholderSystemName)
            }
        }
        .frame(
            width: GlobalSearchResultListRowLayout.artworkSize,
            height: GlobalSearchResultListRowLayout.artworkSize
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: GlobalSearchResultListRowLayout.artworkCornerRadius,
                style: .continuous
            )
        )
    }
}
#endif

struct GlobalSearchDiveResultListRow: View {
    let data: DiveLogbookRowDisplayData

    private var subtitle: String {
        let number = data.diveNumberLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if number.isEmpty || number == "-" {
            return data.detailLine
        }
        return "\(number) · \(data.detailLine)"
    }

    var body: some View {
        GlobalSearchResultListRow(
            title: data.displayName,
            subtitle: subtitle
        ) {
            if let previewMediaPhotoID = data.previewMediaPhotoID {
                GlobalSearchResultMediaArtwork(photoID: previewMediaPhotoID)
            } else {
                GlobalSearchResultSymbolArtwork(systemName: "water.waves")
            }
        }
    }
}
