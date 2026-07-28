import FirebaseFirestore
import Foundation

/// Friend-visible activity kind stored on **`sharedDives`** documents (dives + snorkels).
enum FriendSharedActivityKind: String, Sendable, Equatable {
    case scubaDive
    case snorkel
}

/// Builds Firestore-safe friend-visible dive projections from local dive snapshots.
enum GoDiveSharedDiveProjectionMapping: Sendable {
    nonisolated static let sharedDivesSubcollection = "sharedDives"
    nonisolated static let schemaVersion = 2
    /// Leave headroom under Firestore’s 1 MiB document limit.
    nonisolated static let maxProfileTrackBytes = 700_000
    nonisolated static let maxSwimTrackBytes = 700_000

    struct TaggedBuddySnapshot: Equatable, Sendable {
        var displayName: String
        var firebaseUID: String?
    }

    struct SightingSnapshot: Equatable, Sendable {
        var commonName: String
        var scientificName: String?
        var catalogUUID: String?
    }

    struct MediaPreviewSnapshot: Equatable, Sendable {
        var photoID: String
        var previewURL: String
    }

    struct DiveSnapshot: Equatable, Sendable {
        var id: UUID
        var activityKind: FriendSharedActivityKind = .scubaDive
        var startTime: Date
        var timeZoneOffsetSeconds: Int?
        var durationMinutes: Int
        var maxDepthMeters: Double
        var averageDepthMeters: Double?
        var bottomTimeSeconds: Int?
        var diveNumber: Int?
        var waterTempAvgCelsius: Double?
        var waterTempMinCelsius: Double?
        var waterTempMaxCelsius: Double?
        var siteName: String?
        var locationName: String?
        var region: String? = nil
        var country: String? = nil
        var swimDistanceMeters: Double? = nil
        var entryLatitude: Double?
        var entryLongitude: Double?
        var notes: String?
        var diveCurrentStrengthRaw: String?
        var surfaceCondition: String?
        var entryType: String?
        var diveVisibilityRaw: String?
        var diveOperatorName: String?
        var diveMasterName: String?
        var diveWaterTypeRaw: String?
        var diverWeightKilograms: Double?
        var tankMaterial: String?
        var tankVolumeDescription: String?
        var tankPressureStartPSI: Double?
        var tankPressureEndPSI: Double?
        var gasType: String?
        var oxygenMix: Double?
        var avgSAC: Double?
        var avgRMV: Double?
        var activityTagNames: [String]
        var sightings: [SightingSnapshot]
        var taggedBuddies: [TaggedBuddySnapshot]
        var equipmentSummary: [String]
        var profileTrackData: Data?
        var swimTrackData: Data? = nil
        var mediaPreviews: [MediaPreviewSnapshot]
        var featuredMediaPhotoID: String? = nil
    }

    struct ShareOptions: Equatable, Sendable {
        var includeNotes: Bool
        var includeMedia: Bool
    }

