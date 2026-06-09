"""Tests for marine life image search helpers."""

import unittest
from unittest.mock import patch

from marine_life_image_utils import (
    ImageCandidate,
    build_attribution,
    build_species_search_queries,
    license_allowed,
    license_is_cc0,
    pick_best_candidate,
    score_image_candidate,
    underwater_content_adjustment,
    wikimedia_thumbnail_url,
)


class MarineLifeImageUtilsTests(unittest.TestCase):
    def test_wikimedia_thumbnail_url(self) -> None:
        full = "https://upload.wikimedia.org/wikipedia/commons/8/83/Pomacanthus_paru_430514191.jpg"
        expected = (
            "https://upload.wikimedia.org/wikipedia/commons/thumb/8/83/"
            "Pomacanthus_paru_430514191.jpg/640px-Pomacanthus_paru_430514191.jpg"
        )
        self.assertEqual(wikimedia_thumbnail_url(full), expected)

    def test_license_allowed(self) -> None:
        self.assertTrue(license_allowed("CC0 1.0", allow_cc_by=False))
        self.assertTrue(license_allowed("CC BY 4.0", allow_cc_by=True))
        self.assertFalse(license_allowed("CC BY 4.0", allow_cc_by=False))
        self.assertFalse(license_allowed("CC BY-NC 4.0", allow_cc_by=True))
        self.assertFalse(license_allowed("CC BY-SA 3.0", allow_cc_by=True))

    def test_build_species_search_queries_adds_underwater_suffixes(self) -> None:
        queries = build_species_search_queries("Pomacanthus paru", ("underwater", "diver"))
        self.assertEqual(
            queries,
            ["Pomacanthus paru underwater", "Pomacanthus paru diver", "Pomacanthus paru"],
        )

    def test_build_species_search_queries_includes_common_name(self) -> None:
        queries = build_species_search_queries(
            "Pomacanthus paru",
            ("underwater",),
            common_name="French angelfish",
        )
        self.assertIn("French angelfish underwater", queries)
        self.assertIn("Pomacanthus paru underwater", queries)

    def test_underwater_content_adjustment(self) -> None:
        positive, rejected = underwater_content_adjustment("Pomacanthus paru underwater scuba")
        negative, negative_rejected = underwater_content_adjustment("distribution map sketch")
        self.assertGreater(positive, 0)
        self.assertFalse(rejected)
        self.assertLess(negative, 0)
        self.assertTrue(negative_rejected)

    def test_score_prefers_underwater_over_map(self) -> None:
        underwater_score, _ = score_image_candidate(
            "Pomacanthus paru",
            title="Pomacanthus paru underwater scuba",
            url="https://example.com/Pomacanthus_paru_underwater.jpg",
            license_text="cc0",
            width=1200,
            height=800,
        )
        map_score, _ = score_image_candidate(
            "Pomacanthus paru",
            title="Pomacanthus paru distribution map",
            url="https://example.com/Pomacanthus_paru_map.jpg",
            license_text="cc0",
            width=1200,
            height=800,
        )
        self.assertGreater(underwater_score, map_score)

    def test_score_prefers_binomial_and_penalizes_juvenile(self) -> None:
        adult_score, adult_review = score_image_candidate(
            "Pomacanthus paru",
            title="Pomacanthus paru adult underwater",
            url="https://example.com/Pomacanthus_paru.jpg",
            license_text="cc0",
            width=1200,
            height=800,
        )
        juvenile_score, _ = score_image_candidate(
            "Pomacanthus paru",
            title="Pomacanthus paru juvenile",
            url="https://example.com/Pomacanthus_paru_juvenile.jpg",
            license_text="cc0",
            width=1200,
            height=800,
        )
        self.assertGreater(adult_score, juvenile_score)
        self.assertFalse(adult_review)

    def test_pick_best_candidate(self) -> None:
        weak = ImageCandidate(
            url="https://example.com/a.jpg",
            thumbnail_url="https://example.com/a.jpg",
            title="random fish",
            license="cc0",
            license_url="",
            attribution="",
            source="wikimedia",
            width=200,
            height=200,
            score=5,
            needs_review=True,
        )
        strong = ImageCandidate(
            url="https://example.com/Pomacanthus_paru.jpg",
            thumbnail_url="https://example.com/Pomacanthus_paru.jpg",
            title="Pomacanthus paru",
            license="cc0",
            license_url="",
            attribution="",
            source="wikimedia",
            width=1200,
            height=800,
            score=70,
            needs_review=False,
        )
        best = pick_best_candidate([weak, strong])
        assert best is not None
        self.assertEqual(best.title, "Pomacanthus paru")

    def test_build_attribution(self) -> None:
        text = build_attribution(
            "File:Pomacanthus paru.jpg",
            "Chris Spain",
            "CC BY 4.0",
            "https://creativecommons.org/licenses/by/4.0/",
        )
        self.assertIn("Chris Spain", text)
        self.assertIn("CC BY 4.0", text)

    def test_license_is_cc0(self) -> None:
        self.assertTrue(license_is_cc0("Public domain"))
        self.assertTrue(license_is_cc0("CC0"))
        self.assertFalse(license_is_cc0("CC BY 4.0"))

    @patch("marine_life_image_utils.search_wikimedia_commons")
    @patch("marine_life_image_utils.search_openverse")
    def test_find_species_image_uses_commons_first(
        self,
        mock_openverse,
        mock_commons,
    ) -> None:
        from marine_life_image_utils import find_species_image

        def commons_side_effect(search_query, scientific_name, **kwargs):
            del kwargs
            if "underwater" in search_query:
                return [
                    ImageCandidate(
                        url="https://upload.wikimedia.org/wikipedia/commons/f/fish.jpg",
                        thumbnail_url="https://upload.wikimedia.org/wikipedia/commons/thumb/f/fish.jpg",
                        title="Holacanthus ciliaris underwater",
                        license="CC0",
                        license_url="",
                        attribution="",
                        source="wikimedia",
                        width=1000,
                        height=700,
                        score=80,
                        needs_review=False,
                    )
                ]
            return []

        mock_commons.side_effect = commons_side_effect
        result = find_species_image("Holacanthus ciliaris", allow_cc_by=True)
        assert result is not None
        self.assertEqual(result.source, "wikimedia")
        mock_openverse.assert_not_called()


if __name__ == "__main__":
    unittest.main()
