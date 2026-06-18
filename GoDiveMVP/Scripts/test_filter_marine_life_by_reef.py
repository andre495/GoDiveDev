"""Tests for REEF fish-only filter."""

from __future__ import annotations

import unittest

from filter_marine_life_by_reef import filter_staging_rows


class FilterMarineLifeByReefTests(unittest.TestCase):
    def test_fish_only_keeps_non_fish_regardless_of_reef(self) -> None:
        reef_keys = {"abudefduf saxatilis"}
        rows = [
            {"category": "fish", "scientificName": "Abudefduf saxatilis"},
            {"category": "fish", "scientificName": "Unknown speciesus"},
            {"category": "corals", "scientificName": "Acropora cervicornis"},
        ]
        kept, removed, kept_by_category, removed_by_category = filter_staging_rows(
            rows,
            reef_keys,
            fish_only=True,
        )
        self.assertEqual(len(kept), 2)
        self.assertEqual(len(removed), 1)
        self.assertEqual(kept_by_category["corals"], 1)
        self.assertEqual(kept_by_category["fish"], 1)
        self.assertEqual(removed_by_category["fish"], 1)

    def test_all_species_filters_every_category(self) -> None:
        reef_keys = {"abudefduf saxatilis"}
        rows = [
            {"category": "fish", "scientificName": "Abudefduf saxatilis"},
            {"category": "corals", "scientificName": "Acropora cervicornis"},
        ]
        kept, removed, _, _ = filter_staging_rows(rows, reef_keys, fish_only=False)
        self.assertEqual(len(kept), 1)
        self.assertEqual(len(removed), 1)


if __name__ == "__main__":
    unittest.main()
