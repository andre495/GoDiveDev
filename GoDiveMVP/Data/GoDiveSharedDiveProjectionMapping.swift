import FirebaseFirestore
import Foundation

/// Friend-visible activity kind stored on **`sharedDives`** documents (dives + snorkels).
enum FriendSharedActivityKind: String, Sendable, Equatable {
    case scubaDive
    case snorkel
}

/// Photo vs video on friend-visible **`mediaItems`** (schema v3).
enum FriendSharedMediaKind: String, Sendable, Equatable {
    case photo
    case video
}

/// Builds Firestore-safe friend-visible dive projections from local dive snapshots.
enum GoDiveSharedDiveProjectionMapping: Sendable {
    nonisolated static let sharedDivesSubcollection = "sharedDives"
    nonisolated static let schemaVersion = 3
    /// Leave headroom under Firestore’s 1 MiB document limit.
    nonisolated static let maxProfileTrackBytes = 700_000
    nonisolated static let maxSwimTrackBytes = 700_000

    struct TaggedBuddySnapshot: Equatable, Hashable, Sendable {
        var displayName: String
        var firebaseUID: String?
    }

    nonisolated static func taggedBuddiesFirestoreRows(
        from buddies: [TaggedBuddySnapshot]
    ) -> [[String: Any]] {
        buddies.map { buddy in
            var row: [String: Any] = ["displayName": buddy.displayName]
            if let firebaseUID = buddy.firebaseUID, !firebaseUID.isEmpty {
                row["firebaseUid"] = firebaseUID
            }
            return row
        }
    }

    struct SightingSnapshot: Equatable, Hashable, Sendable {
        var commonName: String
        var scientificName: String?
        var catalogUUID: String?
    }

    struct MediaBuddyTagSnapshot: Equatable, Hashable, Sendable {
        var mediaID: String
        var displayName: String
        var firebaseUID: String?
    }

    /// Legacy v2 thumbnail pointer — still populated on read for existing UI.
    struct MediaPreviewSnapshot: Equatable, Hashable, Sendable {
        var photoID: String
        var previewURL: String
    }

    /// Schema v3 media row (thumbnail + optional full-quality content URL).
    struct MediaItemSnapshot: Equatable, Hashable, Sendable {
        var mediaID: String
        var kind: FriendSharedMediaKind
        var thumbnailURL: String?
        var contentURL: String?
        var width: Int?
        var height: Int?
        var durationSeconds: Double?
        var contentBytes: Int?

        nonisolated static func photoThumbnailOnly(
            mediaID: String,
            thumbnailURL: String
        ) -> MediaItemSnapshot {
            MediaItemSnapshot(
                mediaID: mediaID,
                kind: .photo,
                thumbnailURL: thumbnailURL,
                contentURL: nil,
                width: nil,
                height: nil,
                durationSeconds: nil,
                contentBytes: nil
            )
        }
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
        /// Schema v3 rows (preferred on write).
        var mediaItems: [MediaItemSnapshot] = []
        /// Buddies tagged on specific shared media items (not dive-level roster tags).
        var mediaBuddyTags: [MediaBuddyTagSnapshot] = []
        /// Legacy v2 thumbnail rows — converted to **`mediaItems`** when v3 rows are empty.
        var mediaPreviews: [MediaPreviewSnapshot]
        var featuredMediaPhotoID: String? = nil
    }

    struct ShareOptions: Equatable, Sendable {
        var includeNotes: Bool
        /// When set, written to Firestore **`notes`** (private or public buddy note).
        var notesText: String? = nil
        var includeMedia: Bool
        /// Selected gallery items to upload. Empty = no media when **`restrictsMediaToExplicitSelection`** is true.
        var selectedMediaIDs: Set<UUID> = []
        /// When **`true`**, only **`selectedMediaIDs`** are uploaded (may be empty). When **`false`**, caps apply to full gallery.
        var restrictsMediaToExplicitSelection: Bool = false
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

        if options.includeNotes, let notes = options.notesText {
            if let trimmed = GoDiveInputSanitization.sanitizedNotes(notes) {
                fields["notes"] = trimmed
            }
        }

