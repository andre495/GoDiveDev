import CloudKit
import CoreData
import Foundation
import os
import SwiftData

/// On-disk dual-store layout and container factory.
///
/// Phase 2: production **user** store prefers private CloudKit; **user-local** (profile points),
/// catalog, and diagnostics stay `.none`.
/// If CloudKit open fails, opens **local-only on the existing files** (never deletes the dive log /
/// signed-in profile). After a fallback, sticky local-only skips CloudKit on later launches until
/// the open-policy version bumps (schema fix) or the user resets the app container.
enum AppSwiftDataDualStoreFactory {

    nonisolated static let userStoreName = "GoDiveUser"
    nonisolated static let userLocalStoreName = "GoDiveUserLocal"
    nonisolated static let catalogStoreName = "GoDiveCatalog"
    nonisolated static let diagnosticsStoreName = "GoDiveDiagnostics"
    nonisolated static let cloudKitDiagnosticsFileName = "cloudkit-open-diagnostics.txt"
    nonisolated static let lastCloudKitFallbackErrorDefaultsKey = "godive.dualStore.cloudKitFallbackError"
    nonisolated static let lastCloudKitSyncEnabledDefaultsKey = "godive.dualStore.cloudKitSyncEnabled"
    /// Bumped when CloudKit open policy / schema compatibility changes so sticky local can clear once.
    nonisolated static let cloudKitOpenPolicyVersionKey = "godive.dualStore.cloudKitOpenPolicyVersion"
    /// One-shot: park existing local-only dual files and create a fresh CloudKit-backed trio.
    nonisolated static let recreateDualStoresForCloudKitDefaultsKey = "godive.dualStore.recreateForCloudKit"
    /// User tapped **Reconnect iCloud dive log** — clear sticky local skip on next cold start.
    nonisolated static let cloudKitUserRequestedReconnectDefaultsKey = "godive.dualStore.cloudKitUserRequestedReconnect"
    /// Prior session had private sync off and an empty on-device log — retry CloudKit once on next launch.
    nonisolated static let cloudKitRetryEmptyLocalLogDefaultsKey = "godive.dualStore.cloudKitRetryEmptyLocalLog"
    /// v7: **`DiveProfilePoint`** moves to local-only store (unstick CloudKit export backlog).
    /// v8: **`SnorkelActivity.owner`** gained its required CloudKit inverse on **`UserProfile`** —
    /// clears sticky local-only once so devices that fell back retry CloudKit with the fixed schema.
    nonisolated static let cloudKitOpenPolicyVersion = 8

    /// Test hook — when set, replaces the private user CloudKit database target for open attempts.
    nonisolated(unsafe) static var userCloudKitDatabaseOverrideForTests: ModelConfiguration.CloudKitDatabase?

    /// Test hook — when **`true`**, CloudKit user open throws so the local fallback path can be asserted.
    nonisolated(unsafe) static var forceUserCloudKitOpenFailureForTests = false

    struct Stores {
        let container: ModelContainer
        let userConfiguration: ModelConfiguration
        let userLocalConfiguration: ModelConfiguration
        let catalogConfiguration: ModelConfiguration
        let diagnosticsConfiguration: ModelConfiguration
        let rootDirectory: URL?
        let enableUserCloudKitSync: Bool
        /// True when CloudKit was requested but open fell back to local-only.
        let didFallBackFromCloudKit: Bool
    }

    /// Whether production should attempt private CloudKit on this launch.
    ///
    /// Sticky **`lastCloudKitSyncEnabledDefaultsKey == false`** after a prior fallback keeps the
    /// existing local store (and session) intact instead of re-trying CloudKit every cold start.
    nonisolated static func shouldAttemptUserCloudKitSync(
        requested: Bool,
        defaults: UserDefaults = .standard
    ) -> Bool {
        guard requested else { return false }
        migrateCloudKitOpenPolicyIfNeeded(defaults: defaults)
        if defaults.object(forKey: lastCloudKitSyncEnabledDefaultsKey) as? Bool == false {
            if defaults.bool(forKey: cloudKitUserRequestedReconnectDefaultsKey)
                || defaults.bool(forKey: cloudKitRetryEmptyLocalLogDefaultsKey)
            {
                defaults.set(false, forKey: cloudKitUserRequestedReconnectDefaultsKey)
                defaults.set(false, forKey: cloudKitRetryEmptyLocalLogDefaultsKey)
                defaults.removeObject(forKey: lastCloudKitSyncEnabledDefaultsKey)
                defaults.removeObject(forKey: lastCloudKitFallbackErrorDefaultsKey)
                defaults.set(true, forKey: recreateDualStoresForCloudKitDefaultsKey)
                return true
            }
            return false
        }
        return true
    }