    /// Firestore field map (timestamps as `Date` — sync layer may swap server timestamps for `updatedAt`).
    nonisolated static func projectionFields(
        from dive: DiveSnapshot,
        options: ShareOptions,
        updatedAt: Date = Date()
    ) -> [String: Any] {
        var fields: [String: Any] = [
            "schemaVersion": schemaVersion,
            "diveId": dive.id.uuidString,
            "activityKind": dive.activityKind.rawValue,
            "startTime": dive.startTime,
            "durationMinutes": dive.durationMinutes,
            "maxDepthMeters": dive.maxDepthMeters,
            "updatedAt": updatedAt,
        ]

        setOptional(dive.timeZoneOffsetSeconds, key: "timeZoneOffsetSeconds", into: &fields)
        setOptionalString(dive.region, key: "region", into: &fields)
        setOptionalString(dive.country, key: "country", into: &fields)
        setOptional(dive.swimDistanceMeters, key: "swimDistanceMeters", into: &fields)
        setOptional(dive.averageDepthMeters, key: "averageDepthMeters", into: &fields)
        setOptional(dive.bottomTimeSeconds, key: "bottomTimeSeconds", into: &fields)
        setOptional(dive.diveNumber, key: "diveNumber", into: &fields)
        setOptional(dive.waterTempAvgCelsius, key: "waterTempAvgCelsius", into: &fields)
        setOptional(dive.waterTempMinCelsius, key: "waterTempMinCelsius", into: &fields)
        setOptional(dive.waterTempMaxCelsius, key: "waterTempMaxCelsius", into: &fields)
        setOptionalString(dive.siteName, key: "siteName", into: &fields)
        setOptionalString(dive.locationName, key: "locationName", into: &fields)
        setOptional(dive.entryLatitude, key: "entryLatitude", into: &fields)
        setOptional(dive.entryLongitude, key: "entryLongitude", into: &fields)
        setOptionalString(dive.diveCurrentStrengthRaw, key: "diveCurrentStrengthRaw", into: &fields)
        setOptionalString(dive.surfaceCondition, key: "surfaceCondition", into: &fields)
        setOptionalString(dive.entryType, key: "entryType", into: &fields)
        setOptionalString(dive.diveVisibilityRaw, key: "diveVisibilityRaw", into: &fields)
        setOptionalString(dive.diveOperatorName, key: "diveOperatorName", into: &fields)
        setOptionalString(dive.diveMasterName, key: "diveMasterName", into: &fields)
        setOptionalString(dive.diveWaterTypeRaw, key: "diveWaterTypeRaw", into: &fields)
        setOptional(dive.diverWeightKilograms, key: "diverWeightKilograms", into: &fields)
        setOptionalString(dive.tankMaterial, key: "tankMaterial", into: &fields)
        setOptionalString(dive.tankVolumeDescription, key: "tankVolumeDescription", into: &fields)
        setOptional(dive.tankPressureStartPSI, key: "tankPressureStartPSI", into: &fields)
        setOptional(dive.tankPressureEndPSI, key: "tankPressureEndPSI", into: &fields)
        setOptionalString(dive.gasType, key: "gasType", into: &fields)
        setOptional(dive.oxygenMix, key: "oxygenMix", into: &fields)
        setOptional(dive.avgSAC, key: "avgSAC", into: &fields)
        setOptional(dive.avgRMV, key: "avgRMV", into: &fields)

        if !dive.activityTagNames.isEmpty {
            fields["activityTagNames"] = dive.activityTagNames
        }
        if !dive.equipmentSummary.isEmpty {
            fields["equipmentSummary"] = dive.equipmentSummary
        }
        if !dive.sightings.isEmpty {
            fields["sightings"] = dive.sightings.map { sighting -> [String: Any] in
                var row: [String: Any] = ["commonName": sighting.commonName]
                if let scientificName = sighting.scientificName, !scientificName.isEmpty {
                    row["scientificName"] = scientificName
                }
                if let catalogUUID = sighting.catalogUUID, !catalogUUID.isEmpty {
                    row["catalogUUID"] = catalogUUID
                }
                return row
            }
        }
        if !dive.taggedBuddies.isEmpty {
            fields["taggedBuddies"] = dive.taggedBuddies.map { buddy -> [String: Any] in
                var row: [String: Any] = ["displayName": buddy.displayName]
                if let firebaseUID = buddy.firebaseUID, !firebaseUID.isEmpty {
                    row["firebaseUid"] = firebaseUID
                }
                return row
            }
        }

        if let track = cappedProfileTrack(dive.profileTrackData) {
            fields["profileTrackBase64"] = track.base64EncodedString()
        }
        if let swimTrack = cappedSwimTrack(dive.swimTrackData) {
            fields["swimTrackBase64"] = swimTrack.base64EncodedString()
        }

        if options.includeNotes, let notes = dive.notes {
            let trimmed = GoDiveInputSanitization.trimmedAndCapped(
                notes,
                maxLength: DiveNotesValidation.maxCharacterCount
            )
            if !trimmed.isEmpty {
                fields["notes"] = trimmed
            }
        }

        if options.includeMedia, !dive.mediaPreviews.isEmpty {
            fields["mediaPreviews"] = dive.mediaPreviews.map { preview in
                [
                    "photoId": preview.photoID,
                    "previewURL": preview.previewURL,
                ] as [String: Any]
            }
            setOptionalString(dive.featuredMediaPhotoID, key: "featuredMediaPhotoId", into: &fields)
        }

        return fields
    }

