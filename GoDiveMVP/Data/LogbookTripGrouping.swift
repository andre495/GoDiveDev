import Foundation

/// Trip metadata captured on the main actor for logbook grouping.
struct LogbookTripSnapshotSeed: Sendable, Equatable {
    let tripID: UUID
    let displayTitle: String
    let startDate: Date
    let endDate: Date
}

/// Trip header + standard logbook dive rows shown together on the logbook.
struct LogbookTripGroupDisplayData: Equatable, Identifiable, Sendable {
    var id: UUID { tripID }
    let tripID: UUID
    let title: String
    let dateRangeLine: String
    let dives: [DiveLogbookRowDisplayData]
    let sortTime: Date
    let accentColorIndex: Int

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.tripID == rhs.tripID
            && lhs.title == rhs.title
            && lhs.dateRangeLine == rhs.dateRangeLine
            && lhs.dives == rhs.dives
            && lhs.sortTime == rhs.sortTime
            && lhs.accentColorIndex == rhs.accentColorIndex
    }

    nonisolated func withAccentColorIndex(_ accentColorIndex: Int) -> Self {
        LogbookTripGroupDisplayData(
            tripID: tripID,
            title: title,
            dateRangeLine: dateRangeLine,
            dives: dives,
            sortTime: sortTime,
            accentColorIndex: accentColorIndex
        )
    }
}

enum LogbookListDisplayItem: Equatable, Identifiable, Sendable {
    case standalone(DiveLogbookRowDisplayData)
    case tripGroup(LogbookTripGroupDisplayData)

    nonisolated var id: String {
        switch self {
        case .standalone(let row):
            return "dive-\(row.id.uuidString)"
        case .tripGroup(let group):
            return "trip-\(group.tripID.uuidString)"
        }
    }

    nonisolated var sortTime: Date {
        switch self {
        case .standalone(let row):
            return row.startTime
        case .tripGroup(let group):
            return group.sortTime
        }
    }

    nonisolated var standaloneRows: [DiveLogbookRowDisplayData] {
        switch self {
        case .standalone(let row):
            return [row]
        case .tripGroup:
            return []
        }
    }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.standalone(let left), .standalone(let right)):
            return left == right
        case (.tripGroup(let left), .tripGroup(let right)):
            return left == right
        default:
            return false
        }
    }
}

enum LogbookTripGrouping {

  nonisolated static func formattedGroupHeaderTitle(displayTitle: String, diveCount: Int) -> String {
    let countLabel = diveCount == 1 ? "1 dive" : "\(diveCount) dives"
    return "\(displayTitle) · \(countLabel)"
  }

  nonisolated static func buildListItems(
    rows: [DiveLogbookRowDisplayData],
    seeds: [LogbookActivitySnapshotSeed],
    tripSeeds: [LogbookTripSnapshotSeed]
  ) -> [LogbookListDisplayItem] {
    let seedByID = Dictionary(uniqueKeysWithValues: seeds.map { ($0.id, $0) })
    let tripByID = Dictionary(uniqueKeysWithValues: tripSeeds.map { ($0.tripID, $0) })

    var tripRows: [UUID: [DiveLogbookRowDisplayData]] = [:]
    var standaloneItems: [LogbookListDisplayItem] = []

    for row in rows {
      guard let tripID = seedByID[row.id]?.linkedTripID, tripByID[tripID] != nil else {
        standaloneItems.append(.standalone(row))
        continue
      }
      tripRows[tripID, default: []].append(row)
    }

    var tripItems: [LogbookListDisplayItem] = []
    for (tripID, groupedRows) in tripRows {
      guard let trip = tripByID[tripID] else { continue }
      let sortedRows = groupedRows.sorted {
        if $0.startTime != $1.startTime { return $0.startTime > $1.startTime }
        return $0.id.uuidString < $1.id.uuidString
      }
      guard sortedRows.count >= 2, let newest = sortedRows.first else {
        if let single = sortedRows.first {
          standaloneItems.append(.standalone(single))
        }
        continue
      }

      tripItems.append(
        .tripGroup(
          LogbookTripGroupDisplayData(
            tripID: tripID,
            title: trip.displayTitle,
            dateRangeLine: DiveTripPresentation.formattedDateRange(
              start: trip.startDate,
              end: trip.endDate
            ),
            dives: sortedRows,
            sortTime: newest.startTime,
            accentColorIndex: 0
          )
        )
      )
    }

    return assignAccentColors(to: (tripItems + standaloneItems).sorted {
      if $0.sortTime != $1.sortTime { return $0.sortTime > $1.sortTime }
      return $0.id < $1.id
    })
  }

  /// Assigns cycling bright accent colors so consecutive trip groups in list order never match.
  nonisolated static func assignAccentColors(to items: [LogbookListDisplayItem]) -> [LogbookListDisplayItem] {
    var previousTripColorIndex: Int?
    return items.map { item in
      guard case .tripGroup(let group) = item else { return item }
      let colorIndex = LogbookTripGroupAccentPalette.nextIndex(after: previousTripColorIndex)
      previousTripColorIndex = colorIndex
      return .tripGroup(group.withAccentColorIndex(colorIndex))
    }
  }

