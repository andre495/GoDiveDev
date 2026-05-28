import Foundation

/// Builds logbook row caches off the main actor (duplicate scan + row labels).
enum LogbookDisplayCacheBuilder {

  struct Result: Sendable {
    let rows: [DiveLogbookRowDisplayData]
    let duplicateIds: Set<UUID>
  }

  nonisolated static func build(
    visibleSeeds: [LogbookActivitySnapshotSeed],
    siteSearchQuery: String,
    confirmedTagName: String? = nil,
    unitSystem: DiveDisplayUnitSystem,
    useChronologicalNumbers: Bool,
    includeDuplicateScan: Bool = true
  ) -> Result {
    let filtered = DiveLogbookSiteSearch.filtering(
      visibleSeeds,
      siteQuery: siteSearchQuery,
      confirmedTagName: confirmedTagName
    )
    let duplicateIds: Set<UUID> = includeDuplicateScan
      ? DiveActivityDuplicateMatcher.idsWithDuplicates(
          in: visibleSeeds.map { $0.duplicateSignature }
        )
      : []
    let chronologicalNumbers: [UUID: Int] = useChronologicalNumbers
      ? DiveActivityDiveNumbering.numberedDiveSequentialIndicesById(
          for: visibleSeeds.map { $0.numberingRow }
        )
      : [:]

    let rows = filtered.map { seed in
      DiveLogbookRowDisplayData(
        id: seed.id,
        displayName: seed.displayName,
        diveNumberLabel: logbookDiveNumberLabel(
          for: seed,
          chronologicalNumbers: chronologicalNumbers,
          useChronologicalNumbers: useChronologicalNumbers
        ),
        detailLine: detailLine(for: seed, unitSystem: unitSystem),
        showsDuplicateHint: duplicateIds.contains(seed.id)
      )
    }
    return Result(rows: rows, duplicateIds: duplicateIds)
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
    let depth = DiveQuantityFormatting.depth(meters: seed.maxDepthMeters, system: unitSystem)
    let duration = "\(seed.durationMinutes) min"
    return "\(seed.formattedStartDateOnly) · \(depth) · \(duration)"
  }
}
