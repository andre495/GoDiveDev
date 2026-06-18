"""Shared helpers for FishBase / SeaLifeBase → GoDive marine life catalog scripts."""

from __future__ import annotations

import csv
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
    "featureImageResourceName",
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

# Optional columns on marine_life_caribbean_staging.csv (image review workflow).
IMAGE_WORKFLOW_FIELDNAMES = [
    "imageLicense",
    "imageAttribution",
    "imageSource",
    "imageNeedsReview",
    "markForDeletion",
]

STAGING_WITH_IMAGE_FIELDS = STAGING_FIELDNAMES + [
    field for field in IMAGE_WORKFLOW_FIELDNAMES if field not in STAGING_FIELDNAMES
]


def staging_row_marked_for_deletion(row: dict[str, str]) -> bool:
    return (row.get("markForDeletion") or "").strip().lower() == "yes"


# GoDive JSON keys (MarineLifeDTO).
JSON_KEY_BY_STAGING = {
    "uuid": "uuid",
    "commonName": "common_name",
    "featureImageURL": "feature_image",
    "featureImageResourceName": "feature_image_resource",
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

    clauses: list[str] = []
    habitat_parts: list[str] = []
    includes = filter_cfg.get("demers_pelag_include") or []
    if includes:
        quoted = ", ".join(f"'{value}'" for value in includes)
        habitat_parts.append(f"lower(s.DemersPelag) IN ({quoted})")
    if filter_cfg.get("include_ecology_coral_reefs", True):
        habitat_parts.append("coalesce(ecol.CoralReefs, 0) = 1")
    if habitat_parts:
        clauses.append(f"({' OR '.join(habitat_parts)})")

    excludes = filter_cfg.get("exclude_demers_pelag") or []
    if excludes:
        quoted = ", ".join(f"'{value}'" for value in excludes)
        clauses.append(
            f"coalesce(nullif(trim(lower(s.DemersPelag)), ''), 'unknown') NOT IN ({quoted})"
        )

    max_depth = filter_cfg.get("max_depth_meters")
    if max_depth is not None:
        clauses.append(f"coalesce(s.DepthRangeDeep, 999) <= {int(max_depth)}")

    if not clauses:
        return ""

    return "AND " + " AND ".join(clauses)


def resolve_sealifebase_taxonomy(
    class_name: str | None,
    order_name: str | None,
    family_name: str | None,
    config: dict[str, Any],
) -> tuple[str, str]:
    """Map SeaLifeBase class/order/family to GoDive category + subCategory IDs."""
    cls = (class_name or "").strip()
    order = (order_name or "").strip()
    family = (family_name or "").strip()

    order_map: dict[str, dict[str, str]] = config.get("order_to_taxonomy", {})
    if order in order_map:
        entry = order_map[order]
        return entry["category"], entry["subCategory"]

    gastropod_map: dict[str, str] = config.get("gastropod_order_to_subcategory", {})
    if cls == "Gastropoda" and order in gastropod_map:
        return "mollusks", gastropod_map[order]

    family_map: dict[str, dict[str, str]] = config.get("family_to_taxonomy", {})
    if family in family_map:
        entry = family_map[family]
        return entry["category"], entry["subCategory"]

    class_map: dict[str, dict[str, str]] = config.get("class_to_taxonomy", {})
    if cls in class_map:
        entry = class_map[cls]
        return entry["category"], entry["subCategory"]

    return "", ""


def build_sealifebase_taxon_where_clause(config: dict[str, Any]) -> str:
    """SQL AND-clause limiting SeaLifeBase extract to diver-relevant invertebrate phyla."""
    exclude_classes = config.get("exclude_classes") or []
    include_phyla = config.get("include_phyla") or []
    chordata_classes = config.get("chordata_include_classes") or []
    include_orders = config.get("include_orders") or []

    clauses: list[str] = []
    if exclude_classes:
        quoted = ", ".join(f"'{value}'" for value in exclude_classes)
        exclude = f"coalesce(cl.Class, 'Not assigned') NOT IN ({quoted})"
        if include_orders:
            order_quoted = ", ".join(f"'{value}'" for value in include_orders)
            exclude = f"({exclude} OR f.Order IN ({order_quoted}))"
        clauses.append(exclude)

    phylum_parts: list[str] = []
    if include_phyla:
        quoted = ", ".join(f"'{value}'" for value in include_phyla)
        phylum_parts.append(f"f.Phylum IN ({quoted})")
    if chordata_classes:
        quoted = ", ".join(f"'{value}'" for value in chordata_classes)
        phylum_parts.append(f"(f.Phylum = 'Chordata' AND cl.Class IN ({quoted}))")
    if include_orders:
        quoted = ", ".join(f"'{value}'" for value in include_orders)
        phylum_parts.append(f"f.Order IN ({quoted})")

    if phylum_parts:
        clauses.append(f"({' OR '.join(phylum_parts)})")

    if not clauses:
        return ""

    return "AND " + " AND ".join(clauses)


def apply_diver_visibility_bypass(
    diver_where: str,
    bypass_classes: list[str] | None,
    bypass_orders: list[str] | None = None,
) -> str:
    """Allow selected taxa to bypass recreational depth/pelagic filters."""
    if not diver_where:
        return diver_where
    bypass_parts: list[str] = []
    if bypass_classes:
        quoted = ", ".join(f"'{value}'" for value in bypass_classes)
        bypass_parts.append(f"coalesce(cl.Class, '') IN ({quoted})")
    if bypass_orders:
        quoted = ", ".join(f"'{value}'" for value in bypass_orders)
        bypass_parts.append(f"coalesce(f.Order, '') IN ({quoted})")
    if not bypass_parts:
        return diver_where
    inner = diver_where.removeprefix("AND ").strip()
    return f"AND (({inner}) OR {' OR '.join(bypass_parts)})"


def staging_fieldnames_for_path(path: Path) -> list[str]:
    """Use an existing staging CSV header when present (preserves image workflow columns)."""
    if not path.is_file():
        return STAGING_WITH_IMAGE_FIELDS
    with path.open(encoding="utf-8", newline="") as handle:
        reader = csv.reader(handle)
        header = next(reader, None)
    if not header:
        return STAGING_WITH_IMAGE_FIELDS
    return header


def read_staging_rows(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    if not path.is_file():
        return STAGING_WITH_IMAGE_FIELDS, []
    with path.open(encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        fieldnames = reader.fieldnames or STAGING_WITH_IMAGE_FIELDS
        rows = [dict(row) for row in reader]
    return list(fieldnames), rows


def empty_image_workflow_fields() -> dict[str, str]:
    return {field: "" for field in IMAGE_WORKFLOW_FIELDNAMES}


def normalize_scientific_name_for_match(name: str | None) -> str:
    """Normalize a scientific name for cross-dataset matching (genus + species)."""
    if not name:
        return ""
    normalized = unicodedata.normalize("NFKD", str(name))
    ascii_name = normalized.encode("ascii", "ignore").decode("ascii")
    text = re.sub(r"\([^)]*\)", "", ascii_name.lower())
    text = re.sub(r"[^a-z0-9. ]+", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    parts = text.split()
    if len(parts) < 2:
        return text
    genus, species = parts[0], parts[1].rstrip(".")
    if species in {"sp", "spp"}:
        return ""
    return f"{genus} {species}"


def parse_reef_species_export(csv_text: str) -> list[dict[str, str]]:
    """Parse REEF species reference CSV export rows."""
    rows: list[dict[str, str]] = []
    reader = csv.reader(csv_text.splitlines())
    next(reader, None)  # sort hint row
    header = next(reader, None)
    if not header:
        return rows
    for row in reader:
        if len(row) < 4:
            continue
        species_id = row[1].strip().strip('"') if len(row) > 1 else ""
        common_name = row[2].strip().strip('"') if len(row) > 2 else ""
        scientific_name = row[3].strip().strip('"') if len(row) > 3 else ""
        family_common = row[4].strip().strip('"') if len(row) > 4 else ""
        family_scientific = row[5].strip().strip('"') if len(row) > 5 else ""
        is_invertebrate = row[6].strip().strip('"') if len(row) > 6 else ""
        match_key = normalize_scientific_name_for_match(scientific_name)
        if not match_key:
            continue
        rows.append(
            {
                "reef_species_id": species_id,
                "reef_common_name": common_name,
                "scientificName": scientific_name,
                "match_key": match_key,
                "reef_family_common": family_common,
                "reef_family_scientific": family_scientific,
                "reef_is_invertebrate": is_invertebrate,
            }
        )
    return rows


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
    rounded = int(round(numeric))
    if rounded <= 0 and numeric > 0:
        rounded = 1
    return str(rounded)


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
