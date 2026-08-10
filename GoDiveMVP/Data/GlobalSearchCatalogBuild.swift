import Foundation

/// Sendable site fields for building the global search site index off the main actor.
struct GlobalSearchDiveSiteSeed: Sendable, Equatable {
    let id: UUID
    let siteName: String
    let country: String
    let region: String
    let bodyOfWater: String
    let siteTags: [String]
}

/// Per-activity extras that require walking SwiftData relationships — captured on MainActor.
struct GlobalSearchActivitySearchExtras: Sendable, Equatable {
    let marineLifeCommonNames: [String]
    let tripTitles: [String]
    let countrySearchValue: String?
    let countryDisplay: String?
    let region: String?
    let notes: String?
}

/// MainActor snapshot → detached catalog assembly for **Global Search**.
struct GlobalSearchCatalogBuildInput: Sendable {
    let ownerProfileID: UUID?
    let diveSeeds: [LogbookActivitySnapshotSeed]
    let diveExtrasByID: [UUID: GlobalSearchActivitySearchExtras]
    let snorkelSeeds: [LogbookActivitySnapshotSeed]
    let snorkelExtrasByID: [UUID: GlobalSearchActivitySearchExtras]
    let diveSites: [GlobalSearchDiveSiteSeed]
    let logbookSiteIDs: Set<UUID>
    let speciesSnapshots: [MarineLifeCatalogSnapshot]
    let buddies: [GlobalSearchPresentation.BuddyIndexEntry]
    let tags: [GlobalSearchPresentation.TagIndexEntry]
    let trips: [GlobalSearchPresentation.TripIndexEntry]
    let equipment: [GlobalSearchPresentation.EquipmentIndexEntry]
    let certifications: [GlobalSearchPresentation.CertificationIndexEntry]
}

/// Captures SwiftData models into a Sendable build input (MainActor only).
enum GlobalSearchCatalogCapture {
    @MainActor
    static func capture(
        dives: [DiveActivity],
        snorkels: [SnorkelActivity],
        diveSites: [DiveSite],
        speciesCatalog: [MarineLife],
        buddies: [DiveBuddy],
        tags: [ActivityTag],
        trips: [DiveTrip],
        equipment: [EquipmentItem],
        certifications: [Certification]
    ) -> GlobalSearchCatalogBuildInput {
        let diveSpeciesNameByUUID = Dictionary(
            speciesCatalog.map { ($0.uuid, $0.commonName) },
            uniquingKeysWith: { first, _ in first }
        )
        let diveTripTitleByID = Dictionary(
            trips.map { ($0.id, $0.displayTitle) },
            uniquingKeysWith: { first, _ in first }
        )

        let diveSeeds = LogbookActivitySnapshotSeeding.seeds(from: dives)
        var diveExtrasByID: [UUID: GlobalSearchActivitySearchExtras] = [:]
        diveExtrasByID.reserveCapacity(dives.count)
        for dive in dives {
            diveExtrasByID[dive.id] = activityExtras(
                marineLifeCommonNames: dive.marineLifeSightings.compactMap {
                    diveSpeciesNameByUUID[$0.marineLifeUUID]
                },
                tripTitles: dive.tripActivityLinks.compactMap { link in
                    if let title = link.trip?.displayTitle,
                       !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        return title
                    }
                    guard let tripID = link.tripID else { return nil }
                    return diveTripTitleByID[tripID]
                },
                linkedSite: dive.resolvedLinkedSite,
                notes: dive.notes
            )
        }

        let snorkelSeeds = LogbookActivitySnapshotSeeding.snorkelSeeds(from: snorkels)
        var snorkelExtrasByID: [UUID: GlobalSearchActivitySearchExtras] = [:]
        snorkelExtrasByID.reserveCapacity(snorkels.count)
        for snorkel in snorkels {
            snorkelExtrasByID[snorkel.id] = activityExtras(
                marineLifeCommonNames: snorkel.marineLifeSightings.compactMap {
                    diveSpeciesNameByUUID[$0.marineLifeUUID]
                },
                tripTitles: [],
                linkedSite: snorkel.resolvedLinkedSite,
                notes: snorkel.notes
            )
        }

        let ownerProfileID = dives.first?.ownerProfileID
            ?? snorkels.first?.ownerProfileID
            ?? buddies.first?.ownerProfileID

        var logbookSiteIDs = ExploreSiteScopePresentation.logbookSiteIDs(
            ownerActivities: dives,
            ownerProfileID: ownerProfileID
        )
        logbookSiteIDs.formUnion(Set(snorkels.compactMap(\.diveSiteID)))

        let siteSeeds = diveSites.map { site in
            GlobalSearchDiveSiteSeed(
                id: site.id,
                siteName: site.siteName,
                country: site.country,
                region: site.region,
                bodyOfWater: site.bodyOfWater,
                siteTags: site.siteTags
            )
        }

