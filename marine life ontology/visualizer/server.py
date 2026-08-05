#!/usr/bin/env python3
"""Lightweight localhost ontology visualizer (dev only).

Usage:
  cd visualizer
  python3 -m venv .venv && source .venv/bin/activate
  pip install -r requirements.txt
  python server.py

Then open http://127.0.0.1:8765
"""

from __future__ import annotations

import json
import mimetypes
import re
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlparse

from rdflib import Graph, Literal, Namespace, RDF, RDFS, OWL, URIRef
from rdflib.namespace import XSD

from similarity import similar_species

ROOT = Path(__file__).resolve().parent.parent
STATIC = Path(__file__).resolve().parent / "static"
DEFAULT_PORT = 8765

MLO = Namespace("https://example.org/marine-life/")

# Files loaded by default (TBox + seeded controlled vocabs)
DEFAULT_GLOBS = [
    "ontology/scuba-core.ttl",
    "ontology/godive-activity.ttl",
    "ontology/taxonomy-seed.ttl",
    "ontology/dive-vocab-seed.ttl",
]

# Always available for SPARQL species search + catalog sites
SEARCH_GLOBS = [
    "data/catalog/marine_life_species.ttl",
    "data/catalog/dive_sites.ttl",
    "data/example-sighting.ttl",
    *DEFAULT_GLOBS,
]

_search_graph: Graph | None = None
_search_graph_mtime: float = 0.0


def local_name(term) -> str:
    if isinstance(term, URIRef):
        text = str(term)
        if "#" in text:
            return text.rsplit("#", 1)[-1]
        return text.rstrip("/").rsplit("/", 1)[-1]
    return str(term)


def short_label(graph: Graph, term) -> str:
    for pred in (
        MLO.commonName,
        MLO.siteName,
        MLO.countryName,
        MLO.waterName,
        RDFS.label,
    ):
        for label in graph.objects(term, pred):
            return str(label)
    return local_name(term)


def load_graph(rel_paths: list[str]) -> Graph:
    g = Graph()
    g.bind("mlo", MLO)
    g.bind("rdf", RDF)
    g.bind("rdfs", RDFS)
    g.bind("owl", OWL)
    g.bind("xsd", XSD)
    for rel in rel_paths:
        path = ROOT / rel
        if not path.is_file():
            raise FileNotFoundError(f"Missing RDF file: {path}")
        g.parse(path, format="turtle")
    return g


def search_graph() -> Graph:
    """Cached graph for SPARQL species search (catalog + ontology)."""
    global _search_graph, _search_graph_mtime
    mtimes: list[float] = []
    paths: list[str] = []
    for rel in SEARCH_GLOBS:
        path = ROOT / rel
        if path.is_file():
            paths.append(rel)
            mtimes.append(path.stat().st_mtime)
    stamp = max(mtimes) if mtimes else 0.0
    if _search_graph is None or stamp != _search_graph_mtime:
        print(f"[viz] Loading search graph ({len(paths)} files)…", flush=True)
        _search_graph = load_graph(paths)
        _search_graph_mtime = stamp
        print(f"[viz] Search graph ready: {len(_search_graph)} triples", flush=True)
    return _search_graph


def build_common_name_sparql(query: str, limit: int = 25) -> str:
    """Translate a common-name search string into SPARQL."""
    # Escape for SPARQL string literal
    safe = query.replace("\\", "\\\\").replace('"', '\\"')
    return f"""PREFIX mlo: <https://example.org/marine-life/>
PREFIX rdf:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#>

SELECT ?species ?commonName ?scientificName
WHERE {{
  ?species a mlo:Species ;
           mlo:commonName ?commonName .
  OPTIONAL {{ ?species mlo:scientificName ?scientificName }}
  FILTER(CONTAINS(LCASE(STR(?commonName)), LCASE("{safe}")))
}}
ORDER BY ?commonName
LIMIT {limit}
"""


