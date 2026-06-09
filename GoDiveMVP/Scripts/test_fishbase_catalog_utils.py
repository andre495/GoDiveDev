"""Lightweight tests for FishBase catalog helpers (run with unittest)."""

import unittest

from fishbase_catalog_utils import (
    build_diver_visibility_where_clause,
    cm_to_meters,
    depth_meters,
    fishbase_about_text,
    fishbase_distinctive_features,
    make_uuid,
    slugify_common_name,
)


class FishbaseCatalogUtilsTests(unittest.TestCase):
    def test_slugify_common_name(self) -> None:
        self.assertEqual(slugify_common_name("French Angelfish"), "french-angelfish")
        self.assertEqual(slugify_common_name("Spotted Eagle Ray"), "spotted-eagle-ray")

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


if __name__ == "__main__":
    unittest.main()
