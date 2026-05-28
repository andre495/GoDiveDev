import Foundation
import SwiftData

/// Create, fetch, and link **`ActivityTag`** rows for dives.
enum ActivityTagStore {

    nonisolated static let maxNameLength = 48

    nonisolated static func normalizedName(from raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .lowercased()
    }

    nonisolated static func displayName(from raw: String) -> String {
        let collapsed = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        guard !collapsed.isEmpty else { return "" }
        return String(collapsed.prefix(maxNameLength))
    }

    @MainActor
    static func sortedTags(on activity: DiveActivity) -> [ActivityTag] {
        activity.activityTags.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    @MainActor
    static func summaryLine(for activity: DiveActivity) -> String {
        let names = sortedTags(on: activity).map(\.name)
        return names.isEmpty ? "—" : names.joined(separator: ", ")
    }

    @MainActor
    static func fetchTags(
        ownerProfileID: UUID,
        modelContext: ModelContext
    ) throws -> [ActivityTag] {
        let descriptor = FetchDescriptor<ActivityTag>(
            predicate: #Predicate { $0.ownerProfileID == ownerProfileID },
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    @MainActor
    static func findOrCreateTag(
        rawName: String,
        ownerProfileID: UUID,
        modelContext: ModelContext
    ) throws -> ActivityTag? {
        let display = displayName(from: rawName)
        let normalized = normalizedName(from: display)
        guard !normalized.isEmpty else { return nil }

        if let existing = try fetchTag(
            normalizedName: normalized,
            ownerProfileID: ownerProfileID,
            modelContext: modelContext
        ) {
            return existing
        }

        let tag = ActivityTag(
            name: display,
            normalizedName: normalized,
            ownerProfileID: ownerProfileID
        )
        modelContext.insert(tag)
        return tag
    }

    @MainActor
    static func applyTag(_ tag: ActivityTag, to activity: DiveActivity) {
        guard !activity.activityTags.contains(where: { $0.id == tag.id }) else { return }
        activity.activityTags.append(tag)
    }

    @MainActor
    static func removeTag(_ tag: ActivityTag, from activity: DiveActivity) {
        activity.activityTags.removeAll { $0.id == tag.id }
    }

    @MainActor
    static func isApplied(_ tag: ActivityTag, on activity: DiveActivity) -> Bool {
        activity.activityTags.contains { $0.id == tag.id }
    }

    @MainActor
    private static func fetchTag(
        normalizedName: String,
        ownerProfileID: UUID,
        modelContext: ModelContext
    ) throws -> ActivityTag? {
        var descriptor = FetchDescriptor<ActivityTag>(
            predicate: #Predicate { tag in
                tag.ownerProfileID == ownerProfileID && tag.normalizedName == normalizedName
            }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