        let speciesSnapshots = speciesCatalog.map(\.fieldGuideCatalogSnapshot)

        let buddyEntries = buddies.map {
            GlobalSearchPresentation.BuddyIndexEntry(id: $0.id, displayName: $0.displayName)
        }

        let tagEntries = tags.map { tag in
            let appliedDiveCount: Int
            if let ownerProfileID {
                appliedDiveCount = tag.dives.filter { $0.ownerProfileID == ownerProfileID }.count
            } else {
                appliedDiveCount = tag.dives.count
            }
            return GlobalSearchPresentation.TagIndexEntry(
                id: tag.id,
                name: tag.name,
                appliedDiveCount: appliedDiveCount,
                searchHaystack: CatalogSearchPresentation.joinedLowercasedHaystacks([
                    tag.name,
                    tag.normalizedName,
                ])
            )
        }

        let tripEntries = trips.map { trip in
            GlobalSearchPresentation.TripIndexEntry(
                id: trip.id,
                displayTitle: trip.displayTitle,
                subtitle: DiveTripPresentation.formattedDateRange(
                    start: trip.startDate,
                    end: trip.endDate
                )
            )
        }

        let equipmentEntries = equipment.map { item in
            GlobalSearchPresentation.EquipmentIndexEntry(
                id: item.id,
                title: EquipmentItemPresentation.title(for: item),
                gearTypeLabel: EquipmentItemPresentation.gearTypeLabel(for: item),
                searchHaystacks: [
                    EquipmentItemPresentation.title(for: item),
                    EquipmentItemPresentation.gearTypeLabel(for: item),
                    item.manufacturer,
                    item.model,
                    item.type,
                    item.notes ?? "",
                ]
            )
        }

        let certificationEntries = certifications.map { cert in
            GlobalSearchPresentation.CertificationIndexEntry(
                id: cert.id,
                title: CertificationPresentation.title(for: cert),
                subtitle: CertificationPresentation.subtitle(for: cert),
                searchHaystacks: [
                    CertificationPresentation.title(for: cert),
                    CertificationPresentation.subtitle(for: cert),
                    cert.agency,
                    cert.certNumber,
                    cert.instructor,
                    cert.diveShop ?? "",
                ]
            )
        }

        return GlobalSearchCatalogBuildInput(
            ownerProfileID: ownerProfileID,
            diveSeeds: diveSeeds,
            diveExtrasByID: diveExtrasByID,
            snorkelSeeds: snorkelSeeds,
            snorkelExtrasByID: snorkelExtrasByID,
            diveSites: siteSeeds,
            logbookSiteIDs: logbookSiteIDs,
            speciesSnapshots: speciesSnapshots,
            buddies: buddyEntries,
            tags: tagEntries,
            trips: tripEntries,
            equipment: equipmentEntries,
            certifications: certificationEntries
        )
    }

    @MainActor
    private static func activityExtras(
        marineLifeCommonNames: [String],
        tripTitles: [String],
        linkedSite: DiveLinkedSiteResolver.ResolvedSite?,
        notes: String?
    ) -> GlobalSearchActivitySearchExtras {
        var countrySearchValue: String?
        var countryDisplay: String?
        var region: String?
        if let site = linkedSite {
            let countryTerms = DiveSiteCountryPresentation.searchTerms(for: site.country)
            if !countryTerms.isEmpty {
                countrySearchValue = countryTerms.joined(separator: " ")
                countryDisplay = DiveSiteCountryPresentation.canonicalDisplayName(for: site.country)
            }
            let trimmedRegion = site.region.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedRegion.isEmpty {
                region = trimmedRegion
            }
        }
        let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        return GlobalSearchActivitySearchExtras(
            marineLifeCommonNames: marineLifeCommonNames,
            tripTitles: tripTitles,
            countrySearchValue: countrySearchValue,
            countryDisplay: countryDisplay,
            region: region,
            notes: (trimmedNotes?.isEmpty == false) ? trimmedNotes : nil
        )
    }
}

