"""Shared helpers for FishBase → GoDive marine life catalog scripts."""

from __future__ import annotations

import json
import re
import unicodedata
from pathlib import Path
from typing import Any


SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_DIR = SCRIPT_DIR.parent
DEFAULT_CONFIG_PATH = SCRIPT_DIR / "fishbase_caribbean_config.json"

# CSV columns aligned with marine_life_source.csv + workflow metadata.
STAGING_FIELDNAMES = [
    "uuid",
    "fishbase_spec_code",
    "commonName",
    "featureImageURL",
    "scientificName",
    "category",
    "subCategory",
    "familyName",
    "aboutText",
    "minSizeMeters",
    "maxSizeMeters",
    "minDepthMeters",
    "maxDepthMeters",
    "distinctiveFeatures",
    "Abundance",
    "habitatBehavior",
    "diverReaction",
    "needs_subcategory",
]

# GoDive JSON keys (MarineLifeDTO).
JSON_KEY_BY_STAGING = {
    "uuid": "uuid",
    "commonName": "common_name",
    "featureImageURL": "feature_image",
    "scientificName": "scientific_name",
    "category": "category",
    "subCategory": "subcategory",
    "familyName": "family_name",
    "aboutText": "description",
    "minSizeMeters": "min_size",
    "maxSizeMeters": "max_size",
    "minDepthMeters": "min_depth",
    "maxDepthMeters": "max_depth",
    "distinctiveFeatures": "distinctive_features",
    "Abundance": "abundance",
    "habitatBehavior": "habitat_behavior",
    "diverReaction": "diver_reaction",
}


def load_config(path: Path = DEFAULT_CONFIG_PATH) -> dict[str, Any]:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def normalize_fishbase_text(value: str | None) -> str:
    if not value:
        return ""
    collapsed = re.sub(r"\s+", " ", str(value).strip())
    return collapsed


def fishbase_about_text(comments: str | None, add_rems: str | None) -> str:
    """Primary species narrative from FishBase `species.Comments`, ecology `AddRems` fallback."""
    return normalize_fishbase_text(comments) or normalize_fishbase_text(add_rems)


def fishbase_distinctive_features(body_shape: str | None) -> str:
    text = normalize_fishbase_text(body_shape)
    if not text:
        return ""
    return f"Body shape: {text}"


def build_diver_visibility_where_clause(filter_cfg: dict[str, Any] | None) -> str:
    """SQL AND-clause excluding deep-pelagic / non-reef species divers rarely see."""
    if not filter_cfg or not filter_cfg.get("enabled", True):
        return ""

    habitat_parts: list[str] = []
    includes = filter_cfg.get("demers_pelag_include") or []
    if includes:
        quoted = ", ".join(f"'{value}'" for value in includes)
        habitat_parts.append(f"lower(s.DemersPelag) IN ({quoted})")
    if filter_cfg.get("include_ecology_coral_reefs", True):
        habitat_parts.append("coalesce(ecol.CoralReefs, 0) = 1")

    if not habitat_parts:
        return ""

    clauses = [f"({' OR '.join(habitat_parts)})"]
    max_depth = filter_cfg.get("max_depth_meters")
    if max_depth is not None:
        clauses.append(f"coalesce(s.DepthRangeDeep, 999) <= {int(max_depth)}")

    return "AND " + " AND ".join(clauses)


def slugify_common_name(name: str) -> str:
    normalized = unicodedata.normalize("NFKD", name)
    ascii_name = normalized.encode("ascii", "ignore").decode("ascii")
    slug = re.sub(r"[^a-z0-9]+", "-", ascii_name.lower()).strip("-")
    return slug or "unknown-species"


def make_uuid(common_name: str, spec_code: int, used: set[str]) -> str:
    base = f"marine-life-{slugify_common_name(common_name)}"
    candidate = base
    if candidate in used:
        candidate = f"{base}-{spec_code}"
    if candidate in used:
        candidate = f"{base}-fb{spec_code}"
    used.add(candidate)
    return candidate


def cm_to_meters(value: float | None) -> str:
    if value is None:
        return ""
    try:
        numeric = float(value)
    except (TypeError, ValueError):
        return ""
    if numeric <= 0:
        return ""
    return f"{numeric / 100:.4f}".rstrip("0").rstrip(".")


def depth_meters(value: int | float | None) -> str:
    if value is None:
        return ""
    try:
        numeric = float(value)
    except (TypeError, ValueError):
        return ""
    if numeric < 0:
        return ""
    return str(int(numeric)) if numeric == int(numeric) else f"{numeric:.1f}"


def empty_user_fields() -> dict[str, str]:
    return prose_fields_from_fishbase(None, None, None)


def prose_fields_from_fishbase(
    comments: str | None,
    body_shape: str | None,
    add_rems: str | None,
) -> dict[str, str]:
    return {
        "featureImageURL": "",
        "aboutText": fishbase_about_text(comments, add_rems),
        "distinctiveFeatures": fishbase_distinctive_features(body_shape),
        "Abundance": "",
        "habitatBehavior": "",
        "diverReaction": "",
        "minSizeMeters": "",
    }


def staging_row_to_json(row: dict[str, str]) -> dict[str, Any]:
    payload: dict[str, Any] = {"uuid": row["uuid"].strip()}
    for staging_key, json_key in JSON_KEY_BY_STAGING.items():
        if staging_key == "uuid":
            continue
        raw = row.get(staging_key, "")
        if raw is None:
            continue
        text = str(raw).strip()
        if not text:
            continue
        if staging_key in {
            "minSizeMeters",
            "maxSizeMeters",
            "minDepthMeters",
            "maxDepthMeters",
        }:
            try:
                payload[json_key] = float(text)
            except ValueError:
                continue
        else:
            payload[json_key] = text
    return payload