def run_common_name_search(query: str, limit: int = 25) -> dict:
    q = query.strip()
    if not q:
        return {"error": "Empty query", "sparql": "", "results": []}
    if len(q) > 120:
        return {"error": "Query too long", "sparql": "", "results": []}

    sparql = build_common_name_sparql(q, limit=limit)
    g = search_graph()
    rows = []
    for row in g.query(sparql):
        rows.append(
            {
                "iri": str(row.species),
                "commonName": str(row.commonName),
                "scientificName": str(row.scientificName) if row.scientificName else None,
                "label": str(row.commonName),
            }
        )
    return {"sparql": sparql, "query": q, "results": rows, "count": len(rows)}


def _is_class(graph: Graph, term: URIRef) -> bool:
    return (
        (term, RDF.type, RDFS.Class) in graph
        or (term, RDF.type, OWL.Class) in graph
        or term in (RDFS.Class, OWL.Class, RDF.Property)
    )


def _node_group(graph: Graph, term: URIRef) -> str:
    if _is_class(graph, term):
        return "class"
    if (term, RDF.type, RDF.Property) in graph or (term, RDF.type, OWL.ObjectProperty) in graph:
        return "property"
    if (term, RDF.type, OWL.DatatypeProperty) in graph:
        return "property"
    # Site characteristic graph hubs (vis-network group colors)
    if (term, RDF.type, MLO.Site) in graph:
        return "site"
    if (term, RDF.type, MLO.Country) in graph:
        return "country"
    if (term, RDF.type, MLO.BodyOfWater) in graph:
        return "water"
    if (term, RDF.type, MLO.SiteReport) in graph:
        return "report"
    if (term, RDF.type, MLO.Sighting) in graph:
        return "sighting"
    return "individual"


def _uri_degree(graph: Graph, term: URIRef) -> int:
    """Approx undirected degree over URI–URI links (capped scan)."""
    count = 0
    for _, o in graph.predicate_objects(term):
        if isinstance(o, URIRef):
            count += 1
            if count > 80:
                return count
    for s, _ in graph.subject_predicates(term):
        if isinstance(s, URIRef):
            count += 1
            if count > 80:
                return count
    return count


