"""Lightweight tests for FishBase catalog helpers (run with unittest)."""

import unittest

from fishbase_catalog_utils import (
    build_diver_visibility_where_clause,
    build_sealifebase_taxon_where_clause,
    cm_to_meters,
    depth_meters,
    fishbase_about_text,
    fishbase_distinctive_features,
    make_uuid,
    normalize_scientific_name_for_match,
    parse_reef_species_export,
    resolve_sealifebase_taxonomy,
    slugify_common_name,
)


class FishbaseCatalogUtilsTests(unittest.TestCase):
    def test_slugify_common_name(self) -> None:
        self.assertEqual(slugify_common_name("French Angelfish"), "french-angelfish")
        self.assertEqual(slugify_common_name("Spotted Eagle Ray"), "spotted-eagle-ray")

    def test_normalize_scientific_name_for_match(self) -> None:
        self.assertEqual(
            normalize_scientific_name_for_match("Chelonia mydas"),
            "chelonia mydas",
        )
        self.assertEqual(
            normalize_scientific_name_for_match("Abudefduf saxatilis (Linnaeus, 1766)"),
            "abudefduf saxatilis",
        )
        self.assertEqual(normalize_scientific_name_for_match("Apogon sp."), "")

    def test_parse_reef_species_export(self) -> None:
        sample = '''sort hint
Image,Species ID,Common Name,Scientific Name,Common Name,Scientific Name
,0013,Arrow Blenny,Lucayablennius zingaro,Blenny,Chaenopsidae
,1011,Armored Anemone,Anthopleura carneola,Cnidarians,Cnidaria
'''
        rows = parse_reef_species_export(sample)
        self.assertEqual(len(rows), 2)
        self.assertEqual(rows[0]["match_key"], "lucayablennius zingaro")
        self.assertEqual(rows[1]["reef_common_name"], "Armored Anemone")

    def test_make_uuid_dedupes_collisions(self) -> None:
        used: set[str] = set()
        first = make_uuid("Angelfish", 3608, used)
        second = make_uuid("Angelfish", 3609, used)
        self.assertEqual(first, "marine-life-angelfish")
        self.assertEqual(second, "marine-life-angelfish-3609")

    def test_cm_to_meters(self) -> None:
        self.assertEqual(cm_to_meters(45), "0.45")
        self.assertEqual(cm_to_meters(0), "")

    def test_depth_meters(self) -> None:
        self.assertEqual(depth_meters(12), "12")
        self.assertEqual(depth_meters(12.4), "12")
        self.assertEqual(depth_meters(12.6), "13")
        self.assertEqual(depth_meters(-1), "")

    def test_fishbase_about_text_prefers_comments(self) -> None:
        self.assertIn(
            "shallow reefs",
            fishbase_about_text("Common in shallow reefs.", "Other ecology note."),
        )
        self.assertEqual(fishbase_about_text("", "Ecology fallback."), "Ecology fallback.")

    def test_fishbase_distinctive_features(self) -> None:
        self.assertEqual(
            fishbase_distinctive_features("short and / or deep"),
            "Body shape: short and / or deep",
        )

    def test_build_diver_visibility_where_clause(self) -> None:
        clause = build_diver_visibility_where_clause(
            {
                "enabled": True,
                "demers_pelag_include": ["reef-associated", "demersal"],
                "include_ecology_coral_reefs": True,
                "max_depth_meters": 130,
            }
        )
        self.assertIn("reef-associated", clause)
        self.assertIn("ecol.CoralReefs", clause)
        self.assertIn("<= 130", clause)
        self.assertEqual(build_diver_visibility_where_clause({"enabled": False}), "")
        self.assertEqual(build_diver_visibility_where_clause(None), "")

    def test_build_diver_visibility_exclude_demers_pelag(self) -> None:
        clause = build_diver_visibility_where_clause(
            {
                "enabled": True,
                "exclude_demers_pelag": ["pelagic-oceanic", "bathypelagic"],
                "include_ecology_coral_reefs": False,
                "max_depth_meters": 130,
            }
        )
        self.assertIn("pelagic-oceanic", clause)
        self.assertNotIn("ecol.CoralReefs", clause)

    def test_resolve_sealifebase_taxonomy(self) -> None:
        config = {
            "class_to_taxonomy": {
                "Anthozoa": {"category": "corals", "subCategory": "corals"},
                "Gastropoda": {"category": "mollusks", "subCategory": "gastropods"},
            },
            "gastropod_order_to_subcategory": {"Nudibranchia": "sea-slugs"},
            "family_to_taxonomy": {},
        }
        self.assertEqual(
            resolve_sealifebase_taxonomy("Anthozoa", "", "Acroporidae", config),
            ("corals", "corals"),
        )
        self.assertEqual(
            resolve_sealifebase_taxonomy("Gastropoda", "Nudibranchia", "Chromodorididae", config),
            ("mollusks", "sea-slugs"),
        )
        self.assertEqual(
            resolve_sealifebase_taxonomy("Gastropoda", "Neogastropoda", "Conidae", config),
            ("mollusks", "gastropods"),
        )

    def test_build_sealifebase_taxon_where_clause(self) -> None:
        clause = build_sealifebase_taxon_where_clause(
            {
                "exclude_classes": ["Actinopterygii", "Aves"],
                "include_phyla": ["Cnidaria", "Mollusca"],
                "chordata_include_classes": ["Ascidiacea"],
            }
        )
        self.assertIn("Actinopterygii", clause)
        self.assertIn("Cnidaria", clause)
        self.assertIn("Ascidiacea", clause)


if __name__ == "__main__":
    unittest.main()