    /// Clears sticky local-only skip so the next launch opens a fresh CloudKit-backed user store.
    nonisolated static func scheduleReconnectPrivateCloudKitOnNextLaunch(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: cloudKitUserRequestedReconnectDefaultsKey)
        defaults.set(true, forKey: recreateDualStoresForCloudKitDefaultsKey)
    }

    /// When the on-device log is empty but iCloud may still hold data, retry CloudKit on next cold start.
    nonisolated static func scheduleRetryPrivateCloudKitAfterEmptyLocalLog(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: cloudKitRetryEmptyLocalLogDefaultsKey)
    }

    nonisolated static func lastCloudKitFallbackErrorMessage(defaults: UserDefaults = .standard) -> String? {
        let raw = defaults.string(forKey: lastCloudKitFallbackErrorDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw, !raw.isEmpty else { return nil }
        return raw
    }

    /// Clears sticky local-only once when **`cloudKitOpenPolicyVersion`** advances.
    ///
    /// **v7+** always schedules a one-shot **rename-aside** so CloudKit can open a fresh user store
    /// without the **`DiveProfilePoint`** backlog. Sticky-local devices also clear sticky keys.
    nonisolated static func migrateCloudKitOpenPolicyIfNeeded(defaults: UserDefaults = .standard) {
        let stored = defaults.integer(forKey: cloudKitOpenPolicyVersionKey)
        guard stored < cloudKitOpenPolicyVersion else { return }
        let hadStickyLocal =
            defaults.object(forKey: lastCloudKitSyncEnabledDefaultsKey) as? Bool == false
        if hadStickyLocal {
            defaults.removeObject(forKey: lastCloudKitSyncEnabledDefaultsKey)
            defaults.removeObject(forKey: lastCloudKitFallbackErrorDefaultsKey)
        }
        let requiresFreshCloudKitStore = stored < 7 && cloudKitOpenPolicyVersion >= 7
        if requiresFreshCloudKitStore || hadStickyLocal {
            defaults.set(true, forKey: recreateDualStoresForCloudKitDefaultsKey)
        }
        defaults.set(cloudKitOpenPolicyVersion, forKey: cloudKitOpenPolicyVersionKey)
    }

    /// Parks dual store files as **`*.pre-cloudkit-vN`** (and SQLite sidecars) so a fresh CloudKit
    /// store can be created. Idempotent if already parked.
    nonisolated static func renameDualStoreFilesAsideForCloudKit(in rootDirectory: URL) {
        let fm = FileManager.default
        let stamp = "pre-cloudkit-v\(cloudKitOpenPolicyVersion)"
        for name in [userStoreName, userLocalStoreName, catalogStoreName, diagnosticsStoreName] {
            let base = storeURL(named: name, rootDirectory: rootDirectory)
            for suffix in ["", "-shm", "-wal"] {
                let url = URL(fileURLWithPath: base.path + suffix)
                guard fm.fileExists(atPath: url.path) else { continue }
                let parked = URL(fileURLWithPath: url.path + ".\(stamp)")
                try? fm.removeItem(at: parked)
                try? fm.moveItem(at: url, to: parked)
            }
        }
    }

    /// In-memory split stores — CloudKit always off (unit tests / fixtures).
    nonisolated static func makeInMemorySplitContainer() throws -> Stores {
        try makeSplitContainer(
            isStoredInMemoryOnly: true,
            rootDirectory: nil,
            enableUserCloudKitSync: false
        )
    }

    /// On-disk split stores under **`rootDirectory`** (defaults to Application Support / GoDiveMVP).
    ///
    /// - **`enableUserCloudKitSync: true`** — Phase 2 production user mirroring (falls back to local on failure **without deleting stores**).
    /// - **`false`** — tests, or forced offline-only open.
    nonisolated static func makeOnDiskSplitContainer(
        rootDirectory: URL? = nil,
        enableUserCloudKitSync: Bool = true,
        defaults: UserDefaults = .standard
    ) throws -> Stores {
        let root = try rootDirectory ?? defaultRootDirectory()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let attemptCloudKit = shouldAttemptUserCloudKitSync(
            requested: enableUserCloudKitSync,
            defaults: defaults
        )

        var shouldMigrateFromParkedUserStore = false
        if attemptCloudKit,
           defaults.bool(forKey: recreateDualStoresForCloudKitDefaultsKey),
           dualStoreFilesExist(in: root)
        {
            writeCloudKitDiagnostics(
                root: root,
                lines: [
                    "result=rename-aside-for-fresh-cloudkit",
                    "action=renameDualStoreFilesAsideForCloudKit",
                    "reason=policyBumpExcludeProfilePoints",
                    "container=\(AppSwiftDataCloudKitCompatibility.iCloudContainerIdentifier)",
                ]
            )
            renameDualStoreFilesAsideForCloudKit(in: root)
            defaults.set(false, forKey: recreateDualStoresForCloudKitDefaultsKey)
            shouldMigrateFromParkedUserStore = true
            // Parked store no longer matches the persisted profile id.
            AppLaunchSessionRestorePresentation.clearPersistedProfileID(userDefaults: defaults)
        } else if defaults.bool(forKey: recreateDualStoresForCloudKitDefaultsKey) {
            defaults.set(false, forKey: recreateDualStoresForCloudKitDefaultsKey)
        }

        if enableUserCloudKitSync, !attemptCloudKit {
            writeCloudKitDiagnostics(
                root: root,
                lines: [
                    "result=sticky-local-skip-cloudkit",
                    "enableUserCloudKitSync=false",
                    "reason=priorCloudKitFallback",
                    "container=\(AppSwiftDataCloudKitCompatibility.iCloudContainerIdentifier)",
                ]
            )
            let local = try makeSplitContainer(
                isStoredInMemoryOnly: false,
                rootDirectory: root,
                enableUserCloudKitSync: false
            )
            return Stores(
                container: local.container,
                userConfiguration: local.userConfiguration,
                userLocalConfiguration: local.userLocalConfiguration,
                catalogConfiguration: local.catalogConfiguration,
                diagnosticsConfiguration: local.diagnosticsConfiguration,
                rootDirectory: local.rootDirectory,
                enableUserCloudKitSync: false,
                didFallBackFromCloudKit: true
            )
        }

        do {
            if forceUserCloudKitOpenFailureForTests, attemptCloudKit {
                throw CloudKitOpenTestFailure.forced
            }
            let stores = try makeSplitContainer(
                isStoredInMemoryOnly: false,
                rootDirectory: root,
                enableUserCloudKitSync: attemptCloudKit
            )
            let migrated = try migrateFromParkedUserStoreIfNeeded(
                shouldMigrate: shouldMigrateFromParkedUserStore,
                root: root,
                container: stores.container
            )
            if attemptCloudKit {
                var lines = [
                    "result=success",
                    "enableUserCloudKitSync=true",
                    "container=\(AppSwiftDataCloudKitCompatibility.iCloudContainerIdentifier)",
                    "userStore=\(storeURL(named: userStoreName, rootDirectory: root).path)",
                    "userLocalStore=\(storeURL(named: userLocalStoreName, rootDirectory: root).path)",
                ]
                if let migrated {
                    lines.append(contentsOf: [
                        "migratedFromParked=true",
                        "copiedDives=\(migrated.diveActivityCount)",
                        "copiedProfiles=\(migrated.userProfileCount)",
                        "totalInserted=\(migrated.totalInsertedCount)",
                    ])
                }
                writeCloudKitDiagnostics(root: root, lines: lines)
                defaults.set(true, forKey: lastCloudKitSyncEnabledDefaultsKey)
                defaults.removeObject(forKey: lastCloudKitFallbackErrorDefaultsKey)
            }
            return stores
        } catch {
            guard attemptCloudKit else { throw error }
            let firstError = describeError(error)
            Logger(subsystem: "PrimoSoftware.GoDiveMVP", category: "DualStore")
                .error(
                    "User CloudKit store open failed; preserving existing dual stores and opening local-only. error=\(firstError, privacy: .public)"
                )

            // Never wipe dual store files here — that deleted UserProfile + dives and forced a
            // "new account" sign-in after force-quit when CloudKit open failed on relaunch.
            writeCloudKitDiagnostics(
                root: root,
                lines: [
                    "result=fallback-local-preserve-existing",
                    "attempt1Error=\(firstError)",
                    "action=openLocalOnlyWithoutWipe",
                    "dualStoreFilesExisted=\(dualStoreFilesExist(in: root))",
                    "pendingParkedMigration=\(shouldMigrateFromParkedUserStore)",
                    "policyVersion=\(cloudKitOpenPolicyVersion)",
                    "container=\(AppSwiftDataCloudKitCompatibility.iCloudContainerIdentifier)",
                ]
            )
            defaults.set(false, forKey: lastCloudKitSyncEnabledDefaultsKey)
            defaults.set(firstError, forKey: lastCloudKitFallbackErrorDefaultsKey)

            if !forceUserCloudKitOpenFailureForTests {
                runCloudKitOpenProbes(rootDirectory: root)
            }

            let local = try makeSplitContainer(
                isStoredInMemoryOnly: false,
                rootDirectory: root,
                enableUserCloudKitSync: false
            )
            _ = try migrateFromParkedUserStoreIfNeeded(
                shouldMigrate: shouldMigrateFromParkedUserStore,
                root: root,
                container: local.container
            )
            return Stores(
                container: local.container,
                userConfiguration: local.userConfiguration,
                userLocalConfiguration: local.userLocalConfiguration,
                catalogConfiguration: local.catalogConfiguration,
                diagnosticsConfiguration: local.diagnosticsConfiguration,
                rootDirectory: local.rootDirectory,
                enableUserCloudKitSync: false,
                didFallBackFromCloudKit: true
            )
        }
    }

    @discardableResult
    nonisolated private static func migrateFromParkedUserStoreIfNeeded(
        shouldMigrate: Bool,
        root: URL,
        container: ModelContainer
    ) throws -> AppSwiftDataDualStoreMigrator.Result? {
        guard shouldMigrate else { return nil }
        return try AppSwiftDataDualStoreMigrator.migrateFromParkedPreCloudKitUserStore(
            rootDirectory: root,
            destinationContainer: container,
            policyVersion: cloudKitOpenPolicyVersion
        )
    }

    /// Appends iCloud account status for the shared container (call after launch; async-safe).
    static func appendCloudKitAccountStatusDiagnostics() async {
        guard let root = try? defaultRootDirectory() else { return }
        let container = CKContainer(
            identifier: AppSwiftDataCloudKitCompatibility.iCloudContainerIdentifier
        )
        let status: String
        do {
            let accountStatus = try await container.accountStatus()
            switch accountStatus {
            case .available: status = "available"
            case .noAccount: status = "noAccount"
            case .restricted: status = "restricted"
            case .couldNotDetermine: status = "couldNotDetermine"
            case .temporarilyUnavailable: status = "temporarilyUnavailable"
            @unknown default: status = "unknown(\(accountStatus.rawValue))"
            }
        } catch {
            status = "error:\(describeError(error))"
        }
        let path = root.appendingPathComponent(cloudKitDiagnosticsFileName)
        let existing = (try? String(contentsOf: path, encoding: .utf8)) ?? ""
        let line = "\naccountStatus=\(status)\ncheckedAt=\(ISO8601DateFormatter().string(from: Date()))\n"
        try? (existing + line).write(to: path, atomically: true, encoding: .utf8)
    }

    nonisolated private static func describeError(_ error: Error) -> String {
        let ns = error as NSError
        var parts = [
            "domain=\(ns.domain)",
            "code=\(ns.code)",
            "desc=\(ns.localizedDescription)",
        ]
        // Map known SwiftDataError static cases (NSError code alone is opaque).
        let known: [(String, SwiftDataError)] = [
            ("loadIssueModelContainer", .loadIssueModelContainer),
            ("modelValidationFailure", .modelValidationFailure),
            ("duplicateConfiguration", .duplicateConfiguration),
            ("configurationSchemaNotFoundInContainerSchema", .configurationSchemaNotFoundInContainerSchema),
            ("unknownSchema", .unknownSchema),
            ("backwardMigration", .backwardMigration),
        ]
        for (name, candidate) in known {
            if error as? SwiftDataError == candidate {
                parts.append("swiftDataCase=\(name)")
                break
            }
            if (candidate as NSError).code == ns.code,
               (candidate as NSError).domain == ns.domain
            {
                parts.append("swiftDataCase=\(name)")
                break
            }
        }
        let mirror = String(describing: error)
        parts.append("debugDescription=\(mirror)")
        if !ns.userInfo.isEmpty {
            let info = ns.userInfo.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: "; ")
            parts.append("userInfo={\(info)}")
        }
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError {
            parts.append(
                "underlying={domain=\(underlying.domain); code=\(underlying.code); desc=\(underlying.localizedDescription); userInfo=\(underlying.userInfo)}"
            )
        }
        if let detailed = ns.userInfo["NSDetailedErrors"] as? [NSError], !detailed.isEmpty {
            let details = detailed.enumerated().map { index, err in
                "[\(index)] domain=\(err.domain) code=\(err.code) desc=\(err.localizedDescription) userInfo=\(err.userInfo)"
            }.joined(separator: " || ")
            parts.append("detailedErrors={\(details)}")
        }
        // Core Data CloudKit validation often lands here.
        for key in ["reason", "NSLocalizedFailureReason", "NSDebugDescription", "message"] {
            if let value = ns.userInfo[key] {
                parts.append("\(key)=\(value)")
            }
        }
        return parts.joined(separator: " | ")
    }

    /// Probe CloudKit open shapes and append results (helps isolate multi-store vs schema failures).
    nonisolated static func runCloudKitOpenProbes(rootDirectory: URL) {
        var lines: [String] = ["--- probes ---"]
        let userSchema = Schema(AppSwiftDataStorePartition.userModelTypes)
        let fullSchema = Schema(AppSwiftDataStorePartition.allModelTypes)
        let probeRoot = rootDirectory.appendingPathComponent("CloudKitProbes", isDirectory: true)
        try? FileManager.default.createDirectory(at: probeRoot, withIntermediateDirectories: true)

        // Probe A: user models only + private CloudKit
        do {
            let url = probeRoot.appendingPathComponent("probe-user-only.store")
            try? FileManager.default.removeItem(at: url)
            let config = ModelConfiguration(
                "ProbeUserOnly",
                schema: userSchema,
                url: url,
                cloudKitDatabase: AppSwiftDataCloudKitCompatibility.privateUserCloudKitDatabase
            )
            _ = try ModelContainer(for: userSchema, configurations: [config])
            lines.append("probeA_userOnlyCloudKit=success")
        } catch {
            lines.append("probeA_userOnlyCloudKit=FAIL \(describeError(error))")
        }

        // Probe B: dual split with user CloudKit (same as production)
        do {
            let userURL = probeRoot.appendingPathComponent("probe-dual-user.store")
            let catalogURL = probeRoot.appendingPathComponent("probe-dual-catalog.store")
            let diagnosticsURL = probeRoot.appendingPathComponent("probe-dual-diagnostics.store")
            for url in [userURL, catalogURL, diagnosticsURL] {
                try? FileManager.default.removeItem(at: url)
            }
            let userConfig = ModelConfiguration(
                "ProbeDualUser",
                schema: userSchema,
                url: userURL,
                cloudKitDatabase: AppSwiftDataCloudKitCompatibility.privateUserCloudKitDatabase
            )
            let catalogConfig = ModelConfiguration(
                "ProbeDualCatalog",
                schema: Schema(AppSwiftDataStorePartition.catalogModelTypes),
                url: catalogURL,
                cloudKitDatabase: .none
            )
            let diagnosticsConfig = ModelConfiguration(
                "ProbeDualDiagnostics",
                schema: Schema(AppSwiftDataStorePartition.diagnosticsModelTypes),
                url: diagnosticsURL,
                cloudKitDatabase: .none
            )
            _ = try ModelContainer(
                for: fullSchema,
                configurations: userConfig, catalogConfig, diagnosticsConfig
            )
            lines.append("probeB_dualUserCloudKit=success")
        } catch {
            lines.append("probeB_dualUserCloudKit=FAIL \(describeError(error))")
        }

        // Probe C: user only local (control)
        do {
            let url = probeRoot.appendingPathComponent("probe-user-local.store")
            try? FileManager.default.removeItem(at: url)
            let config = ModelConfiguration(
                "ProbeUserLocal",
                schema: userSchema,
                url: url,
                cloudKitDatabase: .none
            )
            _ = try ModelContainer(for: userSchema, configurations: [config])
            lines.append("probeC_userOnlyLocal=success")
        } catch {
            lines.append("probeC_userOnlyLocal=FAIL \(describeError(error))")
        }

        // Probe D: Core Data CloudKit load — surfaces the real validation reason SwiftData hides.
        lines.append(contentsOf: runCoreDataCloudKitValidationProbe(probeRoot: probeRoot))

        // Probe E: SwiftData + .automatic (entitlement-inferred container)
        do {
            let url = probeRoot.appendingPathComponent("probe-user-automatic.store")
            try? FileManager.default.removeItem(at: url)
            let config = ModelConfiguration(
                "ProbeUserAutomatic",
                schema: userSchema,
                url: url,
                cloudKitDatabase: .automatic
            )
            _ = try ModelContainer(for: userSchema, configurations: [config])
            lines.append("probeE_userOnlyAutomaticCloudKit=success")
        } catch {
            lines.append("probeE_userOnlyAutomaticCloudKit=FAIL \(describeError(error))")
        }

        // Probe F: minimal schema (UserProfile only) + private CloudKit
        do {
            let minimalSchema = Schema([UserProfile.self])
            let url = probeRoot.appendingPathComponent("probe-profile-only.store")
            try? FileManager.default.removeItem(at: url)
            let config = ModelConfiguration(
                "ProbeProfileOnly",
                schema: minimalSchema,
                url: url,
                cloudKitDatabase: AppSwiftDataCloudKitCompatibility.privateUserCloudKitDatabase
            )
            _ = try ModelContainer(for: minimalSchema, configurations: [config])
            lines.append("probeF_userProfileOnlyCloudKit=success")
        } catch {
            lines.append("probeF_userProfileOnlyCloudKit=FAIL \(describeError(error))")
        }

        lines.append("policyVersion=\(cloudKitOpenPolicyVersion)")

        let path = rootDirectory.appendingPathComponent(cloudKitDiagnosticsFileName)
        let existing = (try? String(contentsOf: path, encoding: .utf8)) ?? ""
        try? (existing + "\n" + lines.joined(separator: "\n") + "\n")
            .write(to: path, atomically: true, encoding: .utf8)
    }

    /// Uses **`NSPersistentCloudKitContainer`** so CloudKit schema validation errors appear in diagnostics.
    nonisolated private static func runCoreDataCloudKitValidationProbe(probeRoot: URL) -> [String] {
        let url = probeRoot.appendingPathComponent("probe-coredata-ck.store")
        try? FileManager.default.removeItem(at: url)
        for suffix in ["-shm", "-wal"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + suffix))
        }

        guard let mom = NSManagedObjectModel.makeManagedObjectModel(
            for: AppSwiftDataStorePartition.userModelTypes
        ) else {
            return ["probeD_coreDataCloudKit=FAIL makeManagedObjectModelReturnedNil"]
        }

        let desc = NSPersistentStoreDescription(url: url)
        desc.shouldAddStoreAsynchronously = false
        desc.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: AppSwiftDataCloudKitCompatibility.iCloudContainerIdentifier
        )

        let container = NSPersistentCloudKitContainer(
            name: "GoDiveUserCloudKitProbe",
            managedObjectModel: mom
        )
        container.persistentStoreDescriptions = [desc]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            return ["probeD_coreDataCloudKit=FAIL load \(describeError(loadError))"]
        }
        do {
            try container.initializeCloudKitSchema(options: [])
            if let store = container.persistentStoreCoordinator.persistentStores.first {
                try container.persistentStoreCoordinator.remove(store)
            }
            return ["probeD_coreDataCloudKit=success"]
        } catch {
            if let store = container.persistentStoreCoordinator.persistentStores.first {
                try? container.persistentStoreCoordinator.remove(store)
            }
            return ["probeD_coreDataCloudKit=FAIL initializeSchema \(describeError(error))"]
        }
    }

    nonisolated private static func writeCloudKitDiagnostics(root: URL, lines: [String]) {
        let path = root.appendingPathComponent(cloudKitDiagnosticsFileName)
        let body = (lines + ["writtenAt=\(ISO8601DateFormatter().string(from: Date()))"])
            .joined(separator: "\n")
        try? body.write(to: path, atomically: true, encoding: .utf8)
        GoDiveFileBackupPolicy.excludeFromBackupIfExists(path)
    }

    nonisolated static func defaultRootDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base.appendingPathComponent("GoDiveMVP", isDirectory: true)
    }

    nonisolated static func storeURL(named name: String, rootDirectory: URL) -> URL {
        rootDirectory.appendingPathComponent("\(name).store", isDirectory: false)
    }

    nonisolated static func dualStoreFilesExist(in rootDirectory: URL) -> Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: storeURL(named: userStoreName, rootDirectory: rootDirectory).path)
            && fm.fileExists(atPath: storeURL(named: catalogStoreName, rootDirectory: rootDirectory).path)
            && fm.fileExists(atPath: storeURL(named: diagnosticsStoreName, rootDirectory: rootDirectory).path)
    }

    /// Deletes dual store files (and SQLite sidecars) under **`rootDirectory`**.
    nonisolated static func removeDualStoreFiles(in rootDirectory: URL) throws {
        let fm = FileManager.default
        for name in [userStoreName, userLocalStoreName, catalogStoreName, diagnosticsStoreName] {
            let base = storeURL(named: name, rootDirectory: rootDirectory)
            for suffix in ["", "-shm", "-wal"] {
                let url = URL(fileURLWithPath: base.path + suffix)
                if fm.fileExists(atPath: url.path) {
                    try fm.removeItem(at: url)
                }
            }
        }
    }

    /// Dive count in the legacy unified **`default.store`** (0 if missing).
    nonisolated static func legacyUnifiedDiveCount() throws -> Int {
        guard legacyUnifiedStoreExists() else { return 0 }
        let schema = Schema(AppSwiftDataStorePartition.allModelTypes)
        let configuration = ModelConfiguration(
            schema: schema,
            url: legacyUnifiedStoreURL(),
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        return try context.fetchCount(FetchDescriptor<DiveActivity>())
    }

    /// Dive count in an existing on-disk user store (0 if the dual trio is missing).
    ///
    /// Avoids opening a live **`ModelContainer`** for tiny empty dual files (~307 KB) so remigration
    /// can delete them without store-lock races.
    nonisolated static func dualUserDiveCount(in rootDirectory: URL) throws -> Int {
        guard dualStoreFilesExist(in: rootDirectory) else { return 0 }
        let userURL = storeURL(named: userStoreName, rootDirectory: rootDirectory)
        let bytes: UInt64 = {
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: userURL.path),
                  let size = attrs[.size] as? UInt64
            else { return 0 }
            return size
        }()
        // Fresh empty dual user stores are ~307_200 bytes; treat small files as empty.
        if bytes > 0, bytes < 500_000 {
            return 0
        }
        let stores = try makeOnDiskSplitContainer(
            rootDirectory: rootDirectory,
            enableUserCloudKitSync: false
        )
        let context = ModelContext(stores.container)
        return try context.fetchCount(FetchDescriptor<DiveActivity>())
    }

    /// Legacy unified store URL — the pre–Phase 1c on-disk file at Application Support / **`default.store`**.
    ///
    /// Uses an explicit path (not bare **`ModelConfiguration().url`**) so detection/migration match the
    /// store the app actually wrote before the dual-store split.
    nonisolated static func legacyUnifiedStoreURL() -> URL {
        do {
            let appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            return appSupport.appendingPathComponent("default.store", isDirectory: false)
        } catch {
            return ModelConfiguration(
                schema: Schema(AppSwiftDataStorePartition.allModelTypes),
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            ).url
        }
    }

    nonisolated static func legacyUnifiedStoreExists() -> Bool {
        FileManager.default.fileExists(atPath: legacyUnifiedStoreURL().path)
    }

    nonisolated static func legacyUnifiedStoreByteCount() -> UInt64 {
        let path = legacyUnifiedStoreURL().path
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? UInt64
        else { return 0 }
        return size
    }

    /// Renames legacy unified store files to **`*.migrated-bak`** (idempotent if already moved).
    nonisolated static func renameLegacyUnifiedStoreAside() {
        AppSwiftDataDualStoreMigrator.renameLegacyStoreAsideForBootstrap(legacyUnifiedStoreURL())
    }

    private nonisolated static func makeSplitContainer(
        isStoredInMemoryOnly: Bool,
        rootDirectory: URL?,
        enableUserCloudKitSync: Bool
    ) throws -> Stores {
        let userSchema = Schema(AppSwiftDataStorePartition.userModelTypes)
        let userLocalSchema = Schema(AppSwiftDataStorePartition.userLocalModelTypes)
        let catalogSchema = Schema(AppSwiftDataStorePartition.catalogModelTypes)
        let diagnosticsSchema = Schema(AppSwiftDataStorePartition.diagnosticsModelTypes)

        let userCloudKit: ModelConfiguration.CloudKitDatabase =
            (!isStoredInMemoryOnly && enableUserCloudKitSync)
                ? (userCloudKitDatabaseOverrideForTests
                    ?? AppSwiftDataCloudKitCompatibility.privateUserCloudKitDatabase)
                : AppSwiftDataCloudKitCompatibility.localOnlyCloudKitDatabase

        let userConfiguration: ModelConfiguration
        let userLocalConfiguration: ModelConfiguration
        let catalogConfiguration: ModelConfiguration
        let diagnosticsConfiguration: ModelConfiguration

        if isStoredInMemoryOnly {
            userConfiguration = ModelConfiguration(
                userStoreName,
                schema: userSchema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: userCloudKit
            )
            userLocalConfiguration = ModelConfiguration(
                userLocalStoreName,
                schema: userLocalSchema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: AppSwiftDataCloudKitCompatibility.localOnlyCloudKitDatabase
            )
            catalogConfiguration = ModelConfiguration(
                catalogStoreName,
                schema: catalogSchema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: AppSwiftDataCloudKitCompatibility.localOnlyCloudKitDatabase
            )
            diagnosticsConfiguration = ModelConfiguration(
                diagnosticsStoreName,
                schema: diagnosticsSchema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: AppSwiftDataCloudKitCompatibility.localOnlyCloudKitDatabase
            )
        } else {
            let root = try rootDirectory ?? defaultRootDirectory()
            userConfiguration = ModelConfiguration(
                userStoreName,
                schema: userSchema,
                url: storeURL(named: userStoreName, rootDirectory: root),
                cloudKitDatabase: userCloudKit
            )
            userLocalConfiguration = ModelConfiguration(
                userLocalStoreName,
                schema: userLocalSchema,
                url: storeURL(named: userLocalStoreName, rootDirectory: root),
                cloudKitDatabase: AppSwiftDataCloudKitCompatibility.localOnlyCloudKitDatabase
            )
            catalogConfiguration = ModelConfiguration(
                catalogStoreName,
                schema: catalogSchema,
                url: storeURL(named: catalogStoreName, rootDirectory: root),
                cloudKitDatabase: AppSwiftDataCloudKitCompatibility.localOnlyCloudKitDatabase
            )
            diagnosticsConfiguration = ModelConfiguration(
                diagnosticsStoreName,
                schema: diagnosticsSchema,
                url: storeURL(named: diagnosticsStoreName, rootDirectory: root),
                cloudKitDatabase: AppSwiftDataCloudKitCompatibility.localOnlyCloudKitDatabase
            )
            // Crash rows + open dumps stay out of device/iCloud backups (Phase 4).
            GoDiveFileBackupPolicy.excludeStoreFamilyFromBackup(
                baseStoreURL: storeURL(named: diagnosticsStoreName, rootDirectory: root)
            )
            GoDiveFileBackupPolicy.excludeFromBackupIfExists(
                root.appendingPathComponent(cloudKitDiagnosticsFileName)
            )
        }

        let fullSchema = Schema(AppSwiftDataStorePartition.allModelTypes)
        let container = try ModelContainer(
            for: fullSchema,
            configurations: userConfiguration, userLocalConfiguration, catalogConfiguration, diagnosticsConfiguration
        )
        return Stores(
            container: container,
            userConfiguration: userConfiguration,
            userLocalConfiguration: userLocalConfiguration,
            catalogConfiguration: catalogConfiguration,
            diagnosticsConfiguration: diagnosticsConfiguration,
            rootDirectory: rootDirectory,
            enableUserCloudKitSync: enableUserCloudKitSync && !isStoredInMemoryOnly,
            didFallBackFromCloudKit: false
        )
    }
}

