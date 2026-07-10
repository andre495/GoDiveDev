import CoreGraphics
import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Self-contained fixture data for the logged-out **Share experiences** onboarding micro-demo.
enum OnboardingShareWithFriendsDemoFixtures: Sendable {
  enum DemoPage: String, CaseIterable, Identifiable, Sendable {
    case stats
    case sites
    case buddies

    var id: String { rawValue }
  }

  nonisolated static let tripTitle = "Belize 2026"
  nonisolated static let tripDateRange = "Jun 28 – Jul 5, 2026"
  nonisolated static let marineLifeCallout = "8 species spotted"

  nonisolated static let ownerBuddyID = UUID(uuidString: "A1000003-0000-4000-8000-00000000C001")!
  nonisolated static let mariaBuddyID = UUID(uuidString: "A1000003-0000-4000-8000-00000000C002")!
  nonisolated static let jamesBuddyID = UUID(uuidString: "A1000003-0000-4000-8000-00000000C003")!
  nonisolated static let samBuddyID = UUID(uuidString: "A1000003-0000-4000-8000-00000000C004")!

  nonisolated static let demoBuddyPhotoResourceNames: [String] = [
    "marine-life-french-angelfish",
    "marine-life-stoplight-parrotfish",
    "marine-life-green-sea-turtle",
  ]

  nonisolated static var demoPages: [DemoPage] {
    DemoPage.allCases
  }

  nonisolated static var statTiles: [DiveTripStatTile] {
    [
      DiveTripStatTile(
        id: "dives",
        title: "Dives",
        value: "12",
        footnote: "activities",
        systemImage: "list.bullet.rectangle.fill"
      ),
      DiveTripStatTile(
        id: "underwater-time",
        title: "Underwater",
        value: "7h 48m",
        footnote: "total bottom time",
        systemImage: "timer"
      ),
      DiveTripStatTile(
        id: "deepest",
        title: "Deepest",
        value: "124 ft",
        footnote: "max depth",
        systemImage: "arrow.down.to.line"
      ),
      DiveTripStatTile(
        id: "longest",
        title: "Longest",
        value: "62 min",
        footnote: "bottom time",
        systemImage: "clock.fill"
      ),
    ]
  }

  nonisolated static var plannedSiteRows: [OnboardingTripDemoSiteRow] {
    [
      OnboardingTripDemoSiteRow(
        id: UUID(uuidString: "A1000003-0000-4000-8000-00000000D001")!,
        displayName: "Blue Hole",
        coordinateLine: "17.316° N, 87.535° W",
        placeLine: "Belize · Lighthouse Reef"
      ),
      OnboardingTripDemoSiteRow(
        id: UUID(uuidString: "A1000003-0000-4000-8000-00000000D002")!,
        displayName: "Half Moon Caye",
        coordinateLine: "17.192° N, 87.535° W",
        placeLine: "Belize · Lighthouse Reef"
      ),
      OnboardingTripDemoSiteRow(
        id: UUID(uuidString: "A1000003-0000-4000-8000-00000000D003")!,
        displayName: "The Elbow",
        coordinateLine: "17.280° N, 87.590° W",
        placeLine: "Belize · Turneffe Atoll"
      ),
    ]
  }

  nonisolated static var taggedBuddies: [OnboardingTripDemoBuddy] {
    [
      OnboardingTripDemoBuddy(
        id: mariaBuddyID,
        displayName: "Maria",
        diveCountLabel: "8 dives",
        profilePhotoResourceName: demoBuddyPhotoResourceNames[0]
      ),
      OnboardingTripDemoBuddy(
        id: jamesBuddyID,
        displayName: "James",
        diveCountLabel: "6 dives",
        profilePhotoResourceName: demoBuddyPhotoResourceNames[1]
      ),
      OnboardingTripDemoBuddy(
        id: samBuddyID,
        displayName: "Sam",
        diveCountLabel: "4 dives",
        profilePhotoResourceName: demoBuddyPhotoResourceNames[2]
      ),
    ]
  }

  nonisolated static var shareCardMembers: [TripShareCardMember] {
    [
      TripShareCardMember(
        id: ownerBuddyID,
        displayName: "Alex",
        profilePhoto: nil,
        subtitle: "12 dives",
        usesAccentSubtitle: true
      ),
      TripShareCardMember(
        id: mariaBuddyID,
        displayName: "Maria",
        profilePhoto: bundledJPEGData(named: demoBuddyPhotoResourceNames[0]),
        subtitle: "8 dives",
        usesAccentSubtitle: true
      ),
      TripShareCardMember(
        id: jamesBuddyID,
        displayName: "James",
        profilePhoto: bundledJPEGData(named: demoBuddyPhotoResourceNames[1]),
        subtitle: "6 dives",
        usesAccentSubtitle: true
      ),
      TripShareCardMember(
        id: samBuddyID,
        displayName: "Sam",
        profilePhoto: bundledJPEGData(named: demoBuddyPhotoResourceNames[2]),
        subtitle: "4 dives",
        usesAccentSubtitle: true
      ),
    ]
  }

