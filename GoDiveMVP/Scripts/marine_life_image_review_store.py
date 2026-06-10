"""Read/update marine life staging rows for the local image review UI."""

from __future__ import annotations

import urllib.parse
from pathlib import Path
from typing import Any

from fishbase_catalog_utils import PROJECT_DIR, staging_row_marked_for_deletion
from marine_life_bundle_image_utils import bundle_photo_filename

DEFAULT_STAGING = PROJECT_DIR / "MockData/marine_life_caribbean_staging.csv"
DEFAULT_PHOTOS_DIR = PROJECT_DIR / "Resources/MarineLifePhotos"


def wikimedia_commons_search_url(scientific_name: str, common_name: str = "") -> str:
    query = scientific_name.strip() or common_name.strip()
    if not query:
        return "https://commons.wikimedia.org/wiki/Main_Page"
    search = f"{query} underwater"
    return (
        "https://commons.wikimedia.org/w/index.php?"
        + urllib.parse.urlencode({"search": search, "title": "Special:MediaSearch", "type": "image"})
    )


def species_review_record(
    row: dict[str, str],
    *,
    photos_dir: Path = DEFAULT_PHOTOS_DIR,
) -> dict[str, Any]:
    uuid = (row.get("uuid") or "").strip()
    bundled_path = photos_dir / bundle_photo_filename(uuid) if uuid else None
    has_bundled = bool(bundled_path and bundled_path.exists())
    feature_image_url = (row.get("featureImageURL") or "").strip()
    needs_review = (row.get("imageNeedsReview") or "").strip().lower() == "yes"
    marked_for_deletion = staging_row_marked_for_deletion(row)

    return {
        "uuid": uuid,
        "commonName": (row.get("commonName") or "").strip(),
        "scientificName": (row.get("scientificName") or "").strip(),
        "featureImageURL": feature_image_url,
        "featureImageResourceName": (row.get("featureImageResourceName") or "").strip(),
        "hasBundledPhoto": has_bundled,
        "hasRemoteURL": bool(feature_image_url),
        "imageNeedsReview": needs_review,
        "markForDeletion": marked_for_deletion,
        "imageLicense": (row.get("imageLicense") or "").strip(),
        "imageAttribution": (row.get("imageAttribution") or "").strip(),
        "imageSource": (row.get("imageSource") or "").strip(),
        "bundledPhotoURL": f"/photos/{bundle_photo_filename(uuid)}" if has_bundled else "",
        "previewURL": f"/photos/{bundle_photo_filename(uuid)}" if has_bundled else feature_image_url,
        "wikimediaSearchURL": wikimedia_commons_search_url(
            (row.get("scientificName") or "").strip(),
            (row.get("commonName") or "").strip(),
        ),
    }


def list_species_records(
    rows: list[dict[str, str]],
    *,
    photos_dir: Path = DEFAULT_PHOTOS_DIR,
) -> list[dict[str, Any]]:
    records = [species_review_record(row, photos_dir=photos_dir) for row in rows if (row.get("uuid") or "").strip()]
    return sorted(records, key=lambda item: (item.get("commonName") or item.get("scientificName") or "").lower())


def find_row(rows: list[dict[str, str]], uuid: str) -> dict[str, str] | None:
    target = uuid.strip()
    for row in rows:
        if (row.get("uuid") or "").strip() == target:
            return row
    return None


def apply_deletion_mark(row: dict[str, str], *, mark_for_deletion: bool) -> None:
    row["markForDeletion"] = "yes" if mark_for_deletion else ""


def apply_species_image_update(
    row: dict[str, str],
    *,
    feature_image_url: str,
    image_needs_review: bool | None = None,
    image_license: str | None = None,
    image_attribution: str | None = None,
    image_source: str | None = None,
) -> None:
    row["featureImageURL"] = feature_image_url.strip()
    if image_license is not None:
        row["imageLicense"] = image_license.strip()
    if image_attribution is not None:
        row["imageAttribution"] = image_attribution.strip()
    if image_source is not None:
        row["imageSource"] = image_source.strip() or "manual"
    if image_needs_review is not None:
        row["imageNeedsReview"] = "yes" if image_needs_review else ""
    elif row["featureImageURL"]:
        row["imageNeedsReview"] = ""


def filter_species_records(
    records: list[dict[str, Any]],
    *,
    query: str = "",
    filter_key: str = "all",
) -> list[dict[str, Any]]:
    normalized_query = query.strip().lower()
    filtered: list[dict[str, Any]] = []
    for record in records:
        if filter_key == "marked-for-deletion" and not record.get("markForDeletion"):
            continue
        if filter_key == "needs-review" and not record.get("imageNeedsReview"):
            continue
        if filter_key == "no-image" and (record.get("hasRemoteURL") or record.get("hasBundledPhoto")):
            continue
        if filter_key == "no-bundle" and record.get("hasBundledPhoto"):
            continue
        if filter_key == "has-url-no-bundle" and (
            not record.get("hasRemoteURL") or record.get("hasBundledPhoto")
        ):
            continue
        if normalized_query:
            haystack = " ".join(
                [
                    str(record.get("commonName") or ""),
                    str(record.get("scientificName") or ""),
                    str(record.get("uuid") or ""),
                ]
            ).lower()
            if normalized_query not in haystack:
                continue
        filtered.append(record)
    return filtered