/// Production dual-store bootstrap (Phase 2).
///
/// Opens **`GoDiveUser` / `GoDiveUserLocal` / `GoDiveCatalog` / `GoDiveDiagnostics`**. User store prefers private CloudKit
/// (falls back to local-only on open failure). **`DiveProfilePoint`** lives in **`GoDiveUserLocal`** (CloudKit off).
/// **Legacy unified `default.store` migration is out of
/// scope** for this development build — delete the app (or clear container data) for a clean dual
/// + CloudKit install. The object-by-object migrator remains in-tree for tests only.
enum AppSwiftDataDualStoreBootstrap {

    nonisolated static let migrationCompletedDefaultsKey = "godive.dualStoreMigration.v1.completed"

    struct OpenResult: Equatable, Sendable {
        var enableUserCloudKitSync: Bool
        var didFallBackFromCloudKit: Bool

        nonisolated init(
            enableUserCloudKitSync: Bool,
            didFallBackFromCloudKit: Bool = false
        ) {
            self.enableUserCloudKitSync = enableUserCloudKitSync
            self.didFallBackFromCloudKit = didFallBackFromCloudKit
        }
    }

    /// Production entry — dual stores; Phase 2 enables private CloudKit on the **user** store.
    ///
    /// Pass a custom **`rootDirectory`** (tests) to skip default Application Support / GoDiveMVP.
    /// When **`rootDirectory`** is set, user CloudKit defaults to **off** unless
    /// **`enableUserCloudKitSync`** is explicitly **`true`**.
    /// CloudKit open failures fall back to local-only **without deleting** existing dual stores.
    nonisolated static func openProductionContainer(
        defaults: UserDefaults = .standard,
        rootDirectory: URL? = nil,
        enableUserCloudKitSync: Bool? = nil
    ) throws -> (container: ModelContainer, openResult: OpenResult) {
        let usingCustomRoot = rootDirectory != nil
        let root = try rootDirectory ?? AppSwiftDataDualStoreFactory.defaultRootDirectory()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let syncUser = enableUserCloudKitSync ?? !usingCustomRoot

        let stores = try AppSwiftDataDualStoreFactory.makeOnDiskSplitContainer(
            rootDirectory: root,
            enableUserCloudKitSync: syncUser,
            defaults: defaults
        )
        defaults.set(true, forKey: migrationCompletedDefaultsKey)
            return (
            stores.container,
            OpenResult(
                enableUserCloudKitSync: stores.enableUserCloudKitSync,
                didFallBackFromCloudKit: stores.didFallBackFromCloudKit
            )
        )
    }
}

private enum CloudKitOpenTestFailure: Error {
    case forced
}
