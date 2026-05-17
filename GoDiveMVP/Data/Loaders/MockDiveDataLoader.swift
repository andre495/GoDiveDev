import Foundation

/// Loads `[DiveActivityDTO]` from a JSON file in the app bundle. Used only for mock seeding, not live imports.
enum MockDiveDataLoader {
    static func loadActivities(
        resourceName: String,
        resourceExtension: String = "json",
        bundle: Bundle = .main
    ) throws -> [DiveActivityDTO] {
        guard let fileURL = bundle.url(forResource: resourceName, withExtension: resourceExtension) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([DiveActivityDTO].self, from: data)
    }

    /// Loads `[DiveSiteDTO]` from a JSON file in the app bundle (mock catalog only).
    static func loadDiveSites(
        resourceName: String,
        resourceExtension: String = "json",
        bundle: Bundle = .main
    ) throws -> [DiveSiteDTO] {
        guard let fileURL = bundle.url(forResource: resourceName, withExtension: resourceExtension) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        return try decoder.decode([DiveSiteDTO].self, from: data)
    }
}
