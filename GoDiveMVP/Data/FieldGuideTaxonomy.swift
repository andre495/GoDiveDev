import Foundation

/// Caribbean Reef Life (Mickey Charteris) field guide hierarchy — generated from EPUB TOC.
/// Regenerate: python3 GoDiveMVP/Scripts/generate_field_guide_taxonomy_swift.py
enum FieldGuideTaxonomy {

    struct Subcategory: Sendable, Identifiable {
        let id: String
        let title: String
        let hint: String
        let systemImage: String
    }

    struct Category: Sendable, Identifiable {
        let id: String
        let title: String
        /// Short tagline for hub tiles.
        let subtitle: String
        /// Longer copy for the category detail header.
        let description: String
        let systemImage: String
        /// Future bundled hero asset name; **`nil`** uses the gradient placeholder.
        let heroImageName: String?
        let subcategories: [Subcategory]

        var subcategoryIDs: [String] { subcategories.map(\.id) }
    }

    nonisolated static let categories: [Category] = [
        Category(
            id: "plants",
            title: "Plants",
            subtitle: "Algae, seagrasses, and mangroves",
            description: "Plants and algae from Caribbean Reef Life.",
            systemImage: "leaf.fill",
            heroImageName: nil,
            subcategories: [
                Subcategory(
                    id: "mangroves",
                    title: "Mangroves",
                    hint: "Species from Caribbean Reef Life — Mangroves",
                    systemImage: "circle.fill"
                ),
                Subcategory(
                    id: "seagrasses",
                    title: "Seagrasses",
                    hint: "Species from Caribbean Reef Life — Seagrasses",
                    systemImage: "circle.fill"
                ),
                Subcategory(
                    id: "green-algae",
                    title: "Green Algae",
                    hint: "Species from Caribbean Reef Life — Green Algae",
                    systemImage: "circle.fill"
                ),
                Subcategory(
                    id: "brown-algae",
                    title: "Brown Algae",
                    hint: "Species from Caribbean Reef Life — Brown Algae",
                    systemImage: "circle.fill"
                ),
                Subcategory(
                    id: "red-algae",
                    title: "Red Algae",
                    hint: "Species from Caribbean Reef Life — Red Algae",
                    systemImage: "circle.fill"
                ),
            ]
        ),
        Category(
            id: "sponges",
            title: "Sponges",
            subtitle: "Filter feeders that shape Caribbean reefs",
            description: "Sponge groups from Caribbean Reef Life — barrel, tube, rope, and encrusting forms.",
            systemImage: "bubbles.and.sparkles.fill",
            heroImageName: "FieldGuideCategoryTubeSponge",
            subcategories: [
                Subcategory(
                    id: "encrusting-sponges",
                    title: "Encrusting Sponges",
                    hint: "Species from Caribbean Reef Life — Encrusting Sponges",
                    systemImage: "circle.fill"
                ),
                Subcategory(
                    id: "rope-sponges",
                    title: "Rope Sponges",
                    hint: "Species from Caribbean Reef Life — Rope Sponges",
                    systemImage: "circle.fill"
                ),
                Subcategory(
                    id: "ball-sponges",
                    title: "Ball Sponges",
                    hint: "Species from Caribbean Reef Life — Ball Sponges",
                    systemImage: "circle.fill"
                ),
                Subcategory(
                    id: "vase-sponges",
                    title: "Vase Sponges",
                    hint: "Species from Caribbean Reef Life — Vase Sponges",
                    systemImage: "circle.fill"
                ),
                Subcategory(
                    id: "tube-sponges",
                    title: "Tube Sponges",
                    hint: "Species from Caribbean Reef Life — Tube Sponges",
                    systemImage: "circle.fill"
                ),
                Subcategory(
                    id: "barrel-sponges",
                    title: "Barrel Sponges",
                    hint: "Species from Caribbean Reef Life — Barrel Sponges",
                    systemImage: "circle.fill"
                ),
            ]
        ),
        Category(
            id: "corals",
            title: "Corals",
            subtitle: "Reef builders, gorgonians, and soft corals",
            description: "Hard and soft coral groups from Caribbean Reef Life.",
            systemImage: "leaf.fill",
            heroImageName: "FieldGuideCategoryCoral",
            subcategories: [
                Subcategory(
                    id: "branching-corals",
                    title: "Branching Corals",
                    hint: "Species from Caribbean Reef Life — Branching Corals",
                    systemImage: "circle.fill"
                ),
                Subcategory(
                    id: "lettuce-corals",
                    title: "Lettuce Corals",
                    hint: "Species from Caribbean Reef Life — Lettuce Corals",
                    systemImage: "circle.fill"
                ),
                Subcategory(
                    id: "brain-corals",
                    title: "Brain Corals",
                    hint: "Species from Caribbean Reef Life — Brain Corals",
                    systemImage: "circle.fill"
                ),
                Subcategory(
                    id: "cactus-corals",
                    title: "Cactus Corals",
                    hint: "Species from Caribbean Reef Life — Cactus Corals",
                    systemImage: "circle.fill"
                ),
                Subcategory(
                    id: "star-corals",
                    title: "Star Corals",
                    hint: "Species from Caribbean Reef Life — Star Corals",
                    systemImage: "circle.fill"
                ),
                Subcategory(
                    id: "plate-corals",
                    title: "Plate Corals",
                    hint: "Species from Caribbean Reef Life — Plate Corals",
                    systemImage: "circle.fill"
                ),
                Subcategory(
                    id: "cup-corals",
                    title: "Cup Corals",
                    hint: "Species from Caribbean Reef Life — Cup Corals",
                    systemImage: "circle.fill"
                ),
                Subcategory(
                    id: "black-corals",
                    title: "Black Corals",
                    hint: "Species from Caribbean Reef Life — Black Corals",
                    systemImage: "circle.fill"
                ),
                Subcategory(
                    id: "octocorals",
                    title: "Octocorals",
                    hint: "Species from Caribbean Reef Life — Octocorals",
                    systemImage: "circle.fill"
                ),
            ]
        ),
        Category(
            id: "invertebrates",
            title: "Invertebrates",
            subtitle: "Anemones, worms, mollusks, crustaceans, and more",
            description: "Invertebrate groups from Caribbean Reef Life.",
            systemImage: "ant.fill",
            heroImageName: "FieldGuideCategoryAnemone",
            subcategories: [
                Subcategory(
                    id: "jellies",
                    title: "Jellies",
                    hint: "Species from Caribbean Reef Life — Jellies",
                    systemImage: "drop.fill"
                ),
                Subcategory(
                    id: "anemones",
                    title: "Anemones",
                    hint: "Species from Caribbean Reef Life — Anemones",
                    systemImage: "hand.raised.fill"
                ),
                Subcategory(
                    id: "corallimorphs",
                    title: "Corallimorphs",
                    hint: "Species from Caribbean Reef Life — Corallimorphs",
                    systemImage: "circle.fill"
                ),
                Subcategory(
                    id: "zoanthids",
                    title: "Zoanthids",
                    hint: "Species from Caribbean Reef Life — Zoanthids",
                    systemImage: "circle.grid.2x2.fill"
                ),
                Subcategory(
                    id: "tunicates",
                    title: "Tunicates",
                    hint: "Species from Caribbean Reef Life — Tunicates",
                    systemImage: "rectangle.grid.2x2.fill"
                ),
                Subcategory(
                    id: "hydroids",
                    title: "Hydroids",
                    hint: "Species from Caribbean Reef Life — Hydroids",
                    systemImage: "circle.fill"
                ),
                Subcategory(
                    id: "bryozoans",
                    title: "Bryozoans",
                    hint: "Species from Caribbean Reef Life — Bryozoans",
                    systemImage: "rectangle.grid.2x2.fill"
                ),
                Subcategory(
                    id: "sea-stars",
                    title: "Sea Stars",
                    hint: "Species from Caribbean Reef Life — Sea Stars",
                    systemImage: "star.circle.fill"
                ),
                Subcategory(
                    id: "brittle-stars",
                    title: "Brittle Stars",
                    hint: "Species from Caribbean Reef Life — Brittle Stars",
                    systemImage: "star.circle.fill"
                ),
                Subcategory(
                    id: "crinoids",
                    title: "Crinoids",
                    hint: "Species from Caribbean Reef Life — Crinoids",
                    systemImage: "star.circle.fill"
                ),
                Subcategory(
                    id: "sea-urchins",
                    title: "Sea Urchins",
                    hint: "Species from Caribbean Reef Life — Sea Urchins",
                    systemImage: "star.circle.fill"
                ),
                Subcategory(
                    id: "sea-cucumbers",
                    title: "Sea Cucumbers",
                    hint: "Species from Caribbean Reef Life — Sea Cucumbers",
                    systemImage: "star.circle.fill"
                ),
                Subcategory(
                    id: "worms",
                    title: "Worms",
                    hint: "Species from Caribbean Reef Life — Worms",
                    systemImage: "ellipsis.curlybraces"
                ),
                Subcategory(
                    id: "feather-dusters",
                    title: "Feather Dusters",
                    hint: "Species from Caribbean Reef Life — Feather Dusters",
                    systemImage: "ellipsis.curlybraces"
                ),
                Subcategory(
                    id: "flatworms",
                    title: "Flatworms",
                    hint: "Species from Caribbean Reef Life — Flatworms",
                    systemImage: "ellipsis.curlybraces"
                ),
                Subcategory(
                    id: "sea-slugs",
                    title: "Sea Slugs",
                    hint: "Species from Caribbean Reef Life — Sea Slugs",
                    systemImage: "leaf.arrow.circlepath"
                ),
                Subcategory(
                    id: "nudibranchs",
                    title: "Nudibranchs",
                    hint: "Species from Caribbean Reef Life — Nudibranchs",
                    systemImage: "leaf.arrow.circlepath"
                ),
                Subcategory(
                    id: "clams",
                    title: "Clams",
                    hint: "Species from Caribbean Reef Life — Clams",
                    systemImage: "capsule.fill"
                ),
                Subcategory(
                    id: "oysters",
                    title: "Oysters",
                    hint: "Species from Caribbean Reef Life — Oysters",
                    systemImage: "capsule.fill"
                ),
                Subcategory(
                    id: "chitons",
                    title: "Chitons",
                    hint: "Species from Caribbean Reef Life — Chitons",
                    systemImage: "circle.fill"
                ),
                Subcategory(
                    id: "limpets",
                    title: "Limpets",
                    hint: "Species from Caribbean Reef Life — Limpets",
                    systemImage: "circle.fill"
                ),
                Subcategory(
                    id: "snails",
                    title: "Snails",
                    hint: "Species from Caribbean Reef Life — Snails",
                    systemImage: "spiral"
                ),
                Subcategory(
                    id: "conchs",
                    title: "Conchs",
                    hint: "Species from Caribbean Reef Life — Conchs",
                    systemImage: "circle.fill"
                ),
                Subcategory(
                    id: "octopuses",
                    title: "Octopuses",
                    hint: "Species from Caribbean Reef Life — Octopuses",
                    systemImage: "circle.grid.cross.fill"
                ),
                Subcategory(
                    id: "squids",
                    title: "Squids",
                    hint: "Species from Caribbean Reef Life — Squids",
                    systemImage: "circle.grid.cross.fill"
                ),
                Subcategory(
                    id: "shrimps",
                    title: "Shrimps",
                    hint: "Species from Caribbean Reef Life — Shrimps",
                    systemImage: "hand.point.up.left.fill"
                ),
                Subcategory(
                    id: "crabs",
                    title: "Crabs",
                    hint: "Species from Caribbean Reef Life — Crabs",
                    systemImage: "crab.fill"
                ),
                Subcategory(
                    id: "lobsters",
                    title: "Lobsters",
                    hint: "Species from Caribbean Reef Life — Lobsters",
                    systemImage: "crab.fill"
                ),
            ]
        ),
        Category(
            id: "fishes",
            title: "Fishes",
            subtitle: "Family groups for Caribbean reef fish",
            description: "Fish families from Caribbean Reef Life — browse by the group that best matches what you saw.",
            systemImage: "fish.fill",
            heroImageName: "FieldGuideCategoryFish",
            subcategories: [
                Subcategory(
                    id: "gobies",
                    title: "Gobies",
                    hint: "Species from Caribbean Reef Life — Gobies",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "blennies",
                    title: "Blennies",
                    hint: "Species from Caribbean Reef Life — Blennies",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "cardinalfishes",
                    title: "Cardinalfishes",
                    hint: "Species from Caribbean Reef Life — Cardinalfishes",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "squirrelfishes",
                    title: "Squirrelfishes",
                    hint: "Species from Caribbean Reef Life — Squirrelfishes",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "flounders",
                    title: "Flounders",
                    hint: "Species from Caribbean Reef Life — Flounders",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "scorpionfishes",
                    title: "Scorpionfishes",
                    hint: "Species from Caribbean Reef Life — Scorpionfishes",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "frogfishes",
                    title: "Frogfishes",
                    hint: "Species from Caribbean Reef Life — Frogfishes",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "searobins",
                    title: "Searobins",
                    hint: "Species from Caribbean Reef Life — Searobins",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "batfishes",
                    title: "Batfishes",
                    hint: "Species from Caribbean Reef Life — Batfishes",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "lizardfishes",
                    title: "Lizardfishes",
                    hint: "Species from Caribbean Reef Life — Lizardfishes",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "jawfishes",
                    title: "Jawfishes",
                    hint: "Species from Caribbean Reef Life — Jawfishes",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "toadfishes",
                    title: "Toadfishes",
                    hint: "Species from Caribbean Reef Life — Toadfishes",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "clingfishes",
                    title: "Clingfishes",
                    hint: "Species from Caribbean Reef Life — Clingfishes",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "lionfish",
                    title: "Lionfish",
                    hint: "Species from Caribbean Reef Life — Lionfish",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "brotulas",
                    title: "Brotulas",
                    hint: "Species from Caribbean Reef Life — Brotulas",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "seahorses",
                    title: "Seahorses",
                    hint: "Species from Caribbean Reef Life — Seahorses",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "pipefishes",
                    title: "Pipefishes",
                    hint: "Species from Caribbean Reef Life — Pipefishes",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "drums",
                    title: "Drums",
                    hint: "Species from Caribbean Reef Life — Drums",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "damselfishes",
                    title: "Damselfishes",
                    hint: "Species from Caribbean Reef Life — Damselfishes",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "surgeonfishes",
                    title: "Surgeonfishes",
                    hint: "Species from Caribbean Reef Life — Surgeonfishes",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "butterflyfishes",
                    title: "Butterflyfishes",
                    hint: "Species from Caribbean Reef Life — Butterflyfishes",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "angelfishes",
                    title: "Angelfishes",
                    hint: "Species from Caribbean Reef Life — Angelfishes",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "triggerfishes",
                    title: "Triggerfishes",
                    hint: "Species from Caribbean Reef Life — Triggerfishes",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "filefishes",
                    title: "Filefishes",
                    hint: "Species from Caribbean Reef Life — Filefishes",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "puffers",
                    title: "Puffers",
                    hint: "Species from Caribbean Reef Life — Puffers",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "trunkfishes",
                    title: "Trunkfishes",
                    hint: "Species from Caribbean Reef Life — Trunkfishes",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "cowfishes",
                    title: "Cowfishes",
                    hint: "Species from Caribbean Reef Life — Cowfishes",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "grunts",
                    title: "Grunts",
                    hint: "Species from Caribbean Reef Life — Grunts",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "parrotfishes",
                    title: "Parrotfishes",
                    hint: "Species from Caribbean Reef Life — Parrotfishes",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "hogfishes",
                    title: "Hogfishes",
                    hint: "Species from Caribbean Reef Life — Hogfishes",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "razorfishes",
                    title: "Razorfishes",
                    hint: "Species from Caribbean Reef Life — Razorfishes",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "wrasses",
                    title: "Wrasses",
                    hint: "Species from Caribbean Reef Life — Wrasses",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "basslets",
                    title: "Basslets",
                    hint: "Species from Caribbean Reef Life — Basslets",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "basses",
                    title: "Basses",
                    hint: "Species from Caribbean Reef Life — Basses",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "hamlets",
                    title: "Hamlets",
                    hint: "Species from Caribbean Reef Life — Hamlets",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "groupers",
                    title: "Groupers",
                    hint: "Species from Caribbean Reef Life — Groupers",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "snappers",
                    title: "Snappers",
                    hint: "Species from Caribbean Reef Life — Snappers",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "jacks",
                    title: "Jacks",
                    hint: "Species from Caribbean Reef Life — Jacks",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "barracudas",
                    title: "Barracudas",
                    hint: "Species from Caribbean Reef Life — Barracudas",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "trumpetfish",
                    title: "Trumpetfish",
                    hint: "Species from Caribbean Reef Life — Trumpetfish",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "needlefishes",
                    title: "Needlefishes",
                    hint: "Species from Caribbean Reef Life — Needlefishes",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "silversides",
                    title: "Silversides",
                    hint: "Species from Caribbean Reef Life — Silversides",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "silvery-fishes",
                    title: "Silvery Fishes",
                    hint: "Species from Caribbean Reef Life — Silvery Fishes",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "porgies",
                    title: "Porgies",
                    hint: "Species from Caribbean Reef Life — Porgies",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "sharksuckers",
                    title: "Sharksuckers",
                    hint: "Species from Caribbean Reef Life — Sharksuckers",
                    systemImage: "fish.fill"
                ),
                Subcategory(
                    id: "eels",
                    title: "Eels",
                    hint: "Species from Caribbean Reef Life — Eels",
                    systemImage: "waveform.path"
                ),
                Subcategory(
                    id: "rays",
                    title: "Rays",
                    hint: "Species from Caribbean Reef Life — Rays",
                    systemImage: "figure.open.water.swim"
                ),
                Subcategory(
                    id: "sharks",
                    title: "Sharks",
                    hint: "Species from Caribbean Reef Life — Sharks",
                    systemImage: "figure.open.water.swim"
                ),
            ]
        ),
        Category(
            id: "reptiles",
            title: "Reptiles",
            subtitle: "Sea turtles of the Caribbean",
            description: "Reptiles from Caribbean Reef Life.",
            systemImage: "tortoise.fill",
            heroImageName: "FieldGuideCategorySeaTurtle",
            subcategories: [
            ]
        ),
        Category(
            id: "mammals",
            title: "Mammals",
            subtitle: "Cetaceans visiting Caribbean waters",
            description: "Marine mammals from Caribbean Reef Life.",
            systemImage: "wind",
            heroImageName: "FieldGuideCategoryWhale",
            subcategories: [
            ]
        ),
    ]