def build_ego_graph(graph: Graph, focus: URIRef, depth: int = 2, max_hub_degree: int = 40) -> dict:
    """Build a vis-network payload for nodes within `depth` hops of focus.

    Walks undirected URI–URI links. High-degree hubs (e.g. mlo:Species) are
    included as leaves but not expanded further. Short literal values on the
    focus species are attached as hop-1 leaves so catalog rows aren't empty.
    """
    nodes: dict[str, dict] = {}
    edges: list[dict] = []
    edge_ids: set[str] = set()

    def add_node(term, group: str, label: str | None = None, extra: dict | None = None) -> str:
        nid = str(term) if not isinstance(term, str) else term
        if nid not in nodes:
            nodes[nid] = {
                "id": nid,
                "label": label or (short_label(graph, term) if isinstance(term, URIRef) else str(term)),
                "group": group,
                "title": nid if isinstance(term, URIRef) else str(term),
            }
            if extra:
                nodes[nid].update(extra)
        elif extra:
            nodes[nid].update(extra)
        return nid

    def add_edge(src: str, dst: str, label: str, dashes: bool = False) -> None:
        eid = f"{src}|{label}|{dst}"
        if eid in edge_ids or src == dst:
            return
        edge_ids.add(eid)
        edges.append(
            {
                "id": eid,
                "from": src,
                "to": dst,
                "label": label,
                "arrows": "to",
                "dashes": dashes,
            }
        )

    focus_id = add_node(
        focus,
        "individual",
        short_label(graph, focus),
        {"size": 34, "borderWidth": 3},
    )

    # BFS over URI neighbors
    frontier: set[URIRef] = {focus}
    visited: set[URIRef] = {focus}
    for _hop in range(depth):
        nxt: set[URIRef] = set()
        for node in frontier:
            # Outgoing
            for pred, obj in graph.predicate_objects(node):
                if not isinstance(obj, URIRef):
                    continue
                pred_label = local_name(pred)
                dashes = pred in (RDF.type, RDFS.subClassOf)
                add_node(obj, _node_group(graph, obj))
                add_edge(str(node), str(obj), pred_label, dashes=dashes)
                if obj in visited:
                    continue
                # Don't expand through classes or high-degree hubs
                if _is_class(graph, obj) or _uri_degree(graph, obj) > max_hub_degree:
                    visited.add(obj)
                    continue
                visited.add(obj)
                nxt.add(obj)
            # Incoming
            for subj, pred in graph.subject_predicates(node):
                if not isinstance(subj, URIRef):
                    continue
                pred_label = local_name(pred)
                dashes = pred in (RDF.type, RDFS.subClassOf)
                add_node(subj, _node_group(graph, subj))
                add_edge(str(subj), str(node), pred_label, dashes=dashes)
                if subj in visited:
                    continue
                if _is_class(graph, subj) or _uri_degree(graph, subj) > max_hub_degree:
                    visited.add(subj)
                    continue
                visited.add(subj)
                nxt.add(subj)
        frontier = nxt

    # Literal leaves on the focus (short values only)
    skip_preds = {MLO.aboutText, MLO.featureImageResourceName, MLO.featureImageURL}
    for pred, obj in sorted(graph.predicate_objects(focus), key=lambda x: str(x[0])):
        if not isinstance(obj, Literal):
            continue
        if pred in skip_preds:
            continue
        text = str(obj)
        if len(text) > 48:
            continue
        lit_id = f"literal:{focus_id}|{local_name(pred)}|{text}"
        add_node(
            lit_id,
            "literal",
            text if len(text) <= 28 else text[:27] + "…",
            {"title": f"{local_name(pred)}: {text}"},
        )
        add_edge(focus_id, lit_id, local_name(pred))

    return {
        "nodes": list(nodes.values()),
        "edges": edges,
        "stats": {
            "nodes": len(nodes),
            "edges": len(edges),
            "depth": depth,
            "focus": focus_id,
        },
    }


def species_detail(iri: str, depth: int = 2) -> dict:
    g = search_graph()
    subject = URIRef(iri)
    if (subject, None, None) not in g:
        return {"error": f"Unknown species IRI: {iri}"}

    props = []
    for p, o in sorted(g.predicate_objects(subject), key=lambda x: str(x[0])):
        item: dict = {"predicate": str(p), "predicateLabel": local_name(p)}
        if isinstance(o, URIRef):
            item["object"] = str(o)
            item["objectKind"] = "iri"
            item["objectLabel"] = short_label(g, o)
        else:
            item["object"] = str(o)
            item["objectKind"] = "literal"
            if getattr(o, "language", None):
                item["language"] = o.language
            if getattr(o, "datatype", None):
                item["datatype"] = str(o.datatype)
        props.append(item)

    common = next((str(o) for o in g.objects(subject, MLO.commonName)), local_name(subject))
    scientific = next((str(o) for o in g.objects(subject, MLO.scientificName)), None)

    ego = build_ego_graph(g, subject, depth=depth)
    # Ensure focus label uses common name
    for n in ego["nodes"]:
        if n["id"] == iri:
            n["label"] = common
            n["title"] = f"{common}\n{scientific or ''}\n{iri}".strip()
            n["group"] = "individual"

    return {
        "iri": iri,
        "commonName": common,
        "scientificName": scientific,
        "properties": props,
        "nodes": ego["nodes"],
        "edges": ego["edges"],
        "graphStats": ego["stats"],
        "depth": depth,
    }


