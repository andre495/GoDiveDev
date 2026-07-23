import Foundation
import SwiftData

/// Shared site-linking surface for **`DiveActivity`** and **`SnorkelActivity`** import pipelines.
@MainActor
protocol DiveSiteLinkableActivity: AnyObject {
    var siteName: String? { get set }
    var locationName: String? { get set }
    var entryLatitude: Double? { get set }
    var entryLongitude: Double? { get set }
    var diveSiteID: UUID? { get set }
    var ownerProfileID: UUID? { get set }
    var owner: UserProfile? { get set }
    var entryCoordinate: DiveCoordinate? { get set }
    var modelContext: ModelContext? { get }
}

extension DiveActivity: DiveSiteLinkableActivity {}
