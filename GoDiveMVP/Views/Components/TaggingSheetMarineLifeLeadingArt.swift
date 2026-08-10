import SwiftUI

/// 44pt clipped catalog thumb for marine-life tagging sheets.
struct TaggingSheetMarineLifeLeadingArt: View {
    let featureImageURL: String
    let featureImageResourceName: String

    var body: some View {
        FieldGuideMarineLifeCatalogImage(
            imageURLString: featureImageURL,
            bundleResourceName: featureImageResourceName,
            placement: .mediaSheetHero(
                height: TaggingSheetSelectionPresentation.leadingArtDiameter,
                cornerRadius: TaggingSheetSelectionPresentation.leadingArtDiameter / 2
            )
        )
        .frame(
            width: TaggingSheetSelectionPresentation.leadingArtDiameter,
            height: TaggingSheetSelectionPresentation.leadingArtDiameter
        )
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}
