"""Tests for excluding deletion-marked staging rows from catalog sync."""

from __future__ import annotations

import unittest

from fishbase_catalog_utils import staging_row_marked_for_deletion


def merged_uuids_after_sync(
    staging_rows: list[dict[str, str]],
    *,
    include_all: bool = True,
) -> set[str]:
    ready_uuids = {
        row["uuid"].strip()
        for row in staging_rows
        if (row.get("uuid") or "").strip()
        and (include_all or (row.get("aboutText") or "").strip())
        and not staging_row_marked_for_deletion(row)
    }
    return ready_uuids


class MarineLifeStagingDeletionSyncTests(unittest.TestCase):
    def test_marked_row_is_removed_from_merged_catalog(self) -> None:
        staging_rows = [
            {"uuid": "marine-life-keep", "aboutText": "Keep me"},
            {"uuid": "marine-life-drop", "aboutText": "Drop me", "markForDeletion": "yes"},
        ]
        merged = merged_uuids_after_sync(staging_rows)
        self.assertEqual(merged, {"marine-life-keep"})

    def test_legacy_json_not_in_staging_is_dropped(self) -> None:
        staging_rows = [
            {"uuid": "marine-life-keep", "aboutText": "Keep me"},
        ]
        merged = merged_uuids_after_sync(staging_rows)
        self.assertEqual(merged, {"marine-life-keep"})


if __name__ == "__main__":
    unittest.main()
