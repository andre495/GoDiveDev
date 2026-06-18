import Foundation

/// Caribbean-oriented field guide hierarchy (Humann-style fish groups + phylum-level inverts).
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
            id: "fish",
            title: "Fish",
            subtitle: "Shape & family groups for reef fish",
            description: "Identify Caribbean reef fish by silhouette and family group — the same organization used in popular underwater field guides. Pick the shape that best matches what you saw on the dive, then browse species within that group.",
            systemImage: "fish.fill",
            heroImageName: "FieldGuideCategoryFish",
            subcategories: [
                Subcategory(id: "sharks-and-rays", title: "Sharks and Rays", hint: "Elasmobranchs on sand and reef", systemImage: "figure.open.water.swim"),
                Subcategory(id: "eels", title: "Eels", hint: "Morays, snake eels, garden eels", systemImage: "waveform.path"),
                Subcategory(id: "disk-and-large-oval", title: "Disk and Large Oval", hint: "Angels, butterflies, batfish", systemImage: "circle.circle"),
                Subcategory(id: "small-oval", title: "Small Oval", hint: "Damselfish, chromis, anthias", systemImage: "circle.fill"),
                Subcategory(id: "silvery", title: "Silvery", hint: "Jacks, herrings, mackerels", systemImage: "sparkles"),
                Subcategory(id: "groupers-and-bass", title: "Groupers and Bass", hint: "Serranids and seabasses", systemImage: "square.stack.3d.up.fill"),
                Subcategory(id: "grunts-and-snappers", title: "Grunts and Snappers", hint: "Haemulids and lutjanids", systemImage: "music.note.list"),
                Subcategory(id: "parrotfish-wrasse-razorfish", title: "Parrotfish, Wrasse and Razorfish", hint: "Labrids, scarids, centriscids", systemImage: "paintbrush.fill"),
                Subcategory(id: "cardinalfish-and-reds", title: "Cardinalfish and Reds", hint: "Apogonids and reddish reef fish", systemImage: "heart.fill"),
                Subcategory(id: "gobies-and-blennies", title: "Gobies and Blennies", hint: "Cryptic reef perchers", systemImage: "eye.fill"),
                Subcategory(id: "bottom-dwellers", title: "Bottom Dwellers", hint: "Flatfish, scorpionfish, sitters", systemImage: "arrow.down.to.line"),
                Subcategory(id: "odd-shaped", title: "Odd Shaped", hint: "Seahorses, frogfish, filefish", systemImage: "star.fill"),
            ]
        ),
        Category(
            id: "corals",
            title: "Corals",
            subtitle: "Reef builders, gorgonians, and soft corals",
            description: "Hard and soft corals, gorgonians, and other colony-building animals that give Caribbean reefs their structure, shelter, and color.",
            systemImage: "leaf.fill",
            heroImageName: "FieldGuideCategoryCoral",
            subcategories: [
                Subcategory(id: "corals", title: "Corals", hint: "Stony, soft, and gorgonian corals", systemImage: "tree.fill"),
            ]
        ),
        Category(
            id: "other_cnidarians",
            title: "Other Cnidarians",
            subtitle: "Anemones, hydroids, and jellies",
            description: "Cnidarians beyond stony corals — including anemones, zoanthids, hydroids, and drifting jellies — often spotted on reef walls and in the water column.",
            systemImage: "aqi.medium",
            heroImageName: "FieldGuideCategoryAnemone",
            subcategories: [
                Subcategory(id: "cnidarians", title: "Cnidarians", hint: "Anemones, zoanthids, hydroids", systemImage: "hand.raised.fill"),
                Subcategory(id: "jellies", title: "Jellies", hint: "Medusae drifting in the water column", systemImage: "drop.fill"),
            ]
        ),
        Category(
            id: "sponges",
            title: "Sponges",
            subtitle: "Filter feeders that shape Caribbean reefs",
            description: "Sponges filter vast amounts of water and add texture to Caribbean reefs — from vivid barrel sponges to encrusting forms on rock and coral.",
            systemImage: "bubbles.and.sparkles.fill",
            heroImageName: "FieldGuideCategoryTubeSponge",
            subcategories: [
                Subcategory(id: "sponges", title: "Sponges", hint: "Barrel, tube, encrusting forms", systemImage: "humidity.fill"),
            ]
        ),
        Category(
            id: "mollusks",
            title: "Mollusks",
            subtitle: "Snails, slugs, clams, and cephalopods",
            description: "A diverse phylum on Caribbean reefs — shelled gastropods, colorful sea slugs, bivalves in sand and rubble, and curious cephalopods that change color in an instant.",
            systemImage: "shell.fill",
            heroImageName: "FieldGuideCategoryMollusk",
            subcategories: [
                Subcategory(id: "gastropods", title: "Gastropods", hint: "Cowries, cones, shelled snails", systemImage: "spiral"),
                Subcategory(id: "sea-slugs", title: "Sea Slugs", hint: "Nudibranchs and allies", systemImage: "leaf.arrow.circlepath"),
                Subcategory(id: "bivalves-and-chitons", title: "Bivalves and Chitons", hint: "Clams, oysters, chitons", systemImage: "capsule.fill"),
                Subcategory(id: "cephalopods", title: "Cephalopods", hint: "Octopus, squid, cuttlefish", systemImage: "circle.grid.cross.fill"),
            ]
        ),
        Category(
            id: "crustaceans",
            title: "Crustaceans",
            subtitle: "Crabs, lobsters, shrimp, and mantis shrimp",
            description: "Crustaceans hide in crevices, walk the sand, and clean other reef residents. Look closely on night dives for shrimps, crabs, and lobsters.",
            systemImage: "crab.fill",
            heroImageName: "FieldGuideCategoryCrab",
            subcategories: [
                Subcategory(id: "crustaceans", title: "Crustaceans", hint: "Decapods and stomatopods", systemImage: "hand.point.up.left.fill"),
            ]
        ),
        Category(
            id: "echinoderms",
            title: "Echinoderms",
            subtitle: "Stars, urchins, cucumbers, and crinoids",
            description: "Sea stars, urchins, cucumbers, and feather stars share five-fold symmetry. Common on reef crests, walls, and sandy patches throughout the Caribbean.",
            systemImage: "staroflife.fill",
            heroImageName: "FieldGuideCategorySeaStar",
            subcategories: [
                Subcategory(id: "echinoderms", title: "Echinoderms", hint: "Five-fold symmetry on the reef", systemImage: "star.circle.fill"),
            ]
        ),
        Category(
            id: "worms",
            title: "Worms & Kin",
            subtitle: "Segmented, flat, and burrowing worms",
            description: "Polychaetes, flatworms, and other worm-like invertebrates — often overlooked until you slow down and scan the reef for movement and vivid patterns.",
            systemImage: "line.3.horizontal",
            heroImageName: "FieldGuideCategoryChristmasTreeWorm",
            subcategories: [
                Subcategory(id: "worms", title: "Worms", hint: "Polychaetes, flatworms, peanut worms", systemImage: "ellipsis.curlybraces"),
            ]
        ),
        Category(
            id: "colonial_invertebrates",
            title: "Colonial Invertebrates",
            subtitle: "Encrusting filter feeders",
            description: "Colonial animals such as tunicates and bryozoans form encrusting mats and delicate lace-like colonies on hard substrate across Caribbean reefs.",
            systemImage: "square.grid.3x3.fill",
            heroImageName: "FieldGuideCategoryTunicateChain",
            subcategories: [
                Subcategory(id: "tunicates-and-bryozoans", title: "Tunicates and Bryozoans", hint: "Sea squirts and lace corals", systemImage: "rectangle.grid.2x2.fill"),
            ]
        ),
        Category(
            id: "marine_reptiles",
            title: "Marine Reptiles",
            subtitle: "Sea turtles and allies",
            description: "Sea turtles are the most frequently encountered marine reptiles in the Caribbean — often seen grazing seagrass or resting under ledges on calm dives.",
            systemImage: "tortoise.fill",
            heroImageName: "FieldGuideCategorySeaTurtle",
            subcategories: [
                Subcategory(id: "turtles", title: "Turtles", hint: "Green, hawksbill, loggerhead", systemImage: "tortoise.fill"),
            ]
        ),
        Category(
            id: "marine_mammals",
            title: "Marine Mammals",
            subtitle: "Cetaceans visiting Caribbean waters",
            description: "Dolphins and whales pass through Caribbean waters — a lucky sight from the boat or, occasionally, on open-water dives.",
            systemImage: "wind",
            heroImageName: "FieldGuideCategoryWhale",
            subcategories: [
                Subcategory(id: "dolphins-and-whales", title: "Dolphins and Whales", hint: "Dolphins, whales, and porpoises", systemImage: "water.waves"),
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
        "fish": LegacyMapping(categoryID: "fish", subcategoryID: "odd-shaped"),
        "ray": LegacyMapping(categoryID: "fish", subcategoryID: "sharks-and-rays"),
        "reptile": LegacyMapping(categoryID: "marine_reptiles", subcategoryID: "turtles"),
        "cephalopod": LegacyMapping(categoryID: "mollusks", subcategoryID: "cephalopods"),
        "cnidarian": LegacyMapping(categoryID: "other_cnidarians", subcategoryID: "cnidarians"),
        "mollusk": LegacyMapping(categoryID: "mollusks", subcategoryID: "gastropods"),
        "crustacean": LegacyMapping(categoryID: "crustaceans", subcategoryID: "crustaceans"),
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
