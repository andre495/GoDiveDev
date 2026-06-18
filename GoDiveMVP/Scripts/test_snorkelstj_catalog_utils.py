"""Tests for snorkelstj.com catalog helpers."""

from __future__ import annotations

import unittest

from snorkelstj_catalog_utils import (
    match_staging_row,
    normalize_common_name_for_match,
    parse_snorkelstj_title,
    similarity_score,
)


class SnorkelstjCatalogUtilsTests(unittest.TestCase):
    def test_parse_snorkelstj_title(self) -> None:
        self.assertEqual(
            parse_snorkelstj_title("Staghorn Coral - Acropora cervicornis - USVI Caribbean"),
            ("Staghorn Coral", "Acropora cervicornis"),
        )
        self.assertEqual(
            parse_snorkelstj_title("Bareye Hermit Crab Dardanus focosus | Caribbean"),
            ("Bareye Hermit Crab", "Dardanus focosus"),
        )

    def test_similarity_score_token_order(self) -> None:
        self.assertGreaterEqual(
            similarity_score("French Grunt", "Grunt French"),
            0.9,
        )

    def test_match_staging_row_exact_and_fuzzy(self) -> None:
        reference = [
            {
                "commonName": "Banded Butterflyfish",
                "common_norm": normalize_common_name_for_match("Banded Butterflyfish"),
                "match_key": "chaetodon striatus",
                "source_url": "https://example.com/banded-butterflyfish.html",
            }
        ]
        exact, score, method = match_staging_row(
            "Banded Butterflyfish",
            "Pomacanthus paru",
            reference,
            threshold=0.88,
        )
        self.assertIsNotNone(exact)
        self.assertEqual(method, "exact_common")
        self.assertEqual(score, 1.0)

        sci_match, sci_score, sci_method = match_staging_row(
            "Butterfish",
            "Chaetodon striatus",
            reference,
            threshold=0.88,
        )
        self.assertIsNotNone(sci_match)
        self.assertEqual(sci_method, "exact_scientific")

        fuzzy, fuzzy_score, fuzzy_method = match_staging_row(
            "Banded butterfly fish",
            "",
            reference,
            threshold=0.88,
        )
        self.assertIsNotNone(fuzzy)
        self.assertEqual(fuzzy_method, "fuzzy_common")


if __name__ == "__main__":
    unittest.main()
