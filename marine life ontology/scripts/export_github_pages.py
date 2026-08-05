#!/usr/bin/env python3
"""Export ontology vocabulary docs + static visualizer for GitHub Pages.

Writes into ``<out>/`` (typically ``site/ontology`` after ``mkdocs build``):

  vocabulary/index.html   — pyLODE HTML
  visualizer/             — static UI + prebuilt JSON

Usage:
  python scripts/export_github_pages.py --out ../site/ontology
  python scripts/export_github_pages.py --out /tmp/ontology-pages --max-species 20
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VIS = ROOT / "visualizer"
STATIC = VIS / "static"
DOCS = ROOT / "docs"
ONTOLOGY_DIR = ROOT / "ontology"

sys.path.insert(0, str(VIS))

from rdflib import Graph, Namespace, RDF, URIRef  # noqa: E402

from server import (  # noqa: E402
    DEFAULT_GLOBS,
    SEARCH_GLOBS,
    build_vis_payload,
    load_graph,
    short_label,
    species_detail,
)
from similarity import similar_species  # noqa: E402

MLO = Namespace("https://www.godiveios.com/marine-life/")


def write_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, separators=(",", ":")), encoding="utf-8")
    print(f"  wrote {path} ({path.stat().st_size:,} bytes)", flush=True)


def export_vocabulary(out_vocab: Path) -> None:
    """Generate or copy pyLODE docs into vocabulary/index.html."""
    out_vocab.mkdir(parents=True, exist_ok=True)
    dest = out_vocab / "index.html"

    inputs = [
        ONTOLOGY_DIR / "scuba-core.ttl",
        ONTOLOGY_DIR / "godive-activity.ttl",
        ONTOLOGY_DIR / "taxonomy-seed.ttl",
        ONTOLOGY_DIR / "dive-vocab-seed.ttl",
    ]
    try:
        g = Graph()
        for path in inputs:
            g.parse(path, format="turtle")
        combined = out_vocab / "_combined.ttl"
        combined.write_text(g.serialize(format="turtle"), encoding="utf-8")
        import pylode

        html = pylode.MakeDocco(
            input_data_file=str(combined),
            outputformat="html",
            profile="ontdoc",
        ).document()
        dest.write_text(html, encoding="utf-8")
        combined.unlink(missing_ok=True)
        print(f"  generated {dest} via pylode ({dest.stat().st_size:,} bytes)", flush=True)
        return
    except Exception as exc:  # noqa: BLE001
        print(f"  pyLODE regenerate failed ({exc}); falling back", flush=True)

    src = DOCS / "index.html"
    if src.is_file():
        shutil.copy2(src, dest)
        print(f"  copied {src.relative_to(ROOT)} → {dest}", flush=True)
        return

    raise RuntimeError(
        "Could not generate vocabulary HTML (install pylode) and no docs/index.html fallback"
    )


def species_id(iri: str) -> str:
    return iri.rstrip("/").rsplit("/", 1)[-1]


def lit(graph: Graph, subject: URIRef, pred) -> str | None:
    for o in graph.objects(subject, pred):
        return str(o)
    return None


def num(graph: Graph, subject: URIRef, pred) -> float | None:
    for o in graph.objects(subject, pred):
        try:
            return float(o)
        except (TypeError, ValueError):
            return None
    return None


def build_species_index(graph: Graph, species: list[URIRef]) -> dict:
    rows = []
    for s in species:
        iri = str(s)
        rows.append(
            {
                "id": species_id(iri),
                "iri": iri,
                "commonName": lit(graph, s, MLO.commonName) or short_label(graph, s),
                "scientificName": lit(graph, s, MLO.scientificName),
                "familyName": lit(graph, s, MLO.familyName),
                "subcategory": lit(graph, s, MLO.subcategory),
                "category": lit(graph, s, MLO.category),
                "distinctiveFeatures": lit(graph, s, MLO.distinctiveFeatures) or "",
                "aboutText": lit(graph, s, MLO.aboutText) or "",
                "minDepthM": num(graph, s, MLO.minDepthM),
                "maxDepthM": num(graph, s, MLO.maxDepthM),
                "minSizeM": num(graph, s, MLO.minSizeM),
                "maxSizeM": num(graph, s, MLO.maxSizeM),
            }
        )
    rows.sort(key=lambda r: (r["commonName"] or "").lower())
    return {"count": len(rows), "species": rows}


def export_species_payloads(
    graph: Graph,
    species: list[URIRef],
    out_species: Path,
    *,
    max_species: int | None,
) -> None:
    out_species.mkdir(parents=True, exist_ok=True)
    selected = species if max_species is None else species[:max_species]
    total = len(selected)
    for i, s in enumerate(selected, 1):
        iri = str(s)
        detail = species_detail(iri, depth=2)
        if detail.get("error"):
            print(f"  skip {iri}: {detail['error']}", flush=True)
            continue
        # Drop bulky sparql logs; biology similarity is client-side on Pages.
        payload = {
            "iri": detail["iri"],
            "id": species_id(iri),
            "commonName": detail["commonName"],
            "scientificName": detail.get("scientificName"),
            "properties": detail.get("properties") or [],
            "nodes": detail.get("nodes") or [],
            "edges": detail.get("edges") or [],
            "graphStats": detail.get("graphStats") or {},
            "depth": detail.get("depth", 2),
        }
        write_json(out_species / f"{species_id(iri)}.json", payload)
        if i % 100 == 0 or i == total:
            print(f"  species {i}/{total}", flush=True)


def export_sighting_similar(
    graph: Graph, species: list[URIRef], out_path: Path, *, max_species: int | None
) -> None:
    """Precompute sighting-mode similar for species that have sightings (demo TTL)."""
    with_sightings: list[str] = []
    for s in species:
        iri = str(s)
        q = f"""
        PREFIX mlo: <{MLO}>
        ASK {{ ?x a mlo:Sighting ; mlo:sightedOrganism <{iri}> }}
        """
        if graph.query(q).askAnswer:
            with_sightings.append(iri)

    if max_species is not None:
        with_sightings = with_sightings[:max_species]

    mapping: dict[str, list] = {}
    for iri in with_sightings:
        payload = similar_species(graph, iri, mode="sighting", limit=12)
        mapping[species_id(iri)] = payload.get("results") or []
    write_json(out_path, {"mode": "sighting", "byId": mapping})


def prepare_visualizer_html(dest_dir: Path) -> None:
    dest_dir.mkdir(parents=True, exist_ok=True)
    src_html = (STATIC / "index.html").read_text(encoding="utf-8")
    html = src_html.replace('<html lang="en">', '<html lang="en" data-static="1">', 1)
    (dest_dir / "index.html").write_text(html, encoding="utf-8")

    vendor_src = STATIC / "vendor" / "vis-network.min.js"
    vendor_dst = dest_dir / "vendor" / "vis-network.min.js"
    vendor_dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(vendor_src, vendor_dst)
    shutil.copy2(STATIC / "biology-similarity.js", dest_dir / "biology-similarity.js")
    print(f"  visualizer HTML + vendor → {dest_dir}", flush=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--out",
        type=Path,
        required=True,
        help="Output directory (e.g. site/ontology)",
    )
    parser.add_argument(
        "--max-species",
        type=int,
        default=None,
        help="Limit species ego exports (dev/smoke)",
    )
    parser.add_argument(
        "--skip-species",
        action="store_true",
        help="Skip per-species ego JSON (overview + index only)",
    )
    args = parser.parse_args()
    out: Path = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)

    print("== Vocabulary (pyLODE) ==", flush=True)
    export_vocabulary(out / "vocabulary")

    print("== Visualizer shell ==", flush=True)
    viz = out / "visualizer"
    prepare_visualizer_html(viz)
    data = viz / "data"
    data.mkdir(parents=True, exist_ok=True)

    print("== Overview graphs ==", flush=True)
    ontology_files = [p for p in DEFAULT_GLOBS if (ROOT / p).is_file()]
    g_ont = load_graph(ontology_files)
    ont_payload = build_vis_payload(g_ont)
    ont_payload["files"] = ontology_files
    write_json(data / "graphs" / "ontology.json", ont_payload)

    data_files = ontology_files + ["data/example-sighting.ttl"]
    data_files = [p for p in data_files if (ROOT / p).is_file()]
    g_data = load_graph(data_files)
    data_payload = build_vis_payload(g_data)
    data_payload["files"] = data_files
    write_json(data / "graphs" / "ontology-data.json", data_payload)

    print("== Search graph + species index ==", flush=True)
    search_files = [p for p in SEARCH_GLOBS if (ROOT / p).is_file()]
    g_search = load_graph(search_files)
    # Warm module-level cache used by species_detail()
    import server as server_mod

    server_mod._search_graph = g_search
    server_mod._search_graph_mtime = 1.0

    species = sorted(
        (s for s in g_search.subjects(RDF.type, MLO.Species) if isinstance(s, URIRef)),
        key=lambda s: (lit(g_search, s, MLO.commonName) or "").lower(),
    )
    index = build_species_index(g_search, species)
    if args.max_species is not None:
        index["species"] = index["species"][: args.max_species]
        index["count"] = len(index["species"])
        species = species[: args.max_species]
    write_json(data / "species-index.json", index)

    write_json(
        data / "manifest.json",
        {
            "version": 1,
            "presets": {
                "ontology": "graphs/ontology.json",
                "ontology+data": "graphs/ontology-data.json",
            },
            "speciesIndex": "species-index.json",
            "speciesDir": "species",
            "sightingSimilar": "similar-sighting.json",
            "speciesCount": index["count"],
        },
    )

    if not args.skip_species:
        print("== Per-species ego graphs ==", flush=True)
        export_species_payloads(
            g_search, species, data / "species", max_species=args.max_species
        )
        print("== Sighting similarity (demo) ==", flush=True)
        export_sighting_similar(
            g_search,
            species,
            data / "similar-sighting.json",
            max_species=args.max_species,
        )
    else:
        write_json(data / "similar-sighting.json", {"mode": "sighting", "byId": {}})

    # Landing redirect helpers
    (out / "README.md").write_text(
        "# GoDive marine-life ontology (GitHub Pages)\n\n"
        "- [Vocabulary docs](vocabulary/)\n"
        "- [Static visualizer](visualizer/)\n",
        encoding="utf-8",
    )
    print(f"Done → {out}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
