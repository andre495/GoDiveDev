import Foundation

/// Ownership of a **`MarineLife`** row for the Phase 1 hybrid split.
///
/// Catalog rows refresh from the bundled seed / future Firebase CDN.
/// User-created rows (`user-marine-life-*`) sync with the user's private store.
enum MarineLifeOwnership: String, Codable, CaseIterable, Sendable {
    case catalog
    case userOwned

    nonisolated static func inferred(fromUUID uuid: String) -> Self {
        FieldGuideMarineLifeAddPresentation.isUserCreated(uuid: uuid) ? .userOwned : .catalog
    }
}

/// Ownership of a **`DiveSite`** row for the Phase 1 hybrid split.
///
/// OpenDiveMap / CDN reference rows stay in the catalog store.
/// User-created / import-created sites sync with the user store.
enum DiveSiteOwnership: String, Codable, CaseIterable, Sendable {
    case catalogReference
    case userOwned

    nonisolated static func inferred(fromSiteTags siteTags: [String]) -> Self {
        DiveSiteCatalogMatcher.referenceID(from: siteTags) == nil ? .userOwned : .catalogReference
    }
}