    /// Parses a Firestore document into a display model (missing fields → nil / empty).
    struct FriendVisibleDive: Equatable, Sendable, Identifiable {
        var id: String
        var activityKind: FriendSharedActivityKind = .scubaDive
        var startTime: Date?
        var durationMinutes: Int?
        var maxDepthMeters: Double?
        var averageDepthMeters: Double?
        var diveNumber: Int?
        var siteName: String?
        var locationName: String?
        var region: String? = nil
        var country: String? = nil
        var swimDistanceMeters: Double? = nil
        var entryLatitude: Double?
        var entryLongitude: Double?
        var notes: String?
        var activityTagNames: [String]
        var sightings: [SightingSnapshot]
        var taggedBuddies: [TaggedBuddySnapshot]
        var equipmentSummary: [String]
        var mediaPreviews: [MediaPreviewSnapshot]
        var featuredMediaPhotoID: String? = nil
        var profileTrackBase64: String?
        var swimTrackBase64: String? = nil
        var gasType: String?
        var oxygenMix: Double?
        var tankVolumeDescription: String?
        var waterTempMinCelsius: Double?
        var bottomTimeSeconds: Int?
        var tankPressureStartPSI: Double? = nil
        var tankPressureEndPSI: Double? = nil
        var updatedAt: Date? = nil

        nonisolated var resolvedActivityKind: FriendSharedActivityKind {
            activityKind
        }
    }

    nonisolated static func parseFriendVisibleDive(id: String, data: [String: Any]) -> FriendVisibleDive {
        let sightings: [SightingSnapshot] = (data["sightings"] as? [[String: Any]])?.compactMap { row in
            guard let common = row["commonName"] as? String, !common.isEmpty else { return nil }
            return SightingSnapshot(
                commonName: common,
                scientificName: row["scientificName"] as? String,
                catalogUUID: row["catalogUUID"] as? String
            )
        } ?? []
        let buddies: [TaggedBuddySnapshot] = (data["taggedBuddies"] as? [[String: Any]])?.compactMap { row in
            guard let name = row["displayName"] as? String, !name.isEmpty else { return nil }
            return TaggedBuddySnapshot(
                displayName: name,
                firebaseUID: row["firebaseUid"] as? String
            )
        } ?? []
        let media: [MediaPreviewSnapshot] = (data["mediaPreviews"] as? [[String: Any]])?.compactMap { row in
            guard let photoID = row["photoId"] as? String,
                  let url = row["previewURL"] as? String,
                  !photoID.isEmpty,
                  !url.isEmpty
            else { return nil }
            return MediaPreviewSnapshot(photoID: photoID, previewURL: url)
        } ?? []

        let activityKind = FriendSharedActivityKind(rawValue: data["activityKind"] as? String ?? "")
            ?? .scubaDive

        return FriendVisibleDive(
            id: id,
            activityKind: activityKind,
            startTime: dateValue(data["startTime"]),
            durationMinutes: data["durationMinutes"] as? Int,
            maxDepthMeters: data["maxDepthMeters"] as? Double,
            averageDepthMeters: data["averageDepthMeters"] as? Double,
            diveNumber: data["diveNumber"] as? Int,
            siteName: data["siteName"] as? String,
            locationName: data["locationName"] as? String,
            region: data["region"] as? String,
            country: data["country"] as? String,
            swimDistanceMeters: data["swimDistanceMeters"] as? Double,
            entryLatitude: data["entryLatitude"] as? Double,
            entryLongitude: data["entryLongitude"] as? Double,
            notes: data["notes"] as? String,
            activityTagNames: data["activityTagNames"] as? [String] ?? [],
            sightings: sightings,
            taggedBuddies: buddies,
            equipmentSummary: data["equipmentSummary"] as? [String] ?? [],
            mediaPreviews: media,
            featuredMediaPhotoID: data["featuredMediaPhotoId"] as? String,
            profileTrackBase64: data["profileTrackBase64"] as? String,
            swimTrackBase64: data["swimTrackBase64"] as? String,
            gasType: data["gasType"] as? String,
            oxygenMix: data["oxygenMix"] as? Double,
            tankVolumeDescription: data["tankVolumeDescription"] as? String,
            waterTempMinCelsius: data["waterTempMinCelsius"] as? Double,
            bottomTimeSeconds: data["bottomTimeSeconds"] as? Int,
            tankPressureStartPSI: data["tankPressureStartPSI"] as? Double,
            tankPressureEndPSI: data["tankPressureEndPSI"] as? Double,
            updatedAt: dateValue(data["updatedAt"])
        )
    }

    /// Depth + optional gas overlay series decoded from a friend-visible projection track blob.
    struct FriendSharedDepthChartSeries: Equatable, Sendable {
        var depthSamples: [DiveDepthProfileSample]
        var pressureSamples: [DiveDepthProfilePressureSample]
        var pressureBaselinePSI: Double?

