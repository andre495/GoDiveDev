"""Tests for GBIF occurrence image helpers."""

from __future__ import annotations

import unittest
from pathlib import Path
from unittest.mock import patch

from fetch_marine_life_images_gbif import should_skip_row
from gbif_image_utils import (
    candidates_from_occurrence,
    find_gbif_image,
    gbif_license_label,
    match_gbif_taxon_key,
    media_license_allowed,
)


CC0_URL = "http://creativecommons.org/publicdomain/zero/1.0/"
CC_BY_URL = "http://creativecommons.org/licenses/by/4.0/"
CC_BY_NC_URL = "http://creativecommons.org/licenses/by-nc/4.0/"
CC_BY_SA_URL = "http://creativecommons.org/licenses/by-sa/4.0/"
PHOTO = "https://inaturalist-open-data.s3.amazonaws.com/photos/1/original.jpg"


def _occurrence(*, license: str, basis: str = "HUMAN_OBSERVATION", media_license: str | None = None) -> dict:
    return {
        "gbifID": "123",
        "basisOfRecord": basis,
        "datasetName": "iNaturalist research-grade observations",
        "license": license,
        "media": [
            {
                "type": "StillImage",
                "identifier": PHOTO,
                "license": media_license if media_license is not None else license,
                "creator": "Jane Diver",
                "title": "Holacanthus ciliaris",
            }
        ],
    }


class GbifImageUtilsTests(unittest.TestCase):
    def test_gbif_license_label_maps_urls_and_enums(self) -> None:
        self.assertEqual(gbif_license_label(CC0_URL), "CC0 1.0")
        self.assertEqual(gbif_license_label("CC0_1_0"), "CC0 1.0")
        self.assertEqual(gbif_license_label(CC_BY_URL), "CC BY 4.0")
        self.assertEqual(gbif_license_label("CC_BY_4_0"), "CC BY 4.0")
        self.assertEqual(gbif_license_label(CC_BY_NC_URL), "CC BY-NC")
        self.assertEqual(gbif_license_label(CC_BY_SA_URL), "CC BY-SA")
        self.assertEqual(gbif_license_label("Usage Conditions Apply"), "")

    def test_media_license_allowed(self) -> None:
        self.assertTrue(media_license_allowed(CC0_URL, allow_cc_by=False))
        self.assertTrue(media_license_allowed(CC_BY_URL, allow_cc_by=True))
        self.assertFalse(media_license_allowed(CC_BY_URL, allow_cc_by=False))
        self.assertFalse(media_license_allowed(CC_BY_NC_URL, allow_cc_by=True))
        self.assertFalse(media_license_allowed(CC_BY_SA_URL, allow_cc_by=True))
        self.assertFalse(media_license_allowed("Usage Conditions Apply", allow_cc_by=True))

    def test_skips_nc_media_even_when_occurrence_is_cc0(self) -> None:
        occurrence = _occurrence(license=CC0_URL, media_license=CC_BY_NC_URL)
        self.assertEqual(
            candidates_from_occurrence(occurrence, "Holacanthus ciliaris", allow_cc_by=True),
            [],
        )

    def test_skips_preserved_specimens(self) -> None:
        occurrence = _occurrence(license=CC0_URL, basis="PRESERVED_SPECIMEN")
        self.assertEqual(
            candidates_from_occurrence(occurrence, "Holacanthus ciliaris", allow_cc_by=True),
            [],
        )

    def test_skips_http_identifiers(self) -> None:
        occurrence = _occurrence(license=CC0_URL)
        occurrence["media"][0]["identifier"] = "http://example.com/photo.jpg"
        self.assertEqual(
            candidates_from_occurrence(occurrence, "Holacanthus ciliaris", allow_cc_by=True),
            [],
        )

    def test_keeps_cc0_inat_photo(self) -> None:
        occurrence = _occurrence(license=CC0_URL)
        candidates = candidates_from_occurrence(
            occurrence, "Holacanthus ciliaris", allow_cc_by=True
        )
        self.assertEqual(len(candidates), 1)
        self.assertEqual(candidates[0].source, "gbif")
        self.assertEqual(candidates[0].license, "CC0 1.0")
        self.assertEqual(candidates[0].url, PHOTO)
        self.assertIn("Jane Diver", candidates[0].attribution)
        self.assertIn("123", candidates[0].attribution)

    def test_match_rejects_higher_rank(self) -> None:
        with patch(
            "gbif_image_utils._gbif_get_json",
            return_value={"matchType": "HIGHERRANK", "usageKey": 1, "confidence": 99, "rank": "GENUS"},
        ):
            self.assertIsNone(match_gbif_taxon_key("Holacanthus"))

    def test_match_uses_accepted_usage_key(self) -> None:
        with patch(
            "gbif_image_utils._gbif_get_json",
            return_value={
                "matchType": "EXACT",
                "usageKey": 11,
                "acceptedUsageKey": 22,
                "confidence": 99,
                "rank": "SPECIES",
            },
        ):
            self.assertEqual(match_gbif_taxon_key("Synonymus example"), 22)

    def test_find_gbif_image_uses_media_license_not_occurrence_facet(self) -> None:
        match = {
            "matchType": "EXACT",
            "usageKey": 5211452,
            "confidence": 99,
            "rank": "SPECIES",
        }
        licensed_search = {
            "results": [
                _occurrence(license=CC0_URL, media_license=CC_BY_SA_URL),
            ]
        }
        fallback_search = {
            "results": [
                _occurrence(license=CC_BY_NC_URL, media_license=CC0_URL),
            ]
        }

        def fake_get(url: str, *, sleep_seconds: float = 0.0, retries: int = 1) -> dict:
            del sleep_seconds, retries
            if "species/match" in url:
                return match
            if "license=" in url:
                return licensed_search
            return fallback_search

        with patch("gbif_image_utils._gbif_get_json", side_effect=fake_get):
            candidate = find_gbif_image("Holacanthus ciliaris", request_delay_seconds=0)
        self.assertIsNotNone(candidate)
        assert candidate is not None
        self.assertEqual(candidate.license, "CC0 1.0")
        self.assertEqual(candidate.source, "gbif")

    def test_should_skip_row_default_includes_existing_urls(self) -> None:
        row = {"featureImageURL": "https://example.com/a.jpg", "uuid": "marine-life-x"}
        self.assertFalse(should_skip_row(row, photos_dir=Path("/tmp"), missing_only=False))

    def test_should_skip_row_missing_only_skips_existing_url(self) -> None:
        row = {"featureImageURL": "https://example.com/a.jpg", "uuid": "marine-life-x"}
        self.assertTrue(should_skip_row(row, photos_dir=Path("/tmp"), missing_only=True))


if __name__ == "__main__":
    unittest.main()
