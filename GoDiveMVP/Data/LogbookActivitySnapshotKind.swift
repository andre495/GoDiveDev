import Foundation

/// Logbook row activity kind (dives vs snorkel sessions).
enum LogbookActivitySnapshotKind: String, Sendable, Equatable {
    case scubaDive
    case snorkel
}
