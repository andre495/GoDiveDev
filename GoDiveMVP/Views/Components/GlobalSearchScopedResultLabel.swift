import SwiftData
import SwiftUI

/// Category-aware minimalist search hit row. Renders from a precomputed **`GlobalSearchResultRowContent`**
/// (built once per results change) so scrolling never re-resolves display data on the main actor — see
/// **`GlobalSearchResultRowContent`** for the performance rationale.
struct GlobalSearchResultRowView: View {
    let content: GlobalSearchResultRowContent

    var body: some View {
        switch content.kind {
        case .dive(let data):
            GlobalSearchDiveResultListRow(data: data, matchReasons: content.matchReasons)
        case .standard(let title, let subtitle, let artwork):
            GlobalSearchResultListRow(
                title: title,
                subtitle: subtitle,
                matchReasons: content.matchReasons
            ) {
                artworkView(for: artwork)
            }
        }
    }

    @ViewBuilder
    private func artworkView(for artwork: GlobalSearchResultRowContent.Artwork) -> some View {
        switch artwork {
        case .symbol(let systemName):
            GlobalSearchResultSymbolArtwork(systemName: systemName)
        case .media(let photoID):
            GlobalSearchResultMediaArtwork(photoID: photoID)
        case .species(let snapshot):
            GlobalSearchResultSpeciesArtwork(snapshot: snapshot)
        case .avatar(let profilePhoto, let initials):
            GlobalSearchResultAvatarArtwork(profilePhoto: profilePhoto, initials: initials)
        case .photo(let data, let placeholder):
            #if canImport(UIKit)
            GlobalSearchResultPhotoArtwork(photoData: data, placeholderSystemName: placeholder)
            #else
            GlobalSearchResultSymbolArtwork(systemName: placeholder)
            #endif
        }
    }
}
