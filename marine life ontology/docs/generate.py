#!/usr/bin/env python3
"""Generate human-readable HTML ontology docs with pyLODE.

Usage:
  cd docs
  python3 -m venv .venv && source .venv/bin/activate
  pip install -r requirements.txt
  python generate.py

Then open docs/index.html (or run with --serve).
"""

from __future__ import annotations

import argparse
import http.server
import socketserver
import sys
import webbrowser
from pathlib import Path

from rdflib import Graph

ROOT = Path(__file__).resolve().parent.parent
ONTOLOGY_DIR = ROOT / "ontology"
DOCS_DIR = Path(__file__).resolve().parent
COMBINED = DOCS_DIR / "_combined.ttl"
OUTPUT = DOCS_DIR / "index.html"

# Vocabulary + controlled-value seeds (not instance data / shapes)
DEFAULT_INPUTS = [
    ONTOLOGY_DIR / "scuba-core.ttl",
    ONTOLOGY_DIR / "godive-activity.ttl",
    ONTOLOGY_DIR / "taxonomy-seed.ttl",
    ONTOLOGY_DIR / "dive-vocab-seed.ttl",
]


def merge_ontology(paths: list[Path], dest: Path) -> Graph:
    g = Graph()
    for path in paths:
        if not path.is_file():
            raise FileNotFoundError(path)
        g.parse(path, format="turtle")
        print(f"  + {path.relative_to(ROOT)} ({len(g)} triples cumulative)")
    dest.write_text(g.serialize(format="turtle"), encoding="utf-8")
    print(f"Wrote {dest.relative_to(ROOT)} ({len(g)} triples)", flush=True)
    return g


def generate_html(ontology_path: Path, output_path: Path) -> None:
    import pylode

    html = pylode.MakeDocco(
        input_data_file=str(ontology_path),
        outputformat="html",
        profile="ontdoc",
    ).document()
    output_path.write_text(html, encoding="utf-8")
    print(
        f"Wrote {output_path.relative_to(ROOT)} ({output_path.stat().st_size:,} bytes)",
        flush=True,
    )


def serve(port: int) -> None:
    class Handler(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=str(DOCS_DIR), **kwargs)

    url = f"http://127.0.0.1:{port}/index.html"
    print(f"Serving docs at {url}")
    webbrowser.open(url)
    with socketserver.ThreadingTCPServer(("127.0.0.1", port), Handler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nStopped.")


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate ontology HTML docs with pyLODE")
    parser.add_argument("--serve", action="store_true", help="Serve docs/ on localhost after build")
    parser.add_argument("--port", type=int, default=8766, help="Port for --serve (default 8766)")
    parser.add_argument(
        "--core-only",
        action="store_true",
        help="Document scuba-core.ttl only (skip seed individuals)",
    )
    args = parser.parse_args()

    inputs = [ONTOLOGY_DIR / "scuba-core.ttl"] if args.core_only else DEFAULT_INPUTS
    print("Merging ontology files…")
    merge_ontology(inputs, COMBINED)
    print("Running pyLODE…")
    generate_html(COMBINED, OUTPUT)
    print("Done. Open docs/index.html in a browser.")

    if args.serve:
        serve(args.port)
    return 0


if __name__ == "__main__":
    sys.exit(main())
