#!/usr/bin/env python3
"""Generate FieldGuideTaxonomy.swift categories from Caribbean Reef Life EPUB TOC."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from caribbean_reef_life_catalog_utils import (
    CRL_CATEGORY_DISPLAY_TITLES,
    extract_crl_taxonomy_from_epub,
)
from fishbase_catalog_utils import PROJECT_DIR, load_config

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_CONFIG_PATH = SCRIPT_DIR / "caribbean_reef_life_config.json"
SWIFT_PATH = PROJECT_DIR / "Data" / "FieldGuideTaxonomy.swift"
TAXONOMY_JSON_PATH = PROJECT_DIR / "MockData" / "caribbean_reef_life_taxonomy.json"

CATEGORY_META: dict[str, tuple[str, str | None, str, str]] = {
    "plants": (
        "leaf.fill",
        None,
        "Algae, seagrasses, and mangroves",
        "Plants and algae from Caribbean Reef Life.",
    ),
    "sponges": (
        "bubbles.and.sparkles.fill",
        "FieldGuideCategoryTubeSponge",
        "Filter feeders that shape Caribbean reefs",
        "Sponge groups from Caribbean Reef Life — barrel, tube, rope, and encrusting forms.",
    ),
    "corals": (
        "leaf.fill",
        "FieldGuideCategoryCoral",
        "Reef builders, gorgonians, and soft corals",
        "Hard and soft coral groups from Caribbean Reef Life.",
    ),
    "invertebrates": (
        "ant.fill",
        "FieldGuideCategoryAnemone",
        "Anemones, worms, mollusks, crustaceans, and more",
        "Invertebrate groups from Caribbean Reef Life.",
    ),
    "fishes": (
        "fish.fill",
        "FieldGuideCategoryFish",
        "Family groups for Caribbean reef fish",
        "Fish families from Caribbean Reef Life — browse by the group that best matches what you saw.",
    ),
    "reptiles": (
        "tortoise.fill",
        "FieldGuideCategorySeaTurtle",
        "Sea turtles of the Caribbean",
        "Reptiles from Caribbean Reef Life.",
    ),
    "mammals": (
        "wind",
        "FieldGuideCategoryWhale",
        "Cetaceans visiting Caribbean waters",
        "Marine mammals from Caribbean Reef Life.",
    ),
}

SUBCATEGORY_ICONS: dict[str, str] = {
    "jellies": "drop.fill",
    "anemones": "hand.raised.fill",
    "zoanthids": "circle.grid.2x2.fill",
    "nudibranchs": "leaf.arrow.circlepath",
    "sea-slugs": "leaf.arrow.circlepath",
    "octopuses": "circle.grid.cross.fill",
    "squids": "circle.grid.cross.fill",
    "sharks": "figure.open.water.swim",
    "rays": "figure.open.water.swim",
    "eels": "waveform.path",
    "crabs": "crab.fill",
    "lobsters": "crab.fill",
    "shrimps": "hand.point.up.left.fill",
    "snails": "spiral",
    "clams": "capsule.fill",
    "oysters": "capsule.fill",
    "brittle-stars": "star.circle.fill",
    "sea-stars": "star.circle.fill",
    "sea-urchins": "star.circle.fill",
    "sea-cucumbers": "star.circle.fill",
    "crinoids": "star.circle.fill",
    "tunicates": "rectangle.grid.2x2.fill",
    "bryozoans": "rectangle.grid.2x2.fill",
    "flatworms": "ellipsis.curlybraces",
    "worms": "ellipsis.curlybraces",
    "feather-dusters": "ellipsis.curlybraces",
}


def swift_string(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')


def subcategory_icon(subcategory_id: str, category_id: str) -> str:
    return SUBCATEGORY_ICONS.get(
        subcategory_id,
        "fish.fill" if category_id == "fishes" else "circle.fill",
    )


def render_categories_block(taxonomy: dict) -> str:
    lines: list[str] = ["    nonisolated static let categories: [Category] = ["]
    for category in taxonomy["categories"]:
        category_id = category["id"]
        icon, hero, subtitle, description = CATEGORY_META.get(
            category_id,
            ("circle.fill", None, category["title"], f"{category['title']} from Caribbean Reef Life."),
        )
        display_title = CRL_CATEGORY_DISPLAY_TITLES.get(category_id, category["title"])
        hero_expr = f'"{swift_string(hero)}"' if hero else "nil"
        lines.append("        Category(")
        lines.append(f'            id: "{swift_string(category_id)}",')
        lines.append(f'            title: "{swift_string(display_title)}",')
        lines.append(f'            subtitle: "{swift_string(subtitle)}",')
        lines.append(f'            description: "{swift_string(description)}",')
        lines.append(f'            systemImage: "{swift_string(icon)}",')
        lines.append(f"            heroImageName: {hero_expr},")
        lines.append("            subcategories: [")
        for sub in category["subcategories"]:
            sub_icon = subcategory_icon(sub["id"], category_id)
            hint = f"Species from Caribbean Reef Life — {sub['title']}"
            lines.append("                Subcategory(")
            lines.append(f'                    id: "{swift_string(sub["id"])}",')
            lines.append(f'                    title: "{swift_string(sub["title"])}",')
            lines.append(f'                    hint: "{swift_string(hint)}",')
            lines.append(f'                    systemImage: "{swift_string(sub_icon)}"')
            lines.append("                ),")
        lines.append("            ]")
        lines.append("        ),")
    lines.append("    ]")
    return "\n".join(lines)


def render_swift_file(taxonomy: dict) -> str:
    categories_block = render_categories_block(taxonomy)
    return f"""import Foundation

