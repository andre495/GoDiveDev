import Foundation
import SwiftData

/// Launch / idle catalog CDN refresh: Marine Life SwiftData upsert + OpenDiveMap reference disk cache.
enum CatalogCDNRefresh: Sendable {
    nonisolated static let appliedCatalogVersionDefaultsKey = "godive.catalogCDN.appliedCatalogVersion"

    enum Outcome: Equatable, Sendable {
        case skippedNotConfigured
        case skippedUpToDate(appliedVersion: Int)
        case skippedAppVersionTooLow(minimum: String)
        case skippedMissingPayloads
        case skippedChecksumMismatch
        case applied(catalogVersion: Int, marineLifeUpserted: Int, marineLifePruned: Int, diveSitesStored: Bool)
        case failed(String)
    }

    /// Soft-fail refresh. Bundled seed / bundled OpenDiveMap remain authoritative when this skips or fails.
    @discardableResult
    static func refreshIfNeeded(
        modelContext: ModelContext,
        baseURL: URL? = CatalogCDNSecretsBootstrap.loadManifestBaseURL(),
        appVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0",
        userDefaults: UserDefaults = .standard,
        session: URLSession? = nil,
        fileManager: FileManager = .default
    ) async -> Outcome {
        guard let baseURL else { return .skippedNotConfigured }

        let applied = userDefaults.integer(forKey: appliedCatalogVersionDefaultsKey)
        let resolvedSession = session ?? CatalogCDNSessionFactory.makeSession(forBaseURL: baseURL)

        do {
            let (manifest, _) = try await CatalogCDNClient.fetchManifest(baseURL: baseURL, session: resolvedSession)
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

            let marinePayload = validFullPayload(manifest.marineLife)
            let sitesPayload = validFullPayload(manifest.diveSites)
            guard marinePayload != nil || sitesPayload != nil else {
                return .skippedMissingPayloads
            }

            var marineUpserted = 0
            var marinePruned = 0
            if let marinePayload {
                let payload = try await CatalogCDNClient.fetchPayload(
                    baseURL: baseURL,
                    relativePath: marinePayload.path,
                    session: resolvedSession
                )
                guard CatalogCDNChecksum.matches(data: payload, expectedHex: marinePayload.sha256) else {
                    GoDiveSecurityEvent.record(.cdnChecksumMismatch, detail: "marineLife")
                    return .skippedChecksumMismatch
                }
                let dtos = try JSONDecoder().decode([MarineLifeDTO].self, from: payload)
                let upsert = try MarineLifeCatalogUpsert.apply(dtos: dtos, modelContext: modelContext)
                marineUpserted = upsert.upsertedCount
                marinePruned = upsert.prunedCount
            }

            var diveSitesStored = false
            if let sitesPayload {
                let payload = try await CatalogCDNClient.fetchPayload(
                    baseURL: baseURL,
                    relativePath: sitesPayload.path,
                    session: resolvedSession
                )
                guard CatalogCDNChecksum.matches(data: payload, expectedHex: sitesPayload.sha256) else {
                    GoDiveSecurityEvent.record(.cdnChecksumMismatch, detail: "diveSites")
                    return .skippedChecksumMismatch
                }
                // Validate OpenDiveMap snapshot shape before replacing the disk cache.
                let decoded = try JSONDecoder().decode([DiveSiteReferenceSnapshot].self, from: payload)
                guard !decoded.isEmpty else {
                    return .skippedMissingPayloads
                }
                try DiveSiteReferenceCDNCache.store(data: payload, fileManager: fileManager)
                diveSitesStored = true
            }

            userDefaults.set(manifest.catalogVersion, forKey: appliedCatalogVersionDefaultsKey)
            return .applied(
                catalogVersion: manifest.catalogVersion,
                marineLifeUpserted: marineUpserted,
                marineLifePruned: marinePruned,
                diveSitesStored: diveSitesStored
            )
        } catch {
            GoDiveSecurityEvent.record(.cdnRefreshFailed, detail: "fetchOrDecode")
            return .failed("Catalog refresh failed.")
        }
    }

    /// Compatibility wrapper for Marine Life–only call sites / older tests.
    @discardableResult
    static func refreshMarineLifeIfNeeded(
        modelContext: ModelContext,
        baseURL: URL? = CatalogCDNSecretsBootstrap.loadManifestBaseURL(),
        appVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0",
        userDefaults: UserDefaults = .standard,
        session: URLSession? = nil
    ) async -> Outcome {
        await refreshIfNeeded(
            modelContext: modelContext,
            baseURL: baseURL,
            appVersion: appVersion,
            userDefaults: userDefaults,
            session: session
        )
    }

    nonisolated private static func validFullPayload(
        _ payload: CatalogCDNManifest.CatalogPayload?
    ) -> CatalogCDNManifest.CatalogPayload? {
        guard let payload,
              payload.format.lowercased() == "full",
              CatalogCDNPathValidation.isAllowedRelativePath(payload.path)
        else {
            return nil
        }
        return payload
    }

    #if DEBUG
    static func resetAppliedVersionForTesting(userDefaults: UserDefaults = .standard) {
        userDefaults.removeObject(forKey: appliedCatalogVersionDefaultsKey)
    }
    #endif
}