def build_vis_payload(graph: Graph) -> dict:
    """Build vis-network nodes/edges for classes, properties, and individuals."""
    nodes: dict[str, dict] = {}
    edges: list[dict] = []
    edge_ids: set[str] = set()

    def add_node(term, group: str, extra: dict | None = None) -> str:
        nid = str(term)
        if nid not in nodes:
            nodes[nid] = {
                "id": nid,
                "label": short_label(graph, term),
                "group": group,
                "title": nid,
            }
            if extra:
                nodes[nid].update(extra)
        elif extra:
            nodes[nid].update(extra)
        return nid

    def add_edge(src: str, dst: str, label: str, dashes: bool = False) -> None:
        eid = f"{src}|{label}|{dst}"
        if eid in edge_ids or src == dst:
            return
        edge_ids.add(eid)
        edges.append(
            {
                "id": eid,
                "from": src,
                "to": dst,
                "label": label,
                "arrows": "to",
                "dashes": dashes,
            }
        )

    classes = set(graph.subjects(RDF.type, RDFS.Class)) | set(
        graph.subjects(RDF.type, OWL.Class)
    )
    for s, _, o in graph.triples((None, RDFS.subClassOf, None)):
        classes.add(s)
        classes.add(o)

    properties = set(graph.subjects(RDF.type, RDF.Property)) | set(
        graph.subjects(RDF.type, OWL.ObjectProperty)
    ) | set(graph.subjects(RDF.type, OWL.DatatypeProperty))

    for cls in classes:
        if not isinstance(cls, URIRef):
            continue
        add_node(cls, "class")

    for prop in properties:
        if not isinstance(prop, URIRef):
            continue
        add_node(prop, "property")

    for s, _, o in graph.triples((None, RDFS.subClassOf, None)):
        if isinstance(s, URIRef) and isinstance(o, URIRef):
            add_node(s, "class")
            add_node(o, "class")
            add_edge(str(s), str(o), "subClassOf", dashes=True)

    for prop in properties:
        if not isinstance(prop, URIRef):
            continue
        domains = [d for d in graph.objects(prop, RDFS.domain) if isinstance(d, URIRef)]
        ranges = [r for r in graph.objects(prop, RDFS.range) if isinstance(r, URIRef)]
        label = short_label(graph, prop)

        for r in list(ranges):
            if str(r).startswith(str(XSD)) or r in (RDFS.Literal, RDF.langString):
                nodes[str(prop)]["title"] = f"{str(prop)}\nrange: {local_name(r)}"
                ranges.remove(r)

        if domains and ranges:
            for d in domains:
                add_node(d, "class")
                for r in ranges:
                    add_node(r, "class")
                    add_edge(str(d), str(r), label)
        elif domains:
            for d in domains:
                add_node(d, "class")
                add_edge(str(d), str(prop), label)
        elif ranges:
            for r in ranges:
                add_node(r, "class")
                add_edge(str(prop), str(r), label)

    # Individuals typed as project classes (seed vocabs only — not full catalog)
    for cls in classes:
        if not isinstance(cls, URIRef):
            continue
        if not str(cls).startswith(str(MLO)):
            continue
        # Skip bulk Species catalog in the default TBox view
        if cls == MLO.Species:
            continue
        for ind in graph.subjects(RDF.type, cls):
            if not isinstance(ind, URIRef):
                continue
            add_node(ind, "individual")
            add_edge(str(ind), str(cls), "type", dashes=True)

    return {
        "nodes": list(nodes.values()),
        "edges": edges,
        "stats": {
            "triples": len(graph),
            "nodes": len(nodes),
            "edges": len(edges),
            "classes": sum(1 for n in nodes.values() if n["group"] == "class"),
            "properties": sum(1 for n in nodes.values() if n["group"] == "property"),
            "individuals": sum(1 for n in nodes.values() if n["group"] == "individual"),
        },
    }


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args) -> None:
        print(f"[viz] {self.address_string()} {fmt % args}")

    def _send(self, code: int, body: bytes, content_type: str) -> None:
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _json(self, code: int, payload: dict) -> None:
        data = json.dumps(payload, indent=2).encode("utf-8")
        self._send(code, data, "application/json; charset=utf-8")

    def do_GET(self) -> None:  # noqa: N802
        parsed = urlparse(self.path)
        path = parsed.path
        qs = parse_qs(parsed.query)

        if path in ("/", "/index.html"):
            html = (STATIC / "index.html").read_bytes()
            self._send(200, html, "text/html; charset=utf-8")
            return

        if path == "/api/graph":
            files = qs.get("files")
            if files:
                rel_paths = [p.strip() for p in files[0].split(",") if p.strip()]
            else:
                rel_paths = list(DEFAULT_GLOBS)
            try:
                graph = load_graph(rel_paths)
                payload = build_vis_payload(graph)
                payload["files"] = rel_paths
                self._json(200, payload)
            except Exception as exc:  # noqa: BLE001
                self._json(500, {"error": str(exc)})
            return

        if path == "/api/search":
            q = unquote((qs.get("q") or [""])[0]).strip()
            try:
                limit = int((qs.get("limit") or ["25"])[0])
            except ValueError:
                limit = 25
            limit = max(1, min(limit, 100))
            try:
                payload = run_common_name_search(q, limit=limit)
                code = 400 if payload.get("error") else 200
                self._json(code, payload)
            except Exception as exc:  # noqa: BLE001
                self._json(500, {"error": str(exc), "sparql": "", "results": []})
            return

        if path == "/api/species":
            iri = unquote((qs.get("iri") or [""])[0]).strip()
            if not iri or not re.match(r"^https?://", iri):
                self._json(400, {"error": "Missing or invalid iri parameter"})
                return
            try:
                depth = int((qs.get("depth") or ["2"])[0])
            except ValueError:
                depth = 2
            depth = max(1, min(depth, 3))
            try:
                payload = species_detail(iri, depth=depth)
                code = 404 if payload.get("error") else 200
                self._json(code, payload)
            except Exception as exc:  # noqa: BLE001
                self._json(500, {"error": str(exc)})
            return

        if path == "/api/similar":
            iri = unquote((qs.get("iri") or [""])[0]).strip()
            if not iri or not re.match(r"^https?://", iri):
                self._json(400, {"error": "Missing or invalid iri parameter", "results": []})
                return
            mode = (qs.get("mode") or ["both"])[0].strip().lower()
            try:
                limit = int((qs.get("limit") or ["12"])[0])
            except ValueError:
                limit = 12
            limit = max(1, min(limit, 50))
            try:
                payload = similar_species(search_graph(), iri, mode=mode, limit=limit)
                code = 400 if payload.get("error") else 200
                self._json(code, payload)
            except Exception as exc:  # noqa: BLE001
                self._json(500, {"error": str(exc), "results": []})
            return

        if path == "/api/files":
            ttl = sorted(
                str(p.relative_to(ROOT))
                for p in ROOT.rglob("*.ttl")
                if ".venv" not in p.parts and "node_modules" not in p.parts
            )
            self._json(200, {"files": ttl, "default": DEFAULT_GLOBS})
            return

        static_path = (STATIC / path.lstrip("/")).resolve()
        if static_path.is_file() and str(static_path).startswith(str(STATIC.resolve())):
            ctype = mimetypes.guess_type(static_path.name)[0] or "application/octet-stream"
            self._send(200, static_path.read_bytes(), ctype)
            return

        self._send(404, b"Not found", "text/plain; charset=utf-8")


def main() -> None:
    port = DEFAULT_PORT
    # Warm search graph so first query is snappy
    try:
        search_graph()
    except Exception as exc:  # noqa: BLE001
        print(f"[viz] Warning: search graph not loaded yet: {exc}", flush=True)

    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    print(f"Ontology visualizer: http://127.0.0.1:{port}", flush=True)
    print(f"Serving RDF from: {ROOT}", flush=True)
    print("Ctrl+C to stop", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.", flush=True)
        server.server_close()


if __name__ == "__main__":
    main()
