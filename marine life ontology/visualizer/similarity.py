"""Weighted SPARQL similarity for species (biology + sighting context).

Uses small, value-bound SPARQL queries per signal (rdflib-friendly),
then sums weights in Python. Soft biology scores (color / size / category /
depth) are applied on the candidate set.
"""

from __future__ import annotations

import re
from collections import defaultdict
from typing import Any

from rdflib import Graph, URIRef

MLO = "https://example.org/marine-life/"

BIOLOGY_WEIGHTS: dict[str, float] = {
    "familyName": 4.0,
    "classifiedAs": 4.0,
    "physicalTrait": 3.5,  # shared mlo:PhysicalTrait IRI
    "bodyShape": 2.5,  # shared distinctiveFeatures body-shape value
    "subcategory": 3.0,
    "colorOverlap": 2.5,  # shared color terms (bodyColor + aboutText)
    "sizeOverlap": 2.5,  # overlapping min/max size ranges
    "sizeSimilar": 2.0,  # close maxSizeM when full ranges missing
    "foundInWater": 2.0,
    "category": 1.5,
    "depthOverlap": 1.0,
}

# Common appearance colors mined from aboutText / bodyColor
_COLOR_TERMS = (
    "black",
    "white",
    "gray",
    "grey",
    "yellow",
    "blue",
    "red",
    "orange",
    "green",
    "brown",
    "purple",
    "pink",
    "silver",
    "gold",
    "tan",
    "cream",
    "violet",
    "olive",
    "turquoise",
    "cyan",
    "scarlet",
    "maroon",
)
_COLOR_RE = re.compile(
    r"\b(" + "|".join(re.escape(c) for c in _COLOR_TERMS) + r")\b",
    re.IGNORECASE,
)

SIGHTING_WEIGHTS: dict[str, float] = {
    "sameActivity": 5.0,
    "sameSite": 4.0,
    "sameWaterBody": 3.0,
    "sameTimeOfDay": 2.0,
    "similarDepth": 2.0,
    "sameLifeStage": 1.0,
}

DURING = "mlo:duringDiveActivity|mlo:duringSnorkelActivity|mlo:duringActivity"


def _esc_iri(iri: str) -> str:
    return iri.replace("\\", "\\\\").replace(">", "\\>")


