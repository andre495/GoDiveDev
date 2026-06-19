#!/usr/bin/env python3
"""Unit tests for OpenDiveMap catalog helpers."""

from __future__ import annotations

import unittest

from opendivemap_catalog_utils import (
    best_reference_match,
    combined_match_score,
    feature_to_reference_row,
    name_similarity,
    normalize_site_name_for_match,
)


class OpenDiveMapCatalogUtilsTests(unittest.TestCase):
    def test_normalize_site_name_strips_parenthetical(self) -> None:
        self.assertEqual(
            normalize_site_name_for_match("Salt Pier (Bonaire)"),
            "salt pier",
        )

    def test_name_similarity_exact_and_fuzzy(self) -> None:
        self.assertEqual(name_similarity("Salt Pier", "salt pier"), 1.0)
        self.assertGreater(name_similarity("Salt Pier", "Salt Pier Bonaire"), 0.8)

    def test_feature_to_reference_row_geojson_order(self) -> None:
        row = feature_to_reference_row(
            {
                "geometry": {"coordinates": [-68.283, 12.0835]},
                "properties": {
                    "id": "abc123",
                    "name": "Salt Pier",
                    "country_code": "BQ",
                    "country_name": "Caribbean Netherlands",
                    "max_depth": 30,
                    "entry": "shore",
                    "environment": "ocean",
                    "topologies": ["reef"],
                    "sea_name": "Caribbean Sea",
                },
            }
        )
        self.assertEqual(row["id"], "abc123")
        self.assertEqual(row["latitude"], 12.0835)
        self.assertEqual(row["longitude"], -68.283)

    def test_combined_match_score_name_and_coordinate(self) -> None:
        score = combined_match_score(
            "Salt Pier",
            12.0835,
            -68.283,
            "Salt Pier",
            12.084,
            -68.284,
        )
        self.assertGreaterEqual(score, 0.85)

    def test_best_reference_match_returns_row(self) -> None:
        rows = [
            {
                "id": "one",
                "name": "Unrelated Reef",
                "latitude": 1.0,
                "longitude": 1.0,
            },
            {
                "id": "two",
                "name": "Salt Pier",
                "latitude": 12.0835,
                "longitude": -68.283,
            },
        ]
        match, score = best_reference_match(
            "Salt Pier",
            12.08316,
            -68.2833,
            rows,
            minimum_score=0.85,
        )
        self.assertIsNotNone(match)
        self.assertEqual(match["id"], "two")
        self.assertGreaterEqual(score, 0.85)


if __name__ == "__main__":
    unittest.main()
