"""Tests for apply_marine_life_staging_deletions helpers."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from apply_marine_life_staging_deletions import apply_staging_deletions, marked_rows
from download_marine_life_images import load_staging_rows, write_staging_csv


class ApplyMarineLifeStagingDeletionsTests(unittest.TestCase):
    def test_marked_rows_filters_deletion_flag(self) -> None:
        rows = [
            {"uuid": "keep", "markForDeletion": ""},
            {"uuid": "drop", "markForDeletion": "yes"},
        ]
        self.assertEqual([row["uuid"] for row in marked_rows(rows)], ["drop"])

    def test_apply_staging_deletions_removes_rows_and_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            staging = root / "staging.csv"
            photos = root / "photos"
            photos.mkdir()
            manifest = root / "manifest.json"

            rows = [
                {"uuid": "marine-life-keep", "commonName": "Keep", "markForDeletion": ""},
                {"uuid": "marine-life-drop", "commonName": "Drop", "markForDeletion": "yes"},
            ]
            write_staging_csv(staging, rows)
            (photos / "marine-life-drop.jpg").write_bytes(b"jpeg")
            manifest.write_text(
                json.dumps(
                    {
                        "marine-life-drop": {"sourceURL": "https://example.com/a.jpg"},
                        "marine-life-keep": {"sourceURL": "https://example.com/b.jpg"},
                    }
                ),
                encoding="utf-8",
            )

            summary = apply_staging_deletions(
                staging_path=staging,
                photos_dir=photos,
                manifest_path=manifest,
                json_path=root / "catalog.json",
                delete_photos=True,
                sync_json=False,
                dry_run=False,
            )

            self.assertEqual(summary["removed_count"], 1)
            remaining = load_staging_rows(staging)
            self.assertEqual([row["uuid"] for row in remaining], ["marine-life-keep"])
            self.assertFalse((photos / "marine-life-drop.jpg").exists())
            manifest_data = json.loads(manifest.read_text(encoding="utf-8"))
            self.assertNotIn("marine-life-drop", manifest_data)
            self.assertIn("marine-life-keep", manifest_data)


if __name__ == "__main__":
    unittest.main()
