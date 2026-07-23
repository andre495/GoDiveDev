import Foundation

/// Builds Firestore-safe friend-visible dive projections from local dive snapshots.
enum GoDiveSharedDiveProjectionMapping: Sendable {
    nonisolated static let sharedDivesSubcollection = "sharedDives"
    nonisolated static let schemaVersion = 1
    /// Leave headroom under Firestore’s 1 MiB document limit.
    nonisolated static let maxProfileTrackBytes = 700_000

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
        var mediaPreviews: [MediaPreviewSnapshot]
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
            "startTime": dive.startTime,
            "durationMinutes": dive.durationMinutes,
            "maxDepthMeters": dive.maxDepthMeters,
            "updatedAt": updatedAt,
        ]

        setOptional(dive.timeZoneOffsetSeconds, key: "timeZoneOffsetSeconds", into: &fields)
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
        }

        return fields
    }

    /// Parses a Firestore document into a display model (missing fields → nil / empty).
    struct FriendVisibleDive: Equatable, Sendable, Identifiable {
        var id: String
        var startTime: Date?
        var durationMinutes: Int?
        var maxDepthMeters: Double?
        var averageDepthMeters: Double?
        var diveNumber: Int?
        var siteName: String?
        var locationName: String?
        var entryLatitude: Double?
        var entryLongitude: Double?
        var notes: String?
        var activityTagNames: [String]
        var sightings: [SightingSnapshot]
        var taggedBuddies: [TaggedBuddySnapshot]
        var equipmentSummary: [String]
        var mediaPreviews: [MediaPreviewSnapshot]
        var profileTrackBase64: String?
        var gasType: String?
        var oxygenMix: Double?
        var tankVolumeDescription: String?
        var waterTempMinCelsius: Double?
        var bottomTimeSeconds: Int?
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

        return FriendVisibleDive(
            id: id,
            startTime: dateValue(data["startTime"]),
            durationMinutes: data["durationMinutes"] as? Int,
            maxDepthMeters: data["maxDepthMeters"] as? Double,
            averageDepthMeters: data["averageDepthMeters"] as? Double,
            diveNumber: data["diveNumber"] as? Int,
            siteName: data["siteName"] as? String,
            locationName: data["locationName"] as? String,
            entryLatitude: data["entryLatitude"] as? Double,
            entryLongitude: data["entryLongitude"] as? Double,
            notes: data["notes"] as? String,
            activityTagNames: data["activityTagNames"] as? [String] ?? [],
            sightings: sightings,
            taggedBuddies: buddies,
            equipmentSummary: data["equipmentSummary"] as? [String] ?? [],
            mediaPreviews: media,
            profileTrackBase64: data["profileTrackBase64"] as? String,
            gasType: data["gasType"] as? String,
            oxygenMix: data["oxygenMix"] as? Double,
            tankVolumeDescription: data["tankVolumeDescription"] as? String,
            waterTempMinCelsius: data["waterTempMinCelsius"] as? Double,
            bottomTimeSeconds: data["bottomTimeSeconds"] as? Int
        )
    }

    nonisolated static func displayTitle(for dive: FriendVisibleDive) -> String {
        let site = dive.siteName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !site.isEmpty { return site }
        let location = dive.locationName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !location.isEmpty { return location }
        return "Dive"
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
        return nil
    }
}