def _esc_str(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')


def _short(detail: str | None) -> str | None:
    if not detail:
        return None
    text = detail
    # Only compress IRI-like details; leave literals (e.g. body shape) intact
    if text.startswith("http://") or text.startswith("https://"):
        if "#" in text:
            return text.rsplit("#", 1)[-1]
        return text.rstrip("/").rsplit("/", 1)[-1]
    if len(text) > 48:
        return text[:47] + "…"
    return text


def _lit(graph: Graph, subject: URIRef, pred: str) -> list[str]:
    return [str(o) for o in graph.objects(subject, URIRef(MLO + pred))]


def _uris(graph: Graph, subject: URIRef, pred: str) -> list[str]:
    out = []
    for o in graph.objects(subject, URIRef(MLO + pred)):
        if isinstance(o, URIRef):
            out.append(str(o))
    return out


def _num(graph: Graph, subject: URIRef, pred: str) -> float | None:
    for o in graph.objects(subject, URIRef(MLO + pred)):
        try:
            return float(o)
        except (TypeError, ValueError):
            continue
    return None


def _size_span(graph: Graph, subject: URIRef) -> tuple[float | None, float | None]:
    """Return (min, max) size in meters; synthesize a point range from max-only."""
    s_min = _num(graph, subject, "minSizeM")
    s_max = _num(graph, subject, "maxSizeM")
    if s_min is not None and s_max is not None:
        return s_min, s_max
    if s_max is not None:
        return s_max, s_max
    if s_min is not None:
        return s_min, s_min
    return None, None


def _ranges_overlap(a0: float | None, a1: float | None, b0: float | None, b1: float | None) -> bool:
    if None in (a0, a1, b0, b1):
        return False
    return a0 <= b1 and b0 <= a1


def _max_size_similar(a: float | None, b: float | None, tolerance: float = 0.35) -> bool:
    """True when max sizes are within `tolerance` relative difference."""
    if a is None or b is None or a <= 0 or b <= 0:
        return False
    return max(a, b) / min(a, b) <= 1.0 + tolerance


def _color_terms(graph: Graph, subject: URIRef) -> set[str]:
    """Colors from mlo:bodyColor plus mentions in aboutText."""
    chunks = _lit(graph, subject, "bodyColor") + _lit(graph, subject, "aboutText")
    found: set[str] = set()
    for text in chunks:
        for match in _COLOR_RE.findall(text):
            token = match.lower()
            if token == "grey":
                token = "gray"
            found.add(token)
    return found


def _body_shape(graph: Graph, subject: URIRef) -> str | None:
    for feat in _lit(graph, subject, "distinctiveFeatures"):
        if feat.lower().startswith("body shape"):
            return feat
    return None


def _run(graph: Graph, sparql: str) -> list[Any]:
    return list(graph.query(sparql))


def _add_signal(
    entry: dict[str, Any],
    bucket: str,
    signal: str,
    weight: float,
    detail: str | None,
) -> None:
    seen = entry["signals"][bucket]
    if signal in seen:
        return
    seen[signal] = {"weight": weight, "detail": detail, "detailLabel": _short(detail)}
    entry[bucket] += weight
    entry["evidence"].append(
        {
            "bucket": bucket,
            "signal": signal,
            "weight": weight,
            "detail": detail,
            "detailLabel": _short(detail),
        }
    )


def _mark_candidates(
    graph: Graph,
    scores: dict[str, dict[str, Any]],
    bucket: str,
    signal: str,
    weight: float,
    sparql: str,
    detail: str | None,
    sparql_log: list[str],
) -> None:
    sparql_log.append(f"# {bucket}/{signal}\n{sparql.strip()}\n")
    for row in _run(graph, sparql):
        cand = str(row.candidate)
        _add_signal(scores[cand], bucket, signal, weight, detail)


def biology_queries(graph: Graph, seed_iri: str) -> tuple[list[str], dict[str, dict[str, Any]]]:
    seed = URIRef(seed_iri)
    seed_esc = _esc_iri(seed_iri)
    scores: dict[str, dict[str, Any]] = defaultdict(
        lambda: {
            "biology": 0.0,
            "sighting": 0.0,
            "signals": {"biology": {}, "sighting": {}},
            "evidence": [],
        }
    )
    log: list[str] = []

    for fam in _lit(graph, seed, "familyName"):
        q = f"""
PREFIX mlo: <{MLO}>
SELECT DISTINCT ?candidate WHERE {{
  ?candidate a mlo:Species ;
             mlo:familyName ?f .
  FILTER(?candidate != <{seed_esc}>)
  FILTER(LCASE(STR(?f)) = LCASE("{_esc_str(fam)}"))
}}
"""
        _mark_candidates(
            graph, scores, "biology", "familyName", BIOLOGY_WEIGHTS["familyName"], q, fam, log
        )

    for sub in _lit(graph, seed, "subcategory"):
        q = f"""
PREFIX mlo: <{MLO}>
SELECT DISTINCT ?candidate WHERE {{
  ?candidate a mlo:Species ;
             mlo:subcategory ?s .
  FILTER(?candidate != <{seed_esc}>)
  FILTER(LCASE(STR(?s)) = LCASE("{_esc_str(sub)}"))
}}
"""
        _mark_candidates(
            graph, scores, "biology", "subcategory", BIOLOGY_WEIGHTS["subcategory"], q, sub, log
        )

    for taxon in _uris(graph, seed, "classifiedAs"):
        q = f"""
PREFIX mlo: <{MLO}>
SELECT DISTINCT ?candidate WHERE {{
  ?candidate a mlo:Species ;
             mlo:classifiedAs <{_esc_iri(taxon)}> .
  FILTER(?candidate != <{seed_esc}>)
}}
"""
        _mark_candidates(
            graph,
            scores,
            "biology",
            "classifiedAs",
            BIOLOGY_WEIGHTS["classifiedAs"],
            q,
            taxon,
            log,
        )

    for trait in _uris(graph, seed, "hasPhysicalTrait"):
        q = f"""
PREFIX mlo: <{MLO}>
SELECT DISTINCT ?candidate WHERE {{
  ?candidate a mlo:Species ;
             mlo:hasPhysicalTrait <{_esc_iri(trait)}> .
  FILTER(?candidate != <{seed_esc}>)
}}
"""
        _mark_candidates(
            graph,
            scores,
            "biology",
            "physicalTrait",
            BIOLOGY_WEIGHTS["physicalTrait"],
            q,
            trait,
            log,
        )

    # Catalog body-shape strings live in distinctiveFeatures (closest structured trait)
    seed_shape = _body_shape(graph, seed)
    if seed_shape:
        q = f"""
PREFIX mlo: <{MLO}>
SELECT DISTINCT ?candidate WHERE {{
  ?candidate a mlo:Species ;
             mlo:distinctiveFeatures ?feat .
  FILTER(?candidate != <{seed_esc}>)
  FILTER(LCASE(STR(?feat)) = LCASE("{_esc_str(seed_shape)}"))
}}
"""
        _mark_candidates(
            graph,
            scores,
            "biology",
            "bodyShape",
            BIOLOGY_WEIGHTS["bodyShape"],
            q,
            seed_shape,
            log,
        )

    for color in _lit(graph, seed, "bodyColor"):
        q = f"""
PREFIX mlo: <{MLO}>
SELECT DISTINCT ?candidate WHERE {{
  ?candidate a mlo:Species ;
             mlo:bodyColor ?c .
  FILTER(?candidate != <{seed_esc}>)
  FILTER(LCASE(STR(?c)) = LCASE("{_esc_str(color)}"))
}}
"""
        _mark_candidates(
            graph,
            scores,
            "biology",
            "colorOverlap",
            BIOLOGY_WEIGHTS["colorOverlap"],
            q,
            color,
            log,
        )

    for water in _uris(graph, seed, "foundInWater"):
        q = f"""
PREFIX mlo: <{MLO}>
SELECT DISTINCT ?candidate WHERE {{
  ?candidate a mlo:Species ;
             mlo:foundInWater <{_esc_iri(water)}> .
  FILTER(?candidate != <{seed_esc}>)
}}
"""
        _mark_candidates(
            graph,
            scores,
            "biology",
            "foundInWater",
            BIOLOGY_WEIGHTS["foundInWater"],
            q,
            water,
            log,
        )

    # Soft scores on the candidate set: color / size / category / depth
    seed_cat = next(iter(_lit(graph, seed, "category")), None)
    seed_colors = _color_terms(graph, seed)
    s_min, s_max = _size_span(graph, seed)
    s_max_only = _num(graph, seed, "maxSizeM")
    d_min, d_max = _num(graph, seed, "minDepthM"), _num(graph, seed, "maxDepthM")
    for cand_iri, entry in list(scores.items()):
        cand = URIRef(cand_iri)
        cand_cat = next(iter(_lit(graph, cand, "category")), None)
        if seed_cat and cand_cat and seed_cat.lower() == cand_cat.lower():
            _add_signal(entry, "biology", "category", BIOLOGY_WEIGHTS["category"], cand_cat)

        # Color: shared terms from bodyColor + aboutText
        shared_colors = sorted(seed_colors & _color_terms(graph, cand))
        if shared_colors and "colorOverlap" not in entry["signals"]["biology"]:
            _add_signal(
                entry,
                "biology",
                "colorOverlap",
                BIOLOGY_WEIGHTS["colorOverlap"],
                ",".join(shared_colors),
            )

        # Size: prefer true range overlap; else close maxSizeM
        c_min, c_max = _size_span(graph, cand)
        c_max_only = _num(graph, cand, "maxSizeM")
        has_full_seed = (
            _num(graph, seed, "minSizeM") is not None and _num(graph, seed, "maxSizeM") is not None
        )
        has_full_cand = (
            _num(graph, cand, "minSizeM") is not None and _num(graph, cand, "maxSizeM") is not None
        )
        if has_full_seed and has_full_cand and _ranges_overlap(
            _num(graph, seed, "minSizeM"),
            _num(graph, seed, "maxSizeM"),
            _num(graph, cand, "minSizeM"),
            _num(graph, cand, "maxSizeM"),
        ):
            _add_signal(
                entry,
                "biology",
                "sizeOverlap",
                BIOLOGY_WEIGHTS["sizeOverlap"],
                f"{c_min}-{c_max}m",
            )
        elif _max_size_similar(s_max_only, c_max_only):
            _add_signal(
                entry,
                "biology",
                "sizeSimilar",
                BIOLOGY_WEIGHTS["sizeSimilar"],
                f"max~{c_max_only}m",
            )

        c_dmin, c_dmax = _num(graph, cand, "minDepthM"), _num(graph, cand, "maxDepthM")
        if None not in (d_min, d_max, c_dmin, c_dmax) and d_min <= c_dmax and c_dmin <= d_max:
            _add_signal(
                entry,
                "biology",
                "depthOverlap",
                BIOLOGY_WEIGHTS["depthOverlap"],
                f"{c_dmin}-{c_dmax}m",
            )

    return log, scores


def sighting_queries(graph: Graph, seed_iri: str) -> tuple[list[str], dict[str, dict[str, Any]]]:
    seed_esc = _esc_iri(seed_iri)
    scores: dict[str, dict[str, Any]] = defaultdict(
        lambda: {
            "biology": 0.0,
            "sighting": 0.0,
            "signals": {"biology": {}, "sighting": {}},
            "evidence": [],
        }
    )
    log: list[str] = []

    queries = [
        (
            "sameActivity",
            SIGHTING_WEIGHTS["sameActivity"],
            f"""
PREFIX mlo: <{MLO}>
SELECT DISTINCT ?candidate ?detail WHERE {{
  ?s1 a mlo:Sighting ; mlo:sightedOrganism <{seed_esc}> ; {DURING} ?activity .
  ?s2 a mlo:Sighting ; mlo:sightedOrganism ?candidate ; {DURING} ?activity .
  ?candidate a mlo:Species .
  FILTER(?candidate != <{seed_esc}>)
  BIND(STR(?activity) AS ?detail)
}}
""",
        ),
        (
            "sameSite",
            SIGHTING_WEIGHTS["sameSite"],
            f"""
PREFIX mlo: <{MLO}>
SELECT DISTINCT ?candidate ?detail WHERE {{
  ?s1 a mlo:Sighting ; mlo:sightedOrganism <{seed_esc}> ; {DURING} ?a1 .
  ?a1 mlo:atSite ?site .
  ?s2 a mlo:Sighting ; mlo:sightedOrganism ?candidate ; {DURING} ?a2 .
  ?a2 mlo:atSite ?site .
  ?candidate a mlo:Species .
  FILTER(?candidate != <{seed_esc}>)
  BIND(STR(?site) AS ?detail)
}}
""",
        ),
        (
            "sameWaterBody",
            SIGHTING_WEIGHTS["sameWaterBody"],
            f"""
PREFIX mlo: <{MLO}>
SELECT DISTINCT ?candidate ?detail WHERE {{
  ?s1 a mlo:Sighting ; mlo:sightedOrganism <{seed_esc}> ; {DURING} ?a1 .
  ?a1 mlo:atSite/mlo:locatedInWater ?water .
  ?s2 a mlo:Sighting ; mlo:sightedOrganism ?candidate ; {DURING} ?a2 .
  ?a2 mlo:atSite/mlo:locatedInWater ?water .
  ?candidate a mlo:Species .
  FILTER(?candidate != <{seed_esc}>)
  BIND(STR(?water) AS ?detail)
}}
""",
        ),
        (
            "sameTimeOfDay",
            SIGHTING_WEIGHTS["sameTimeOfDay"],
            f"""
PREFIX mlo: <{MLO}>
SELECT DISTINCT ?candidate ?detail WHERE {{
  ?s1 a mlo:Sighting ; mlo:sightedOrganism <{seed_esc}> ; {DURING} ?a1 .
  ?a1 mlo:timeOfDay ?tod .
  ?s2 a mlo:Sighting ; mlo:sightedOrganism ?candidate ; {DURING} ?a2 .
  ?a2 mlo:timeOfDay ?tod .
  ?candidate a mlo:Species .
  FILTER(?candidate != <{seed_esc}>)
  BIND(STR(?tod) AS ?detail)
}}
""",
        ),
        (
            "similarDepth",
            SIGHTING_WEIGHTS["similarDepth"],
            f"""
PREFIX mlo: <{MLO}>
SELECT DISTINCT ?candidate ?detail WHERE {{
  ?s1 a mlo:Sighting ; mlo:sightedOrganism <{seed_esc}> ; mlo:sightingDepthM ?d1 .
  ?s2 a mlo:Sighting ; mlo:sightedOrganism ?candidate ; mlo:sightingDepthM ?d2 .
  ?candidate a mlo:Species .
  FILTER(?candidate != <{seed_esc}>)
  FILTER(ABS(?d1 - ?d2) <= 5)
  BIND(CONCAT(STR(?d2), "m") AS ?detail)
}}
""",
        ),
        (
            "sameLifeStage",
            SIGHTING_WEIGHTS["sameLifeStage"],
            f"""
PREFIX mlo: <{MLO}>
SELECT DISTINCT ?candidate ?detail WHERE {{
  ?s1 a mlo:Sighting ; mlo:sightedOrganism <{seed_esc}> ; mlo:lifeStage ?stage .
  ?s2 a mlo:Sighting ; mlo:sightedOrganism ?candidate ; mlo:lifeStage ?stage .
  ?candidate a mlo:Species .
  FILTER(?candidate != <{seed_esc}>)
  BIND(STR(?stage) AS ?detail)
}}
""",
        ),
    ]

    for signal, weight, sparql in queries:
        log.append(f"# sighting/{signal}\n{sparql.strip()}\n")
        for row in _run(graph, sparql):
            detail = str(row.detail) if getattr(row, "detail", None) is not None else None
            _add_signal(scores[str(row.candidate)], "sighting", signal, weight, detail)

    return log, scores


def _merge(
    into: dict[str, dict[str, Any]], src: dict[str, dict[str, Any]]
) -> None:
    for iri, entry in src.items():
        dest = into[iri]
        for bucket in ("biology", "sighting"):
            for signal, meta in entry["signals"][bucket].items():
                _add_signal(dest, bucket, signal, meta["weight"], meta.get("detail"))


def _label(graph: Graph, iri: str) -> tuple[str, str | None]:
    subject = URIRef(iri)
    common = next(iter(_lit(graph, subject, "commonName")), None)
    scientific = next(iter(_lit(graph, subject, "scientificName")), None)
    if not common:
        common = iri.rstrip("/").rsplit("/", 1)[-1]
    return common, scientific


def similar_species(
    graph: Graph,
    seed_iri: str,
    *,
    mode: str = "both",
    limit: int = 15,
) -> dict[str, Any]:
    mode = (mode or "both").strip().lower()
    if mode not in {"biology", "sighting", "both"}:
        return {"error": "mode must be biology, sighting, or both", "results": []}

    seed = URIRef(seed_iri)
    if (seed, None, None) not in graph:
        return {"error": f"Unknown species IRI: {seed_iri}", "results": []}

    scores: dict[str, dict[str, Any]] = defaultdict(
        lambda: {
            "biology": 0.0,
            "sighting": 0.0,
            "signals": {"biology": {}, "sighting": {}},
            "evidence": [],
        }
    )
    bio_log: list[str] = []
    sight_log: list[str] = []

    if mode in {"biology", "both"}:
        bio_log, bio_scores = biology_queries(graph, seed_iri)
        _merge(scores, bio_scores)
    if mode in {"sighting", "both"}:
        sight_log, sight_scores = sighting_queries(graph, seed_iri)
        _merge(scores, sight_scores)

    seed_common, seed_scientific = _label(graph, seed_iri)
    ranked = []
    for cand, entry in scores.items():
        total = entry["biology"] + entry["sighting"]
        if total <= 0:
            continue
        common, scientific = _label(graph, cand)
        ranked.append(
            {
                "iri": cand,
                "commonName": common,
                "scientificName": scientific,
                "score": round(total, 2),
                "biologyScore": round(entry["biology"], 2),
                "sightingScore": round(entry["sighting"], 2),
                "evidence": sorted(
                    entry["evidence"], key=lambda e: (-e["weight"], e["signal"])
                ),
            }
        )

    ranked.sort(key=lambda r: (-r["score"], r["commonName"].lower()))
    ranked = ranked[: max(1, min(limit, 50))]

    return {
        "seed": {
            "iri": seed_iri,
            "commonName": seed_common,
            "scientificName": seed_scientific,
        },
        "mode": mode,
        "weights": {"biology": BIOLOGY_WEIGHTS, "sighting": SIGHTING_WEIGHTS},
        "sparql": {
            "biology": "\n".join(bio_log).strip() if bio_log else None,
            "sighting": "\n".join(sight_log).strip() if sight_log else None,
        },
        "results": ranked,
        "count": len(ranked),
    }