/// Assembles **`GlobalSearchPresentation.Catalog`** from a Sendable capture (safe off MainActor).
enum GlobalSearchCatalogBuild: Sendable {
    nonisolated static func build(from input: GlobalSearchCatalogBuildInput) -> GlobalSearchPresentation.Catalog {
        let monthSymbols = GlobalSearchDiveIndexing.monthSymbols()

        let diveEntries = input.diveSeeds.map { seed in
            let matchFields = diveMatchFields(
                seed: seed,
                extras: input.diveExtrasByID[seed.id],
                monthSymbols: monthSymbols
            )
            let haystack = CatalogSearchPresentation.joinedLowercasedHaystacks(
                [seed.displayName, seed.resolvedSiteNameLowercased ?? ""] + matchFields.map(\.value)
            )
            return GlobalSearchPresentation.DiveIndexEntry(
                id: seed.id,
                title: seed.displayName,
                subtitle: seed.resolvedSiteNameLowercased?.capitalized,
                searchHaystack: haystack,
                matchFields: matchFields
            )
        }

        let snorkelEntries = input.snorkelSeeds.map { seed in
            let matchFields = snorkelMatchFields(
                seed: seed,
                extras: input.snorkelExtrasByID[seed.id],
                monthSymbols: monthSymbols
            )
            let haystack = CatalogSearchPresentation.joinedLowercasedHaystacks(
                [seed.displayName, seed.resolvedSiteNameLowercased ?? ""] + matchFields.map(\.value)
            )
            return GlobalSearchPresentation.DiveIndexEntry(
                id: seed.id,
                title: seed.displayName,
                subtitle: seed.resolvedSiteNameLowercased?.capitalized,
                searchHaystack: haystack,
                matchFields: matchFields
            )
        }

        let siteEntries = GlobalSearchSiteIndexSeeding.entries(
            diveSites: input.diveSites,
            logbookSiteIDs: input.logbookSiteIDs
        )

        let speciesEntries = input.speciesSnapshots.map { snapshot in
            GlobalSearchPresentation.SpeciesIndexEntry(
                uuid: snapshot.uuid,
                title: snapshot.commonName,
                subtitle: snapshot.scientificName,
                searchText: FieldGuideMarineLifeSearch.precomputedSearchText(for: snapshot)
            )
        }

        return GlobalSearchPresentation.Catalog(
            dives: diveEntries,
            snorkels: snorkelEntries,
            diveSites: siteEntries,
            species: speciesEntries,
            buddies: input.buddies,
            tags: input.tags,
            trips: input.trips,
            equipment: input.equipment,
            certifications: input.certifications
        )
    }

    nonisolated private static func diveMatchFields(
        seed: LogbookActivitySnapshotSeed,
        extras: GlobalSearchActivitySearchExtras?,
        monthSymbols: [String]
    ) -> [GlobalSearchPresentation.SearchField] {
        var fields: [GlobalSearchPresentation.SearchField] = []

        for buddy in seed.buddyDisplayNames {
            fields.append(.init(label: "Buddy", value: buddy))
        }
        if let extras {
            for name in extras.marineLifeCommonNames {
                fields.append(.init(label: "Marine life", value: name))
            }
        }
        for tag in seed.activityTagNames {
            fields.append(.init(label: "Tag", value: tag))
        }
        if let extras {
            for title in extras.tripTitles {
                fields.append(.init(label: "Trip", value: title))
            }
            if let countrySearchValue = extras.countrySearchValue {
                fields.append(.init(
                    label: "Country",
                    value: countrySearchValue,
                    display: extras.countryDisplay
                ))
            }
            if let region = extras.region {
                fields.append(.init(label: "Region", value: region))
            }
        }
        if let month = GlobalSearchDiveIndexing.monthName(for: seed.startTime, monthSymbols: monthSymbols) {
            fields.append(.init(label: "Dive month", value: month))
        }
        if let year = GlobalSearchDiveIndexing.yearString(for: seed.startTime) {
            fields.append(.init(label: "Dive year", value: year))
        }
        if let notes = extras?.notes {
            fields.append(.init(label: "Notes", value: notes, isSnippet: true))
        }
        if let number = seed.diveNumber {
            fields.append(.init(label: "Dive number", value: "#\(number)"))
        }

        return fields
    }

    nonisolated private static func snorkelMatchFields(
        seed: LogbookActivitySnapshotSeed,
        extras: GlobalSearchActivitySearchExtras?,
        monthSymbols: [String]
    ) -> [GlobalSearchPresentation.SearchField] {
        var fields: [GlobalSearchPresentation.SearchField] = []

        for buddy in seed.buddyDisplayNames {
            fields.append(.init(label: "Buddy", value: buddy))
        }
        if let extras {
            for name in extras.marineLifeCommonNames {
                fields.append(.init(label: "Marine life", value: name))
            }
            if let countrySearchValue = extras.countrySearchValue {
                fields.append(.init(
                    label: "Country",
                    value: countrySearchValue,
                    display: extras.countryDisplay
                ))
            }
            if let region = extras.region {
                fields.append(.init(label: "Region", value: region))
            }
        }
        if let month = GlobalSearchDiveIndexing.monthName(for: seed.startTime, monthSymbols: monthSymbols) {
            fields.append(.init(label: "Snorkel month", value: month))
        }
        if let year = GlobalSearchDiveIndexing.yearString(for: seed.startTime) {
            fields.append(.init(label: "Snorkel year", value: year))
        }
        if let notes = extras?.notes {
            fields.append(.init(label: "Notes", value: notes, isSnippet: true))
        }

        return fields
    }
}