/// Caribbean Reef Life (Mickey Charteris) field guide hierarchy — generated from EPUB TOC.
/// Regenerate: python3 GoDiveMVP/Scripts/generate_field_guide_taxonomy_swift.py
enum FieldGuideTaxonomy {{

    struct Subcategory: Sendable, Identifiable {{
        let id: String
        let title: String
        let hint: String
        let systemImage: String
    }}

    struct Category: Sendable, Identifiable {{
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

        var subcategoryIDs: [String] {{ subcategories.map(\\.id) }}
    }}

{categories_block}

    nonisolated static var categoryByID: [String: Category] {{
        Dictionary(uniqueKeysWithValues: categories.map {{ ($0.id, $0) }})
    }}

    nonisolated static func category(id: String) -> Category? {{
        categoryByID[normalizedCategoryID(id)]
    }}

    nonisolated static func subcategory(categoryID: String, subcategoryID: String) -> Subcategory? {{
        category(id: categoryID)?.subcategories.first {{ $0.id == normalizedSubcategoryID(subcategoryID) }}
    }}

    nonisolated static func resolvedCategoryID(for snapshot: MarineLifeCatalogSnapshot) -> String {{
        let stored = normalizedCategoryID(snapshot.category)
        if categoryByID[stored] != nil {{ return stored }}
        return legacyCategoryMapping[stored.lowercased()]?.categoryID ?? stored
    }}

    nonisolated static func resolvedSubcategoryID(for snapshot: MarineLifeCatalogSnapshot) -> String {{
        let categoryID = resolvedCategoryID(for: snapshot)
        let storedSub = normalizedSubcategoryID(snapshot.subcategory)
        if subcategory(categoryID: categoryID, subcategoryID: storedSub) != nil {{
            return storedSub
        }}
        let rawCategoryKey = snapshot.category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if categoryByID[normalizedCategoryID(snapshot.category)] == nil,
           let legacySub = legacyCategoryMapping[rawCategoryKey]?.subcategoryID {{
            return legacySub
        }}
        if let category = category(id: categoryID),
           category.subcategories.count == 1,
           let only = category.subcategories.first {{
            return only.id
        }}
        return storedSub
    }}

    nonisolated static func categoryTitle(for snapshot: MarineLifeCatalogSnapshot) -> String {{
        category(id: resolvedCategoryID(for: snapshot))?.title ?? listFallback(snapshot.category)
    }}

    nonisolated static func subcategoryTitle(for snapshot: MarineLifeCatalogSnapshot) -> String {{
        let categoryID = resolvedCategoryID(for: snapshot)
        let subID = resolvedSubcategoryID(for: snapshot)
        return subcategory(categoryID: categoryID, subcategoryID: subID)?.title ?? listFallback(snapshot.subcategory)
    }}

    nonisolated static func normalizedCategoryID(_ raw: String) -> String {{
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }}

    nonisolated static func normalizedSubcategoryID(_ raw: String) -> String {{
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "_", with: "-")
    }}

    private nonisolated static func listFallback(_ raw: String) -> String {{
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }}

    private struct LegacyMapping: Sendable {{
        let categoryID: String
        let subcategoryID: String
    }}

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
}}

extension FieldGuideTaxonomy.Subcategory: Equatable {{
    /// Explicit **nonisolated** equality for **`nonisolated`** taxonomy helpers (Swift 6).
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {{
        lhs.id == rhs.id
            && lhs.title == rhs.title
            && lhs.hint == rhs.hint
            && lhs.systemImage == rhs.systemImage
    }}
}}

extension FieldGuideTaxonomy.Category: Equatable {{
    /// Explicit **nonisolated** equality for **`nonisolated`** taxonomy helpers (Swift 6).
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {{
        lhs.id == rhs.id
            && lhs.title == rhs.title
            && lhs.subtitle == rhs.subtitle
            && lhs.description == rhs.description
            && lhs.systemImage == rhs.systemImage
            && lhs.heroImageName == rhs.heroImageName
            && lhs.subcategories == rhs.subcategories
    }}
}}
"""


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG_PATH)
    parser.add_argument("--epub", type=Path)
    args = parser.parse_args()

    config = load_config(args.config)
    epub_path = args.epub
    if epub_path is None:
        default_epub = config.get("default_epub_path")
        if not default_epub:
            print("Pass --epub or set default_epub_path.", file=sys.stderr)
            return 1
        epub_path = Path(default_epub)
        if not epub_path.is_absolute():
            epub_path = PROJECT_DIR / epub_path
    epub_path = epub_path.expanduser()

    if not epub_path.exists():
        print(f"EPUB not found: {epub_path}", file=sys.stderr)
        return 1

    taxonomy = extract_crl_taxonomy_from_epub(epub_path)
    TAXONOMY_JSON_PATH.parent.mkdir(parents=True, exist_ok=True)
    with TAXONOMY_JSON_PATH.open("w", encoding="utf-8") as handle:
        json.dump(taxonomy, handle, indent=2)
        handle.write("\n")

    SWIFT_PATH.write_text(render_swift_file(taxonomy), encoding="utf-8")

    category_count = len(taxonomy["categories"])
    sub_count = sum(len(cat["subcategories"]) for cat in taxonomy["categories"])
    print(f"Wrote {TAXONOMY_JSON_PATH}")
    print(f"Wrote {SWIFT_PATH} ({category_count} categories, {sub_count} subcategories)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
