# Ontology scripts

## GitHub Pages export

Publishes vocabulary docs + a static visualizer into the MkDocs site (used by `.github/workflows/deploy-docs.yml`):

```bash
# After mkdocs build:
python3 -m venv .venv && source .venv/bin/activate
pip install 'rdflib>=7,<8'
# Prefer a fresh pyLODE HTML first (separate venv; see docs/requirements.txt):
#   python docs/generate.py
python scripts/export_github_pages.py --out ../site/ontology
```

Smoke (few species only):

```bash
python scripts/export_github_pages.py --out /tmp/ontology-pages --max-species 20
```

Output layout:

- `vocabulary/index.html` — pyLODE
- `visualizer/` — static UI, overview graphs, `species/*.json`, browser biology similarity
