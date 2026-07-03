"""Tests for marine life image review helpers."""

from __future__ import annotations

import unittest

from fishbase_catalog_utils import staging_row_marked_for_deletion

from marine_life_image_review_store import (
    apply_deletion_mark,
    apply_species_image_approval,
    apply_species_image_update,
    filter_species_records,
    species_review_record,
)


class MarineLifeImageReviewStoreTests(unittest.TestCase):
    def test_species_review_record_prefers_bundled_preview(self) -> None:
        record = species_review_record(
            {
                "uuid": "marine-life-queen-angelfish",
                "commonName": "Queen Angelfish",
                "scientificName": "Holacanthus ciliaris",
                "featureImageURL": "https://example.com/remote.jpg",
                "featureImageResourceName": "marine-life-queen-angelfish",
                "imageNeedsReview": "yes",
            },
            photos_dir=__import__("pathlib").Path("/tmp/nonexistent"),
        )
        self.assertFalse(record["hasBundledPhoto"])
        self.assertEqual(record["previewURL"], "https://example.com/remote.jpg")
        self.assertTrue(record["imageNeedsReview"])
        self.assertIn("Holacanthus", record["wikimediaSearchURL"])

    def test_apply_species_image_update_clears_review_flag_by_default(self) -> None:
        row = {
            "featureImageURL": "",
            "imageNeedsReview": "yes",
            "imageLicense": "",
            "imageAttribution": "",
            "imageSource": "",
        }
        apply_species_image_update(
            row,
            feature_image_url="https://example.com/new.jpg",
            image_source="manual",
        )
        self.assertEqual(row["featureImageURL"], "https://example.com/new.jpg")
        self.assertEqual(row["imageNeedsReview"], "")
        self.assertEqual(row["imageSource"], "manual")

    def test_apply_deletion_mark_writes_csv_flag(self) -> None:
        row = {"markForDeletion": ""}
        apply_deletion_mark(row, mark_for_deletion=True)
        self.assertEqual(row["markForDeletion"], "yes")
        self.assertTrue(staging_row_marked_for_deletion(row))
        apply_deletion_mark(row, mark_for_deletion=False)
        self.assertEqual(row["markForDeletion"], "")
        self.assertFalse(staging_row_marked_for_deletion(row))

    def test_filter_species_records_supports_marked_for_deletion(self) -> None:
        records = [
            {"commonName": "A", "scientificName": "", "uuid": "a", "markForDeletion": True, "hasRemoteURL": True, "hasBundledPhoto": True},
            {"commonName": "B", "scientificName": "", "uuid": "b", "markForDeletion": False, "hasRemoteURL": True, "hasBundledPhoto": True},
        ]
        filtered = filter_species_records(records, filter_key="marked-for-deletion")
        self.assertEqual([item["uuid"] for item in filtered], ["a"])

    def test_apply_species_image_approval_clears_review_flag(self) -> None:
        row = {"imageNeedsReview": "yes"}
        apply_species_image_approval(row)
        self.assertEqual(row["imageNeedsReview"], "")

    def test_filter_species_records_supports_needs_review(self) -> None:
        records = [
            {"commonName": "A", "scientificName": "", "uuid": "a", "imageNeedsReview": True, "hasRemoteURL": True, "hasBundledPhoto": True},
            {"commonName": "B", "scientificName": "", "uuid": "b", "imageNeedsReview": False, "hasRemoteURL": False, "hasBundledPhoto": False},
        ]
        filtered = filter_species_records(records, filter_key="needs-review")
        self.assertEqual([item["uuid"] for item in filtered], ["a"])


if __name__ == "__main__":
    unittest.main()
