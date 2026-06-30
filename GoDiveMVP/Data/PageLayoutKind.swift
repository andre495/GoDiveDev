import Foundation

/// Pages that share the Home-style hero + overlapping blue sheet layout.
enum PageLayoutKind: String, Sendable, CaseIterable, Identifiable {
    case home
    case buddyDetail
    case tripDetail
    case speciesDetail
    case diveSiteDetail

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .home: "Home"
        case .buddyDetail: "Buddy detail"
        case .tripDetail: "Trip detail"
        case .speciesDetail: "Species detail"
        case .diveSiteDetail: "Dive site detail"
        }
    }
}
