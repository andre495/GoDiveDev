//
//  GoDiveMVPTestSupport.swift
//  GoDiveMVPTests
//

import CoreGraphics
import Foundation
import SwiftData
import SwiftUI
#if os(iOS)
import UIKit
#endif
@testable import GoDiveMVP

#if canImport(UIKit)
func solidTestImage(edge: CGFloat) -> UIImage {
    let size = CGSize(width: edge, height: edge)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    return renderer.image { context in
        UIColor.darkGray.setFill()
        context.fill(CGRect(origin: .zero, size: size))
    }
}
#endif

func logbookRowsSortedForDisplay(_ rows: [DiveLogbookRowDisplayData]) -> [DiveLogbookRowDisplayData] {
    rows.sorted {
        if $0.startTime != $1.startTime { return $0.startTime > $1.startTime }
        return $0.id.uuidString < $1.id.uuidString
    }
}

func logbookSnapshotSeed(
    id: UUID = UUID(),
    resolvedSiteNameLowercased: String?,
    activityTagNames: [String] = [],
    buddyDisplayNames: [String] = [],
    linkedTripID: UUID? = nil,
    startTime: Date = Date(timeIntervalSince1970: 0),
    durationMinutes: Int = 30,
    bottomTimeSeconds: Int? = nil,
    diveNumberExplicitlyNone: Bool = false
) -> LogbookActivitySnapshotSeed {
    LogbookActivitySnapshotSeed(
        id: id,
        kind: .scubaDive,
        sourceDiveId: nil,
        sourceActivityId: nil,
        startTime: startTime,
        maxDepthMeters: 10,
        swimDistanceMeters: nil,
        durationMinutes: durationMinutes,
        bottomTimeSeconds: bottomTimeSeconds,
        diveNumber: 1,
        diveNumberExplicitlyNone: diveNumberExplicitlyNone,
        displayName: resolvedSiteNameLowercased ?? "New Dive",
        formattedStartDateOnly: "Jan 1, 1970",
        resolvedSiteNameLowercased: resolvedSiteNameLowercased,
        activityTagNames: activityTagNames,
        buddyDisplayNames: buddyDisplayNames,
        previewMediaPhotoID: nil,
        linkedTripID: linkedTripID,
        previewMediaIsSnorkel: false
    )
}

@MainActor
struct FixedGeocodingTimeZoneResolver: GeocodingTimeZoneResolving {
    let timeZone: TimeZone

    func timeZone(for coordinate: DiveGeographicTimeZoneLookup.CoordinateInput) async -> TimeZone? {
        timeZone
    }

    func timeZone(forLocationQuery query: String) async -> TimeZone? {
        timeZone
    }
}

@MainActor
final class FailingGeocodingTimeZoneResolver: GeocodingTimeZoneResolving {
    private(set) var coordinateLookupCount = 0

    func timeZone(for coordinate: DiveGeographicTimeZoneLookup.CoordinateInput) async -> TimeZone? {
        coordinateLookupCount += 1
        return nil
    }

    func timeZone(forLocationQuery query: String) async -> TimeZone? {
        return nil
    }
}
