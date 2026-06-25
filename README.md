# GoDive

GoDive is an iPhone dive log app built with SwiftUI and SwiftData.

## User guide

The public user guide is published with GitHub Pages:

**https://andre495.github.io/GoDiveDev/**

### Edit locally

```bash
pip install mkdocs-material
mkdocs serve
```

Open http://127.0.0.1:8000 to preview. Pushes to `main` that touch `docs/` or `mkdocs.yml` deploy automatically via GitHub Actions.

### Enable GitHub Pages (one-time)

In the repo on GitHub: **Settings → Pages → Build and deployment → Source → GitHub Actions**.

The workflow uses [custom GitHub Pages workflows](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages) (`mkdocs build` → upload artifact → `deploy-pages`), not the legacy `gh-pages` branch.
