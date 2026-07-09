import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Self-contained fixture data for the logged-out **Monitor your equipment** onboarding micro-demo.
enum OnboardingMonitorEquipmentDemoFixtures: Sendable {
  nonisolated static let focusedItemID = UUID(uuidString: "A1000004-0000-4000-8000-00000000E001")!
  nonisolated static let serviceSectionScrollID = "OnboardingMonitorEquipmentDemo.Service"

  nonisolated static let heroHeight: CGFloat = 320
  nonisolated static let panelOverlap: CGFloat = 12

  nonisolated static let garminManufacturer = "Garmin"
  nonisolated static let garminModel = "Mk3i"
  nonisolated static let garminTitle = "Garmin Mk3i"
  nonisolated static let garminGearTypeLabel = "Dive Computer"
  /// Bundled JPEG (no extension) under **`Resources/OnboardingPhotos/`** — Garmin Descent™ Mk3i product photo.
  nonisolated static let garminMk3iPhotoResourceName = "onboarding-garmin-descent-mk3i"

  nonisolated static let nextServiceLabel = "Mar 15, 2027"
  nonisolated static let lastServiceLabel = "Mar 15, 2026"
  nonisolated static let recurrenceLabel = "Every 1 year"
  nonisolated static let serviceNotes =
    "Annual battery and O-ring check. Verify transmitter pairing before each trip."

  nonisolated static let bundlePhotoSubdirectories = [
    "Resources/OnboardingPhotos",
    "OnboardingPhotos",
  ]

  nonisolated static let lockerRows: [OnboardingEquipmentDemoListRow] = [
    OnboardingEquipmentDemoListRow(
      id: UUID(uuidString: "A1000004-0000-4000-8000-00000000E002")!,
      manufacturer: "Atomic Aquatics",
      model: "Z2",
      gearTypeLabel: "Regulator",
      showsEquipmentPhoto: false
    ),
    OnboardingEquipmentDemoListRow(
      id: focusedItemID,
      manufacturer: garminManufacturer,
      model: garminModel,
      gearTypeLabel: garminGearTypeLabel,
      showsEquipmentPhoto: true
    ),
    OnboardingEquipmentDemoListRow(
      id: UUID(uuidString: "A1000004-0000-4000-8000-00000000E003")!,
      manufacturer: "Apeks",
      model: "XTX50",
      gearTypeLabel: "Regulator",
      showsEquipmentPhoto: false
    ),
    OnboardingEquipmentDemoListRow(
      id: UUID(uuidString: "A1000004-0000-4000-8000-00000000E004")!,
      manufacturer: "Mares",
      model: "Avanti Quattro",
      gearTypeLabel: "Fins",
      showsEquipmentPhoto: false
    ),
  ]

  nonisolated static func displayTitle(for row: OnboardingEquipmentDemoListRow) -> String {
    "\(row.manufacturer) \(row.model)"
  }

  nonisolated static func bundledPhotoURL(
    resourceName: String,
    bundle: Bundle = .main
  ) -> URL? {
    let trimmed = resourceName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    for subdirectory in bundlePhotoSubdirectories {
      if let url = bundle.url(
        forResource: trimmed,
        withExtension: "jpg",
        subdirectory: subdirectory
      ) {
        return url
      }
    }

    return bundle.url(forResource: trimmed, withExtension: "jpg")
  }

  nonisolated static var garminMk3iPhotoData: Data? {
    guard let url = bundledPhotoURL(resourceName: garminMk3iPhotoResourceName) else { return nil }
    return try? Data(contentsOf: url)
  }

  nonisolated static func equipmentPhotoData(for row: OnboardingEquipmentDemoListRow) -> Data? {
    guard row.showsEquipmentPhoto else { return nil }
    return garminMk3iPhotoData
  }

  #if canImport(UIKit)
  nonisolated static var garminMk3iHeroImage: UIImage? {
    guard let data = garminMk3iPhotoData else { return nil }
    return UIImage(data: data)
  }
  #endif
}

struct OnboardingEquipmentDemoListRow: Identifiable, Equatable, Sendable {
  let id: UUID
  let manufacturer: String
  let model: String
  let gearTypeLabel: String
  let showsEquipmentPhoto: Bool
}
