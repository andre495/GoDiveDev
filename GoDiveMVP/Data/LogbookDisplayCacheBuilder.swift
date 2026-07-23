import Foundation

/// Builds logbook row caches off the main actor (duplicate scan + row labels).
enum LogbookDisplayCacheBuilder {

  struct Result: Sendable {
    let items: [LogbookListDisplayItem]
    let duplicateIds: Set<UUID>
    let myActivitiesSummary: LogbookMyActivitiesSummary

    var rows: [DiveLogbookRowDisplayData] {
      items.flatMap(\.standaloneRows)
    }
  }

  nonisolated static func build(
    visibleSeeds: [LogbookActivitySnapshotSeed],
    tripSeeds: [LogbookTripSnapshotSeed],
    siteSearchQuery: String,
    confirmedTagName: String? = nil,
    confirmedBuddyName: String? = nil,
    confirmedTripID: UUID? = nil,
    unitSystem: DiveDisplayUnitSystem,
    useChronologicalNumbers: Bool,
    includeDuplicateScan: Bool = true
  ) -> Result {
    let filtered = DiveLogbookSiteSearch.filtering(
      visibleSeeds,
      siteQuery: siteSearchQuery,
      confirmedTagName: confirmedTagName,
      confirmedBuddyName: confirmedBuddyName,
      confirmedTripID: confirmedTripID
    )
    let duplicateIds: Set<UUID> = includeDuplicateScan
      ? duplicateIds(from: visibleSeeds)
      : []
    let diveNumberingRows = visibleSeeds
      .filter { $0.kind == .scubaDive }
      .map(\.numberingRow)
    let chronologicalNumbers: [UUID: Int] = useChronologicalNumbers
      ? DiveActivityDiveNumbering.numberedDiveSequentialIndicesById(for: diveNumberingRows)
      : [:]

    let rows = filtered.map { seed in
      DiveLogbookRowDisplayData(
        id: seed.id,
        activityKind: seed.kind,
        displayName: seed.displayName,
        diveNumberLabel: leadingChipLabel(
          for: seed,
          chronologicalNumbers: chronologicalNumbers,
          useChronologicalNumbers: useChronologicalNumbers
        ),
        diveNumberLeadingSymbolName: leadingChipSymbolName(for: seed.kind),
        detailLine: detailLine(for: seed, unitSystem: unitSystem),
        showsDuplicateHint: duplicateIds.contains(seed.id),
        previewMediaPhotoID: seed.previewMediaPhotoID,
        previewMediaIsSnorkel: seed.previewMediaIsSnorkel,
        startTime: seed.startTime
      )
    }
    let items = LogbookTripGrouping.buildListItems(
      rows: rows,
      seeds: filtered,
      tripSeeds: tripSeeds
    )
    let myActivitiesSummary = LogbookMyActivitiesSummaryPresentation.summary(from: filtered)
    return Result(
      items: items,
      duplicateIds: duplicateIds,
      myActivitiesSummary: myActivitiesSummary
    )
  }

  nonisolated private static func duplicateIds(from seeds: [LogbookActivitySnapshotSeed]) -> Set<UUID> {
    let diveSigs = seeds.filter { $0.kind == .scubaDive }.map(\.duplicateSignature)
    let snorkelSigs = seeds.filter { $0.kind == .snorkel }.map(\.snorkelDuplicateSignature)
    var result = DiveActivityDuplicateMatcher.idsWithDuplicates(in: diveSigs)
    result.formUnion(snorkelDuplicateIds(in: snorkelSigs))
    return result
  }

  nonisolated private static func snorkelDuplicateIds(
    in signatures: [SnorkelActivityDuplicateMatcher.Signature]
  ) -> Set<UUID> {
    guard signatures.count > 1 else { return [] }
    var result = Set<UUID>()
    for i in signatures.indices {
      for j in (i + 1) ..< signatures.count {
        if SnorkelActivityDuplicateMatcher.matchReason(
          candidate: signatures[i],
          existing: signatures[j]
        ) != nil {
          result.insert(signatures[i].id)
          result.insert(signatures[j].id)
        }
      }
    }
    return result
  }

  nonisolated private static func leadingChipSymbolName(
    for kind: LogbookActivitySnapshotKind
  ) -> String {
    switch kind {
    case .scubaDive:
      LogbookActivityRowPresentation.scubaDiveLeadingSymbolName
    case .snorkel:
      LogbookActivityRowPresentation.snorkelLeadingSymbolName
    }
  }

  nonisolated private static func leadingChipLabel(
    for seed: LogbookActivitySnapshotSeed,
    chronologicalNumbers: [UUID: Int],
    useChronologicalNumbers: Bool
  ) -> String {
    switch seed.kind {
    case .snorkel:
      return LogbookActivityRowPresentation.snorkelChipTitle
    case .scubaDive:
      return logbookDiveNumberLabel(
        for: seed,
        chronologicalNumbers: chronologicalNumbers,
        useChronologicalNumbers: useChronologicalNumbers
      )
    }
  }

  nonisolated private static func logbookDiveNumberLabel(
    for seed: LogbookActivitySnapshotSeed,
    chronologicalNumbers: [UUID: Int],
    useChronologicalNumbers: Bool
  ) -> String {
    if seed.diveNumberExplicitlyNone {
      return "-"
    }
    if useChronologicalNumbers, let number = chronologicalNumbers[seed.id] {
      return "#\(number)"
    }
    if let number = seed.diveNumber {
      return "#\(number)"
    }
    return "-"
  }

  nonisolated private static func detailLine(
    for seed: LogbookActivitySnapshotSeed,
    unitSystem: DiveDisplayUnitSystem
  ) -> String {
    let duration = "\(seed.durationMinutes) min"
    switch seed.kind {
    case .scubaDive:
      let depth = DiveQuantityFormatting.depth(meters: seed.maxDepthMeters, system: unitSystem)
      return "\(seed.formattedStartDateOnly) · \(depth) · \(duration)"
    case .snorkel:
      var parts = [seed.formattedStartDateOnly]
      if let meters = seed.swimDistanceMeters, meters > 0 {
        parts.append(DiveQuantityFormatting.swimDistance(meters: meters, system: unitSystem))
      }
      if seed.maxDepthMeters > 0 {
        parts.append(DiveQuantityFormatting.depth(meters: seed.maxDepthMeters, system: unitSystem))
      }
      parts.append(duration)
      return parts.joined(separator: " · ")
    }
  }
}