    nonisolated static var categoryByID: [String: Category] {
        Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
    }

    nonisolated static func category(id: String) -> Category? {
        categoryByID[normalizedCategoryID(id)]
    }

    nonisolated static func subcategory(categoryID: String, subcategoryID: String) -> Subcategory? {
        category(id: categoryID)?.subcategories.first { $0.id == normalizedSubcategoryID(subcategoryID) }
    }

    nonisolated static func resolvedCategoryID(for snapshot: MarineLifeCatalogSnapshot) -> String {
        let stored = normalizedCategoryID(snapshot.category)
        if categoryByID[stored] != nil { return stored }
        return legacyCategoryMapping[stored.lowercased()]?.categoryID ?? stored
    }

    nonisolated static func resolvedSubcategoryID(for snapshot: MarineLifeCatalogSnapshot) -> String {
        let categoryID = resolvedCategoryID(for: snapshot)
        let storedSub = normalizedSubcategoryID(snapshot.subcategory)
        if subcategory(categoryID: categoryID, subcategoryID: storedSub) != nil {
            return storedSub
        }
        let rawCategoryKey = snapshot.category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if categoryByID[normalizedCategoryID(snapshot.category)] == nil,
           let legacySub = legacyCategoryMapping[rawCategoryKey]?.subcategoryID {
            return legacySub
        }
        if let category = category(id: categoryID),
           category.subcategories.count == 1,
           let only = category.subcategories.first {
            return only.id
        }
        return storedSub
    }

