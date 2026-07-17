import Foundation
import SwiftData

/// Launch / idle Phase 4 refresh: fetch CDN Marine Life when configured and newer than last applied.
enum CatalogCDNRefresh: Sendable {
    nonisolated static let appliedCatalogVersionDefaultsKey = "godive.catalogCDN.appliedCatalogVersion"

    enum Outcome: Equatable, Sendable {
        case skippedNotConfigured
        case skippedUpToDate(appliedVersion: Int)
        case skippedAppVersionTooLow(minimum: String)
        case skippedMissingMarineLifePayload
        case skippedChecksumMismatch
        case applied(catalogVersion: Int, upserted: Int, pruned: Int)
        case failed(String)
    }

    /// Soft-fail refresh. Bundled seed remains authoritative when this skips or fails.
    @discardableResult
    static func refreshMarineLifeIfNeeded(
        modelContext: ModelContext,
        baseURL: URL? = CatalogCDNSecretsBootstrap.loadManifestBaseURL(),
        appVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0",
        userDefaults: UserDefaults = .standard,
        session: URLSession = .shared
    ) async -> Outcome {
        guard let baseURL else { return .skippedNotConfigured }

        let applied = userDefaults.integer(forKey: appliedCatalogVersionDefaultsKey)

        do {
            let (manifest, _) = try await CatalogCDNClient.fetchManifest(baseURL: baseURL, session: session)
            guard CatalogCDNRefreshPolicy.meetsMinimumAppVersion(
                appVersion: appVersion,
                minimumAppVersion: manifest.minimumAppVersion
            ) else {
                return .skippedAppVersionTooLow(minimum: manifest.minimumAppVersion)
            }
            guard CatalogCDNRefreshPolicy.shouldApply(
                remoteCatalogVersion: manifest.catalogVersion,
                appliedCatalogVersion: applied
            ) else {
                return .skippedUpToDate(appliedVersion: applied)
            }
            guard let marineLife = manifest.marineLife,
                  marineLife.format.lowercased() == "full",
                  !marineLife.path.isEmpty
            else {
                return .skippedMissingMarineLifePayload
            }

            let payload = try await CatalogCDNClient.fetchPayload(
                baseURL: baseURL,
                relativePath: marineLife.path,
                session: session
            )
            guard CatalogCDNChecksum.matches(data: payload, expectedHex: marineLife.sha256) else {
                return .skippedChecksumMismatch
            }

            let dtos = try JSONDecoder().decode([MarineLifeDTO].self, from: payload)
            let upsert = try MarineLifeCatalogUpsert.apply(dtos: dtos, modelContext: modelContext)
            userDefaults.set(manifest.catalogVersion, forKey: appliedCatalogVersionDefaultsKey)
            return .applied(
                catalogVersion: manifest.catalogVersion,
                upserted: upsert.upsertedCount,
                pruned: upsert.prunedCount
            )
        } catch {
            return .failed(String(describing: error))
        }
    }

    #if DEBUG
    static func resetAppliedVersionForTesting(userDefaults: UserDefaults = .standard) {
        userDefaults.removeObject(forKey: appliedCatalogVersionDefaultsKey)
    }
    #endif
}
