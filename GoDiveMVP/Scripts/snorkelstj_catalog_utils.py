"""Helpers for snorkelstj.com Caribbean species cross-reference."""

from __future__ import annotations

import re
from difflib import SequenceMatcher

from fishbase_catalog_utils import normalize_scientific_name_for_match

BINOMIAL_IN_TITLE = re.compile(
    r"\b([A-Z][a-z]+(?:-[a-z]+)?)\s+([a-z][a-z-]+(?:\.?\s+sp\.?)?)\b"
)

# Gallery / nav pages — not individual species profiles.
SNORKELSTJ_NAV_PAGES = {
    "index.html",
    "id_gallery.html",
    "fish_gallery.html",
    "creatures_gallery.html",
    "coral_gallery.html",
    "plants-algae_gallery.html",
    "diseases.html",
    "things-that-sting.html",
    "turtles.html",
    "list-species.html",
    "search.html",
    "about_me.html",
    "cool_stuff.html",
    "portfolio.html",
    "log-blog1.html",
    "bacteria-lichens.html",
    "stony-corals_gallery.html",
    "soft-coral_gallery.html",
    "tube-and-cup-coral_gallery.html",
    "hydrocorals_gallery.html",
    "fish_silvery.html",
    "spottedfish_gallery.html",
    "sharks-rays.html",
    "comb-jellyfish_gallery.html",
    "spotted-eagle-ray.html",
}


def normalize_common_name_for_match(name: str | None) -> str:
    if not name:
        return ""
    text = name.lower()
    text = re.sub(r"\([^)]*\)", "", text)
    text = re.sub(r"[^a-z0-9 ]+", " ", text)
    return re.sub(r"\s+", " ", text).strip()


def common_name_tokens(name: str | None) -> str:
    return " ".join(sorted(normalize_common_name_for_match(name).split()))


def parse_snorkelstj_title(title: str) -> tuple[str, str]:
    """Parse species page titles like 'Staghorn Coral - Acropora cervicornis - USVI Caribbean'."""
    cleaned = re.sub(r"\s*(USVI\s*)?Caribbean\s*", "", title, flags=re.IGNORECASE)
    cleaned = cleaned.strip(" -|")

    if " - " in cleaned:
        common, rest = cleaned.split(" - ", 1)
        common, rest = common.strip(), rest.strip()
    else:
        match = BINOMIAL_IN_TITLE.search(cleaned)
        if not match:
            return cleaned.strip(), ""
        return cleaned[: match.start()].strip(), match.group(0).strip()

    match = BINOMIAL_IN_TITLE.search(rest)
    scientific = match.group(0).strip() if match else ""
    return common, scientific


def similarity_score(left: str, right: str) -> float:
    left_norm = normalize_common_name_for_match(left)
    right_norm = normalize_common_name_for_match(right)
    if not left_norm or not right_norm:
        return 0.0
    if left_norm == right_norm:
        return 1.0
    ratio = SequenceMatcher(None, left_norm, right_norm).ratio()
    token_ratio = SequenceMatcher(None, common_name_tokens(left), common_name_tokens(right)).ratio()
    return max(ratio, token_ratio)


def match_staging_row(
    common_name: str,
    scientific_name: str,
    reference_rows: list[dict[str, str]],
    *,
    threshold: float,
) -> tuple[dict[str, str] | None, float, str]:
    staging_common_norm = normalize_common_name_for_match(common_name)
    staging_sci = normalize_scientific_name_for_match(scientific_name)

    best_row: dict[str, str] | None = None
    best_score = 0.0
    best_method = "none"

    for row in reference_rows:
        ref_sci = (row.get("match_key") or "").strip()
        if staging_sci and ref_sci and staging_sci == ref_sci:
            return row, 1.0, "exact_scientific"

        ref_common_norm = (row.get("common_norm") or "").strip()
        if staging_common_norm and ref_common_norm and staging_common_norm == ref_common_norm:
            return row, 1.0, "exact_common"

        score = similarity_score(common_name, row.get("commonName", ""))
        if score > best_score:
            best_score = score
            best_row = row
            best_method = "fuzzy_common"

    if best_row and best_score >= threshold:
        return best_row, best_score, best_method
    return None, best_score, "none"
