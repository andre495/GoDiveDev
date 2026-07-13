"""Match Caribbean Reef Life (Mickey Charteris) EPUB photos to staging rows.

The CRL 4th-edition EPUB stores ~2,200 species photos in `OEBPS/image/`, named by
species — either the scientific binomial (`Agelas_spectrum_cmyk.jpg`) or the common
name (`African_pompano_cmyk.jpg`), often with a trailing `_cmyk` and/or a `_2` variant
suffix. This module turns those filenames into normalized lookup keys and matches them
against marine-life staging rows by scientific name (preferred) then common name.

IMPORTANT — licensing: CRL photographs are © Mickey Charteris. They require written
permission before shipping in the app bundle. Rows staged from this source are tagged
`imageSource=caribbean-reef-life`, `imageLicense="© Mickey Charteris — permission
required"`, and `imageNeedsReview=yes` — the same hold-for-review pattern as reefguide.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

from fishbase_catalog_utils import normalize_scientific_name_for_match

CRL_IMAGE_SOURCE = "caribbean-reef-life"
CRL_IMAGE_LICENSE = "© Mickey Charteris — permission required"
CRL_IMAGE_ATTRIBUTION = "Caribbean Reef Life (Mickey Charteris, 4th ed.)"
CRL_PROVENANCE_PREFIX = "caribbean-reef-life-4"

_IMAGE_EXTENSION = re.compile(r"\.(jpe?g)$", re.IGNORECASE)
_CMYK_SUFFIX = re.compile(r"[ _-]cmyk$", re.IGNORECASE)
_VARIANT_SUFFIX = re.compile(r"[ _-]\d+$")
_LEADING_COUNT = re.compile(r"^\d+[ _-]+")
_NON_ALNUM = re.compile(r"[^a-z0-9]+")


def is_species_image_filename(filename: str) -> bool:
    """True for `.jpg`/`.jpeg` files (skips `1.png` spacers and non-images)."""
    return bool(_IMAGE_EXTENSION.search(filename.strip()))


def candidate_species_name_from_filename(filename: str) -> str:
    """Best-effort species name encoded in a CRL image filename.

    `African_pompano_cmyk.jpg` -> "african pompano"; `Agelas_spectrum_cmyk.jpg` ->
    "agelas spectrum"; `3_coneys_2.jpg` -> "coneys". Underscores/hyphens become spaces,
    a trailing `_cmyk`/`_2` and a leading count prefix are dropped, casing is lowered.
    """
    base = _IMAGE_EXTENSION.sub("", filename.strip())
    base = _CMYK_SUFFIX.sub("", base)
    base = _VARIANT_SUFFIX.sub("", base)
    base = _LEADING_COUNT.sub("", base)
    base = base.replace("_", " ").replace("-", " ")
    return re.sub(r"\s+", " ", base).strip().lower()


def normalize_common_name(name: str | None) -> str:
    """Lowercase alphanumeric key for common-name matching (spaces collapsed)."""
    return _NON_ALNUM.sub(" ", (name or "").lower()).strip()


@dataclass
class EpubImageIndex:
    """Filename lookup by normalized scientific and common name.

    First filename wins on a key collision so results are deterministic given a sorted
    input; `count` is the number of indexed image files.
    """

    by_scientific: dict[str, str] = field(default_factory=dict)
    by_common: dict[str, str] = field(default_factory=dict)
    count: int = 0


def build_epub_image_index(filenames: list[str]) -> EpubImageIndex:
    """Index CRL image filenames by scientific + common name keys (sorted, stable)."""
    index = EpubImageIndex()
    for filename in sorted(filenames):
        if not is_species_image_filename(filename):
            continue
        index.count += 1
        candidate = candidate_species_name_from_filename(filename)
        if not candidate:
            continue
        sci_key = normalize_scientific_name_for_match(candidate)
        if sci_key and sci_key not in index.by_scientific:
            index.by_scientific[sci_key] = filename
        common_key = normalize_common_name(candidate)
        if common_key and common_key not in index.by_common:
            index.by_common[common_key] = filename
    return index


@dataclass(frozen=True)
class ImageMatch:
    filename: str
    match_kind: str  # "scientific" | "common"


def match_image_for_row(
    scientific_name: str,
    common_name: str,
    index: EpubImageIndex,
) -> ImageMatch | None:
    """Match a staging row to a CRL image, preferring the scientific-name key."""
    sci_key = normalize_scientific_name_for_match(scientific_name)
    if sci_key:
        filename = index.by_scientific.get(sci_key)
        if filename:
            return ImageMatch(filename=filename, match_kind="scientific")

    common_key = normalize_common_name(common_name)
    if common_key:
        filename = index.by_common.get(common_key)
        if filename:
            return ImageMatch(filename=filename, match_kind="common")

    return None


def provenance_marker(filename: str) -> str:
    """Stable provenance string recorded in the bundle photo manifest."""
    return f"{CRL_PROVENANCE_PREFIX}:OEBPS/image/{filename}"