        if options.includeMedia {
            let items = resolvedMediaItems(for: dive)
            if !items.isEmpty {
                fields["mediaItems"] = items.map(mediaItemFirestoreRow)
                let featuredID = dive.featuredMediaPhotoID?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                setOptionalString(featuredID, key: "featuredMediaId", into: &fields)
            }
            if !dive.mediaBuddyTags.isEmpty {
                fields["mediaBuddyTags"] = dive.mediaBuddyTags.map(mediaBuddyTagFirestoreRow)
            }
        }

        return fields
    }

    nonisolated static func resolvedMediaItems(for dive: DiveSnapshot) -> [MediaItemSnapshot] {
        if !dive.mediaItems.isEmpty { return dive.mediaItems }
        return dive.mediaPreviews.map { preview in
            .photoThumbnailOnly(mediaID: preview.photoID, thumbnailURL: preview.previewURL)
        }
    }

    nonisolated static func legacyMediaPreviews(from items: [MediaItemSnapshot]) -> [MediaPreviewSnapshot] {
        items.compactMap { item in
            let thumb = item.thumbnailURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let content = item.contentURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let previewURL: String
            if !thumb.isEmpty {
                previewURL = thumb
            } else if !content.isEmpty {
                previewURL = content
            } else {
                return nil
            }
            return MediaPreviewSnapshot(photoID: item.mediaID, previewURL: previewURL)
        }
    }

    nonisolated static func mediaBuddyTagFirestoreRow(_ tag: MediaBuddyTagSnapshot) -> [String: Any] {
        var row: [String: Any] = [
            "mediaId": tag.mediaID,
            "displayName": tag.displayName,
        ]
        setOptionalString(tag.firebaseUID, key: "firebaseUid", into: &row)
        return row
    }

    nonisolated static func mediaItemFirestoreRow(_ item: MediaItemSnapshot) -> [String: Any] {
        var row: [String: Any] = [
            "mediaId": item.mediaID,
            "kind": item.kind.rawValue,
        ]
        setOptionalString(item.thumbnailURL, key: "thumbnailURL", into: &row)
        setOptionalString(item.contentURL, key: "contentURL", into: &row)
        setOptional(item.width, key: "width", into: &row)
        setOptional(item.height, key: "height", into: &row)
        setOptional(item.durationSeconds, key: "durationSeconds", into: &row)
        setOptional(item.contentBytes, key: "contentBytes", into: &row)
        return row
    }

    /// Parses a Firestore document into a display model (missing fields → nil / empty).
    struct FriendVisibleDive: Equatable, Hashable, Sendable, Identifiable {
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
        var mediaItems: [MediaItemSnapshot] = []
        var mediaBuddyTags: [MediaBuddyTagSnapshot] = []
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
        /// First time this projection was shared with buddies (stable; not bumped by media/republish).
        var sharedAt: Date? = nil
        /// Denormalized tally maintained by Cloud Function (not written by clients).
        var likeCount: Int = 0
        /// Denormalized tally maintained by Cloud Function (not written by clients).
        var commentCount: Int = 0

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
        let mediaPayload = parseMediaPayload(from: data)
        let mediaBuddyTags: [MediaBuddyTagSnapshot] = (data["mediaBuddyTags"] as? [[String: Any]])?
            .compactMap { row in
                guard let mediaID = row["mediaId"] as? String,
                      !mediaID.isEmpty,
                      let name = row["displayName"] as? String,
                      !name.isEmpty
                else { return nil }
                return MediaBuddyTagSnapshot(
                    mediaID: mediaID,
                    displayName: name,
                    firebaseUID: row["firebaseUid"] as? String
                )
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
            mediaItems: mediaPayload.items,
            mediaBuddyTags: mediaBuddyTags,
            mediaPreviews: mediaPayload.previews,
            featuredMediaPhotoID: mediaPayload.featuredMediaID,
            profileTrackBase64: data["profileTrackBase64"] as? String,
            swimTrackBase64: data["swimTrackBase64"] as? String,
            gasType: data["gasType"] as? String,
            oxygenMix: data["oxygenMix"] as? Double,
            tankVolumeDescription: data["tankVolumeDescription"] as? String,
            waterTempMinCelsius: data["waterTempMinCelsius"] as? Double,
            bottomTimeSeconds: data["bottomTimeSeconds"] as? Int,
            tankPressureStartPSI: data["tankPressureStartPSI"] as? Double,
            tankPressureEndPSI: data["tankPressureEndPSI"] as? Double,
            updatedAt: dateValue(data["updatedAt"]),
            sharedAt: dateValue(data["sharedAt"]),
            likeCount: nonNegativeInt(data["likeCount"]),
            commentCount: nonNegativeInt(data["commentCount"])
        )
    }