  nonisolated static func profilePhotoData(for buddy: OnboardingTripDemoBuddy) -> Data? {
    bundledJPEGData(named: buddy.profilePhotoResourceName)
  }

  nonisolated static func bundledJPEGData(named resourceName: String) -> Data? {
    guard let url = FieldGuideMarineLifeBundledImagePresentation.bundledPhotoURL(resourceName: resourceName) else {
      return nil
    }
    return try? Data(contentsOf: url)
  }

  /// Bundled JPEG under **`Resources/OnboardingPhotos/`** — tropical beach hero (Unsplash).
  nonisolated static let tripHeroPhotoResourceName = "onboarding-share-trip-hero-beach"

  nonisolated static let bundlePhotoSubdirectories = [
    "Resources/OnboardingPhotos",
    "OnboardingPhotos",
  ]

  /// Scale **`TripShareCardView`** to fit the onboarding phone frame in share preview.
  nonisolated static func shareCardScaleForPhoneFrame(
    phoneLogicalSize: CGSize = OnboardingDemoPhoneFrameMetrics.referenceLogicalSize
  ) -> CGFloat {
    min(
      phoneLogicalSize.width / TripShareCardPresentation.cardWidth,
      phoneLogicalSize.height / TripShareCardPresentation.cardMinHeight
    )
  }

  #if canImport(UIKit)
  @MainActor
  static func renderShareCardPreviewImage() -> UIImage? {
    let card = TripShareCardView(
      tripTitle: tripTitle,
      dateRange: tripDateRange,
      members: shareCardMembers,
      marineLifeCallout: marineLifeCallout,
      mapImage: shareCardMapImage
    )
    .frame(width: TripShareCardPresentation.cardWidth, alignment: .top)
    .background(AppOverviewSheetPanelBackground())

    let renderer = ImageRenderer(content: card)
    renderer.scale = 2
    return renderer.uiImage
  }
  #endif

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

  nonisolated static var tripHeroPhotoData: Data? {
    guard let url = bundledPhotoURL(resourceName: tripHeroPhotoResourceName) else { return nil }
    return try? Data(contentsOf: url)
  }

  #if canImport(UIKit)
  nonisolated static var tripHeroImage: UIImage? {
    guard let data = tripHeroPhotoData else { return nil }
    return UIImage(data: data)
  }
  #endif

  #if canImport(UIKit)
  nonisolated static var shareCardMapImage: UIImage? {
    let size = TripShareMapSnapshotPresentation.mapSnapshotSize(
      cardWidth: TripShareCardPresentation.cardWidth
    )
    let format = UIGraphicsImageRendererFormat()
    format.scale = 2
    format.opaque = true

    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    return renderer.image { context in
      let cg = context.cgContext
      let colors = [
        UIColor(red: 0.18, green: 0.52, blue: 0.78, alpha: 1).cgColor,
        UIColor(red: 0.08, green: 0.28, blue: 0.48, alpha: 1).cgColor,
      ] as CFArray
      let space = CGColorSpaceCreateDeviceRGB()
      if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) {
        cg.drawLinearGradient(
          gradient,
          start: .zero,
          end: CGPoint(x: size.width, y: size.height),
          options: []
        )
      }

      let pinCenters: [CGPoint] = [
        CGPoint(x: size.width * 0.42, y: size.height * 0.48),
        CGPoint(x: size.width * 0.58, y: size.height * 0.36),
        CGPoint(x: size.width * 0.34, y: size.height * 0.62),
      ]
      for center in pinCenters {
        cg.setFillColor(UIColor.systemRed.cgColor)
        cg.fillEllipse(in: CGRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10))
      }
    }
  }
  #endif
}

struct OnboardingTripDemoSiteRow: Identifiable, Equatable, Sendable {
  let id: UUID
  let displayName: String
  let coordinateLine: String
  let placeLine: String
}

struct OnboardingTripDemoBuddy: Identifiable, Equatable, Sendable {
  let id: UUID
  let displayName: String
  let diveCountLabel: String
  let profilePhotoResourceName: String
}