        nonisolated static let empty = FriendSharedDepthChartSeries(
            depthSamples: [],
            pressureSamples: [],
            pressureBaselinePSI: nil
        )

        nonisolated var hasRenderableProfile: Bool {
            depthSamples.count >= 2
        }
    }

    nonisolated static func displayTitle(for dive: FriendVisibleDive) -> String {
        let site = dive.siteName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !site.isEmpty { return site }
        let location = dive.locationName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !location.isEmpty { return location }
        switch dive.resolvedActivityKind {
        case .snorkel:
            return "Snorkel"
        case .scubaDive:
            return "Dive"
        }
    }

    nonisolated static func regionCountryDisplayLine(for dive: FriendVisibleDive) -> String? {
        let region = dive.region?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let country = dive.country?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if let line = DiveActivityOverviewPresentation.regionCountryLine(region: region, country: country) {
            return line
        }
        return DiveActivityOverviewPresentation.regionCountryLine(locationName: dive.locationName)
    }

    nonisolated static func decodedDepthChartSeries(
        from dive: FriendVisibleDive
    ) -> FriendSharedDepthChartSeries {
        guard dive.resolvedActivityKind == .scubaDive,
              let base64 = dive.profileTrackBase64,
              let data = Data(base64Encoded: base64),
              let startTime = dive.startTime
        else { return .empty }
        guard let track = try? DiveProfileTrackCodec.decode(data, diveStartTime: startTime) else { return .empty }
        let snapshots = track
            .map {
                DiveDerivedProfilePointSnapshot(
                    timestamp: $0.timestamp,
                    depthMeters: $0.depthMeters,
                    tankPressurePSI: $0.tankPressurePSI
                )
            }
            .sorted { $0.timestamp < $1.timestamp }
        let built = DiveDerivedDataBuilder.build(
            from: DiveDerivedDataBuildInput(
                profilePointSnapshots: snapshots,
                sortedMediaSnapshots: [],
                activityStartTime: startTime,
                durationMinutes: dive.durationMinutes ?? 0
            )
        )
        let baseline = dive.tankPressureEndPSI ?? built.profileGasStats.minPSI
        return FriendSharedDepthChartSeries(
            depthSamples: built.depthSamples,
            pressureSamples: built.pressureSamples,
            pressureBaselinePSI: baseline
        )
    }

    nonisolated static func decodedDepthSamples(from dive: FriendVisibleDive) -> [DiveDepthProfileSample] {
        decodedDepthChartSeries(from: dive).depthSamples
    }

    nonisolated static func decodedSwimTrackCoordinates(from dive: FriendVisibleDive) -> [DiveCoordinate] {
        guard dive.resolvedActivityKind == .snorkel,
              let base64 = dive.swimTrackBase64,
              let data = Data(base64Encoded: base64),
              let startTime = dive.startTime
        else { return [] }
        guard let track = try? SnorkelSwimTrackCodec.decode(data, activityStartTime: startTime) else { return [] }
        return track.compactMap { sample in
            let coordinate = DiveCoordinate(latitude: sample.latitude, longitude: sample.longitude)
            return DiveMapCoordinateResolver.isUsable(coordinate) ? coordinate : nil
        }
    }

    nonisolated static func wasCurrentUserTagged(
        dive: FriendVisibleDive,
        currentFirebaseUID: String?
    ) -> Bool {
        guard let uid = currentFirebaseUID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !uid.isEmpty
        else { return false }
        return dive.taggedBuddies.contains { $0.firebaseUID == uid }
    }

    nonisolated static func cappedProfileTrack(_ data: Data?) -> Data? {
        guard let data, !data.isEmpty else { return nil }
        guard data.count <= maxProfileTrackBytes else { return nil }
        return data
    }

    nonisolated static func cappedSwimTrack(_ data: Data?) -> Data? {
        guard let data, !data.isEmpty else { return nil }
        guard data.count <= maxSwimTrackBytes else { return nil }
        return data
    }

    private nonisolated static func setOptional<T>(_ value: T?, key: String, into fields: inout [String: Any]) {
        if let value { fields[key] = value }
    }

    private nonisolated static func setOptionalString(_ value: String?, key: String, into fields: inout [String: Any]) {
        guard let value else { return }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        fields[key] = trimmed
    }

    private nonisolated static func dateValue(_ raw: Any?) -> Date? {
        if let date = raw as? Date { return date }
        if let timestamp = raw as? Timestamp { return timestamp.dateValue() }
        return nil
    }
}