    /// First-share / republish timestamp rules for friend-visible projections.
    /// - First create: set **`sharedAt`** + **`updatedAt`**.
    /// - Existing: never overwrite **`sharedAt`**; hydrate it once if missing.
    /// - Full republish (`bumpUpdatedAt == false`): do not bump **`updatedAt`**.
    nonisolated static func applyShareTimestampPolicy(
        to fields: inout [String: Any],
        projectionAlreadyExists: Bool,
        bumpUpdatedAt: Bool,
        existingData: [String: Any]?,
        activityStartTime: Date?,
        now: Date = Date()
    ) {
        if projectionAlreadyExists, !bumpUpdatedAt {
            fields.removeValue(forKey: "updatedAt")
        }
        // `projectionFields` does not emit sharedAt; strip any accidental caller value.
        fields.removeValue(forKey: "sharedAt")

        if !projectionAlreadyExists {
            fields["sharedAt"] = now
            fields["updatedAt"] = now
            return
        }

        if dateValue(existingData?["sharedAt"]) == nil {
            fields["sharedAt"] = activityStartTime
                ?? dateValue(existingData?["updatedAt"])
                ?? now
        }
    }

    nonisolated private static func nonNegativeInt(_ value: Any?) -> Int {
        let parsed: Int?
        if let int = value as? Int {
            parsed = int
        } else if let number = value as? NSNumber {
            parsed = number.intValue
        } else {
            parsed = nil
        }
        return max(0, parsed ?? 0)
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

    nonisolated static func parseMediaPayload(
        from data: [String: Any]
    ) -> (items: [MediaItemSnapshot], previews: [MediaPreviewSnapshot], featuredMediaID: String?) {
        let featuredID = (data["featuredMediaId"] as? String)
            ?? (data["featuredMediaPhotoId"] as? String)

        let v3Items = parseV3MediaItems(from: data)
        if !v3Items.isEmpty {
            return (v3Items, legacyMediaPreviews(from: v3Items), featuredID)
        }

        let v2Previews: [MediaPreviewSnapshot] = (data["mediaPreviews"] as? [[String: Any]])?.compactMap { row in
            guard let photoID = row["photoId"] as? String,
                  let url = row["previewURL"] as? String,
                  !photoID.isEmpty,
                  !url.isEmpty
            else { return nil }
            return MediaPreviewSnapshot(photoID: photoID, previewURL: url)
        } ?? []
        let items = v2Previews.map {
            MediaItemSnapshot.photoThumbnailOnly(mediaID: $0.photoID, thumbnailURL: $0.previewURL)
        }
        return (items, v2Previews, featuredID)
    }

    nonisolated static func parseV3MediaItems(from data: [String: Any]) -> [MediaItemSnapshot] {
        (data["mediaItems"] as? [[String: Any]])?.compactMap { row in
            guard let mediaID = row["mediaId"] as? String,
                  !mediaID.isEmpty
            else { return nil }
            let kind = FriendSharedMediaKind(rawValue: row["kind"] as? String ?? "") ?? .photo
            return MediaItemSnapshot(
                mediaID: mediaID,
                kind: kind,
                thumbnailURL: row["thumbnailURL"] as? String,
                contentURL: row["contentURL"] as? String,
                width: row["width"] as? Int,
                height: row["height"] as? Int,
                durationSeconds: row["durationSeconds"] as? Double,
                contentBytes: row["contentBytes"] as? Int
            )
        } ?? []
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
