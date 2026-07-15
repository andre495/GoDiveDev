import Foundation

/// Front / back side of a certification card hero (matches media/map toggle role on other detail pages).
nonisolated enum CertificationDetailHeroSide: String, CaseIterable, Hashable, Identifiable, Sendable {
    case front
    case back

    var id: String { rawValue }

    var accessibilityLabel: String {
        switch self {
        case .front: "Front of certification card"
        case .back: "Back of certification card"
        }
    }

    var shortTitle: String {
        switch self {
        case .front: "Front"
        case .back: "Back"
        }
    }

    var systemImage: String {
        switch self {
        case .front: "rectangle.portrait"
        case .back: "rectangle.portrait.on.rectangle.portrait"
        }
    }
}
