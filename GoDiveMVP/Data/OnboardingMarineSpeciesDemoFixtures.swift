import CoreGraphics
import Foundation

/// Self-contained fixture data for the logged-out **Learn from thousands of marine species** onboarding micro-demo.
enum OnboardingMarineSpeciesDemoFixtures: Sendable {
  nonisolated static let fishesCategoryID = "fishes"
  nonisolated static let angelfishesSubcategoryID = "angelfishes"
  nonisolated static let frenchAngelfishUUID = "marine-life-french-angelfish"
  nonisolated static let frenchAngelfishImageResourceName = "marine-life-french-angelfish"

  nonisolated static let heroHeight: CGFloat = 300
  nonisolated static let panelOverlap: CGFloat = 12

  nonisolated static let hubCategories: [OnboardingFieldGuideDemoCategoryRow] = [
    OnboardingFieldGuideDemoCategoryRow(categoryID: "sponges", speciesCount: 42),
    OnboardingFieldGuideDemoCategoryRow(categoryID: fishesCategoryID, speciesCount: 286),
    OnboardingFieldGuideDemoCategoryRow(categoryID: "corals", speciesCount: 118),
    OnboardingFieldGuideDemoCategoryRow(categoryID: "invertebrates", speciesCount: 204),
  ]

  /// Compact fishes subcategory list — scroll targets **Angelfishes** before opening French angelfish.
  nonisolated static let fishesSubcategoryRows: [OnboardingFieldGuideDemoSubcategoryRow] = [
    OnboardingFieldGuideDemoSubcategoryRow(id: "butterflyfishes", speciesCount: 12),
    OnboardingFieldGuideDemoSubcategoryRow(id: angelfishesSubcategoryID, speciesCount: 8),
    OnboardingFieldGuideDemoSubcategoryRow(id: "triggerfishes", speciesCount: 9),
    OnboardingFieldGuideDemoSubcategoryRow(id: "parrotfishes", speciesCount: 11),
    OnboardingFieldGuideDemoSubcategoryRow(id: "groupers", speciesCount: 14),
  ]

  nonisolated static var frenchAngelfishSnapshot: MarineLifeCatalogSnapshot {
    MarineLifeCatalogSnapshot(
      uuid: frenchAngelfishUUID,
      commonName: "French Angelfish",
      scientificName: "Pomacanthus paru",
      category: fishesCategoryID,
      subcategory: angelfishesSubcategoryID,
      featureImageURL: "",
      featureImageResourceName: frenchAngelfishImageResourceName,
      minSizeMeters: 0.4,
      maxSizeMeters: 0.4,
      avgDepthMeters: 45,
      minDepthMeters: 3,
      maxDepthMeters: 100,
      distinctiveFeatures:
        "Dark gray with yellow scale edges. Yellow around eye, at base of pectoral fin and on tips of dorsal and anal fins."
    )
  }

  nonisolated static var frenchAngelfishAboutText: String {
    frenchAngelfishSnapshot.distinctiveFeatures
  }

  nonisolated static func taxonomyLabel(for snapshot: MarineLifeCatalogSnapshot) -> String {
    let category = FieldGuideTaxonomy.categoryTitle(for: snapshot)
    let subcategory = FieldGuideTaxonomy.subcategoryTitle(for: snapshot)
    if subcategory != "—" {
      return "\(category) · \(subcategory)"
    }
    return category == "—" ? "" : category
  }

  nonisolated static func bundledPhotoURL(
    resourceName: String = frenchAngelfishImageResourceName,
    bundle: Bundle = .main
  ) -> URL? {
    FieldGuideMarineLifeBundledImagePresentation.bundledPhotoURL(
      resourceName: resourceName,
      bundle: bundle
    )
  }
}

struct OnboardingFieldGuideDemoCategoryRow: Identifiable, Equatable, Sendable {
  let categoryID: String
  let speciesCount: Int

  var id: String { categoryID }
}

struct OnboardingFieldGuideDemoSubcategoryRow: Identifiable, Equatable, Sendable {
  let id: String
  let speciesCount: Int
}