    nonisolated static func categoryTitle(for snapshot: MarineLifeCatalogSnapshot) -> String {
        category(id: resolvedCategoryID(for: snapshot))?.title ?? listFallback(snapshot.category)
    }

    nonisolated static func subcategoryTitle(for snapshot: MarineLifeCatalogSnapshot) -> String {
        let categoryID = resolvedCategoryID(for: snapshot)
        let subID = resolvedSubcategoryID(for: snapshot)
        return subcategory(categoryID: categoryID, subcategoryID: subID)?.title ?? listFallback(snapshot.subcategory)
    }

    nonisolated static func normalizedCategoryID(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }

    nonisolated static func normalizedSubcategoryID(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "_", with: "-")
    }

    private nonisolated static func listFallback(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }

    private struct LegacyMapping: Sendable {
        let categoryID: String
        let subcategoryID: String
    }

    private nonisolated static let legacyCategoryMapping: [String: LegacyMapping] = [
        "fish": LegacyMapping(categoryID: "fishes", subcategoryID: "gobies"),
        "ray": LegacyMapping(categoryID: "fishes", subcategoryID: "rays"),
        "reptile": LegacyMapping(categoryID: "reptiles", subcategoryID: ""),
        "cephalopod": LegacyMapping(categoryID: "invertebrates", subcategoryID: "octopuses"),
        "cnidarian": LegacyMapping(categoryID: "invertebrates", subcategoryID: "anemones"),
        "mollusk": LegacyMapping(categoryID: "invertebrates", subcategoryID: "snails"),
        "crustacean": LegacyMapping(categoryID: "invertebrates", subcategoryID: "crabs"),
        "corals": LegacyMapping(categoryID: "corals", subcategoryID: "brain-corals"),
        "sponges": LegacyMapping(categoryID: "sponges", subcategoryID: "barrel-sponges"),
        "worms": LegacyMapping(categoryID: "invertebrates", subcategoryID: "worms"),
        "echinoderms": LegacyMapping(categoryID: "invertebrates", subcategoryID: "sea-stars"),
        "colonial_invertebrates": LegacyMapping(categoryID: "invertebrates", subcategoryID: "tunicates"),
        "other_cnidarians": LegacyMapping(categoryID: "invertebrates", subcategoryID: "jellies"),
        "marine_plants": LegacyMapping(categoryID: "plants", subcategoryID: "green-algae"),
        "marine_reptiles": LegacyMapping(categoryID: "reptiles", subcategoryID: ""),
        "sea_turtles": LegacyMapping(categoryID: "reptiles", subcategoryID: ""),
        "marine_mammals": LegacyMapping(categoryID: "mammals", subcategoryID: ""),
    ]
}

extension FieldGuideTaxonomy.Subcategory: Equatable {
    /// Explicit **nonisolated** equality for **`nonisolated`** taxonomy helpers (Swift 6).
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
            && lhs.title == rhs.title
            && lhs.hint == rhs.hint
            && lhs.systemImage == rhs.systemImage
    }
}

extension FieldGuideTaxonomy.Category: Equatable {
    /// Explicit **nonisolated** equality for **`nonisolated`** taxonomy helpers (Swift 6).
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
            && lhs.title == rhs.title
            && lhs.subtitle == rhs.subtitle
            && lhs.description == rhs.description
            && lhs.systemImage == rhs.systemImage
            && lhs.heroImageName == rhs.heroImageName
            && lhs.subcategories == rhs.subcategories
    }
}