  nonisolated static func removingDive(id diveID: UUID, from items: [LogbookListDisplayItem]) -> [LogbookListDisplayItem] {
    assignAccentColors(to:
      items.compactMap { item in
        switch item {
        case .standalone(let row):
          return row.id == diveID ? nil : item
        case .tripGroup(let group):
          let remaining = group.dives.filter { $0.id != diveID }
          if remaining.isEmpty { return nil }
          if remaining.count == 1, let only = remaining.first {
            return .standalone(only)
          }
          guard let newest = remaining.max(by: { $0.startTime < $1.startTime }) else { return nil }
          return .tripGroup(
            LogbookTripGroupDisplayData(
              tripID: group.tripID,
              title: group.title,
              dateRangeLine: group.dateRangeLine,
              dives: remaining.sorted {
                if $0.startTime != $1.startTime { return $0.startTime > $1.startTime }
                return $0.id.uuidString < $1.id.uuidString
              },
              sortTime: newest.startTime,
              accentColorIndex: group.accentColorIndex
            )
          )
        }
      }
    )
  }

  nonisolated static func applyingDiveNumberLabels(
    _ labels: [UUID: String],
    to items: [LogbookListDisplayItem]
  ) -> [LogbookListDisplayItem] {
    assignAccentColors(to:
      items.map { item in
        switch item {
        case .standalone(let row):
          guard let label = labels[row.id] else { return item }
          return .standalone(
            DiveLogbookRowDisplayData(
              id: row.id,
              activityKind: row.activityKind,
              displayName: row.displayName,
              diveNumberLabel: label,
              diveNumberLeadingSymbolName: row.diveNumberLeadingSymbolName,
              detailLine: row.detailLine,
              showsDuplicateHint: row.showsDuplicateHint,
              previewMediaPhotoID: row.previewMediaPhotoID,
              previewMediaIsSnorkel: row.previewMediaIsSnorkel,
              startTime: row.startTime
            )
          )
        case .tripGroup(let group):
          let dives = group.dives.map { row in
            DiveLogbookRowDisplayData(
              id: row.id,
              activityKind: row.activityKind,
              displayName: row.displayName,
              diveNumberLabel: labels[row.id] ?? row.diveNumberLabel,
              diveNumberLeadingSymbolName: row.diveNumberLeadingSymbolName,
              detailLine: row.detailLine,
              showsDuplicateHint: row.showsDuplicateHint,
              previewMediaPhotoID: row.previewMediaPhotoID,
              previewMediaIsSnorkel: row.previewMediaIsSnorkel,
              startTime: row.startTime
            )
          }
          return .tripGroup(
            LogbookTripGroupDisplayData(
              tripID: group.tripID,
              title: group.title,
              dateRangeLine: group.dateRangeLine,
              dives: dives,
              sortTime: group.sortTime,
              accentColorIndex: group.accentColorIndex
            )
          )
        }
      }
    )
  }
}

enum LogbookTripGroupingSync {
    /// Changes when owner trips or dive ↔ trip links change — drives logbook cache refresh.
    @MainActor
    static func syncToken(ownerTrips: [DiveTrip], activities: [DiveActivity]) -> String {
        let tripPart = ownerTrips
            .map { "\($0.id.uuidString):\($0.activityLinks.count)" }
            .sorted()
            .joined(separator: ",")
        let linkPart = activities
            .flatMap { activity in
                activity.tripActivityLinks.compactMap { link -> String? in
                    guard let tripID = link.trip?.id ?? link.tripID else { return nil }
                    return "\(activity.id.uuidString)>\(tripID.uuidString)"
                }
            }
            .sorted()
            .joined(separator: ",")
        return "\(tripPart)|\(linkPart)"
    }
}

enum LogbookTripSnapshotSeeding {
    @MainActor
    static func tripSeeds(
        from activities: [DiveActivity],
        ownerTrips: [DiveTrip] = []
    ) -> [LogbookTripSnapshotSeed] {
        var tripsByID: [UUID: DiveTrip] = [:]
        for trip in ownerTrips {
            tripsByID[trip.id] = trip
        }
        for activity in activities {
            for link in activity.tripActivityLinks {
                guard let trip = link.trip else { continue }
                tripsByID[trip.id] = trip
            }
        }
        return tripsByID.values.map { trip in
            LogbookTripSnapshotSeed(
                tripID: trip.id,
                displayTitle: trip.displayTitle,
                startDate: trip.startDate,
                endDate: trip.endDate
            )
        }
    }

    @MainActor
    static func primaryLinkedTripID(for activity: DiveActivity) -> UUID? {
        activity.tripActivityLinks
            .compactMap(\.trip)
            .max(by: { lhs, rhs in
                if lhs.startDate != rhs.startDate { return lhs.startDate < rhs.startDate }
                return lhs.createdAt < rhs.createdAt
            })?
            .id
    }
}
