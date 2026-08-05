/** Client-side biology similarity for the static ontology visualizer (Pages). */
(function (global) {
  const WEIGHTS = {
    familyName: 4.0,
    subcategory: 3.0,
    bodyShape: 2.5,
    colorOverlap: 2.5,
    sizeOverlap: 2.5,
    sizeSimilar: 2.0,
    category: 1.5,
    depthOverlap: 1.0,
  };

  const COLOR_RE =
    /\b(black|white|gray|grey|yellow|blue|red|orange|green|brown|purple|pink|silver|gold|tan|cream|violet|olive|turquoise|cyan|scarlet|maroon)\b/gi;

  function norm(s) {
    return String(s || "")
      .trim()
      .toLowerCase();
  }

  function bodyShape(features) {
    const text = String(features || "");
    for (const line of text.split(/\n/)) {
      const trimmed = line.trim();
      if (!trimmed) continue;
      if (trimmed.toLowerCase().startsWith("body shape")) return trimmed;
    }
    const trimmed = text.trim();
    return trimmed.toLowerCase().startsWith("body shape") ? trimmed : null;
  }

  function colorTerms(text) {
    const found = new Set();
    const src = String(text || "");
    let m;
    COLOR_RE.lastIndex = 0;
    while ((m = COLOR_RE.exec(src))) {
      let t = m[1].toLowerCase();
      if (t === "grey") t = "gray";
      found.add(t);
    }
    return found;
  }

  function positive(n) {
    return typeof n === "number" && n > 0 ? n : null;
  }

  function rangesOverlap(a0, a1, b0, b1) {
    if (a0 == null || a1 == null || b0 == null || b1 == null) return false;
    return a0 <= b1 && b0 <= a1;
  }

  function maxSizeSimilar(a, b, tol = 0.35) {
    if (a == null || b == null || a <= 0 || b <= 0) return false;
    return Math.max(a, b) / Math.min(a, b) <= 1 + tol;
  }

  function addSignal(entries, id, signal, weight, detail) {
    let entry = entries.get(id);
    if (!entry) {
      entry = { id, score: 0, signals: {}, evidence: [] };
      entries.set(id, entry);
    }
    if (entry.signals[signal]) return;
    const ev = { signal, weight, detail: detail || null };
    entry.signals[signal] = ev;
    entry.score += weight;
    entry.evidence.push(ev);
  }

  function rankBiology(seed, catalog, limit = 12) {
    const seedId = seed.id || seed.iri;
    const entries = new Map();

    const seedFamily = norm(seed.familyName);
    if (seedFamily) {
      for (const c of catalog) {
        if ((c.id || c.iri) === seedId) continue;
        if (norm(c.familyName) === seedFamily) {
          addSignal(entries, c.id || c.iri, "familyName", WEIGHTS.familyName, seed.familyName);
        }
      }
    }

    const seedSub = norm(seed.subcategory);
    if (seedSub) {
      for (const c of catalog) {
        if ((c.id || c.iri) === seedId) continue;
        if (norm(c.subcategory) === seedSub) {
          addSignal(entries, c.id || c.iri, "subcategory", WEIGHTS.subcategory, seed.subcategory);
        }
      }
    }

    const seedShape = bodyShape(seed.distinctiveFeatures);
    if (seedShape) {
      const key = seedShape.toLowerCase();
      for (const c of catalog) {
        if ((c.id || c.iri) === seedId) continue;
        const cs = bodyShape(c.distinctiveFeatures);
        if (cs && cs.toLowerCase() === key) {
          addSignal(entries, c.id || c.iri, "bodyShape", WEIGHTS.bodyShape, seedShape);
        }
      }
    }

    const seedCategory = norm(seed.category);
    const seedColors = colorTerms(seed.aboutText);
    const seedMinSize = positive(seed.minSizeM);
    const seedMaxSize = positive(seed.maxSizeM);
    const seedMinDepth = positive(seed.minDepthM);
    const seedMaxDepth = positive(seed.maxDepthM);
    const hasFullSeedSize = seedMinSize != null && seedMaxSize != null;

    const byId = new Map(catalog.map((c) => [c.id || c.iri, c]));

    for (const id of [...entries.keys()]) {
      const c = byId.get(id);
      if (!c) continue;

      if (seedCategory && seedCategory === norm(c.category)) {
        addSignal(entries, id, "category", WEIGHTS.category, c.category);
      }

      const shared = [...seedColors].filter((t) => colorTerms(c.aboutText).has(t)).sort();
      if (shared.length) {
        addSignal(entries, id, "colorOverlap", WEIGHTS.colorOverlap, shared.join(","));
      }

      const cMinSize = positive(c.minSizeM);
      const cMaxSize = positive(c.maxSizeM);
      if (
        hasFullSeedSize &&
        cMinSize != null &&
        cMaxSize != null &&
        rangesOverlap(seedMinSize, seedMaxSize, cMinSize, cMaxSize)
      ) {
        addSignal(
          entries,
          id,
          "sizeOverlap",
          WEIGHTS.sizeOverlap,
          `${cMinSize}–${cMaxSize}m`
        );
      } else if (maxSizeSimilar(seedMaxSize, cMaxSize)) {
        addSignal(entries, id, "sizeSimilar", WEIGHTS.sizeSimilar, `max~${cMaxSize}m`);
      }

      const cMinDepth = positive(c.minDepthM);
      const cMaxDepth = positive(c.maxDepthM);
      if (
        seedMinDepth != null &&
        seedMaxDepth != null &&
        cMinDepth != null &&
        cMaxDepth != null &&
        seedMinDepth <= cMaxDepth &&
        cMinDepth <= seedMaxDepth
      ) {
        addSignal(
          entries,
          id,
          "depthOverlap",
          WEIGHTS.depthOverlap,
          `${cMinDepth}–${cMaxDepth}m`
        );
      }
    }

    const ranked = [...entries.values()]
      .filter((e) => e.score > 0)
      .map((e) => {
        const c = byId.get(e.id);
        return {
          iri: c ? c.iri : e.id,
          id: c ? c.id : e.id,
          commonName: c ? c.commonName : e.id,
          scientificName: c ? c.scientificName : null,
          score: Math.round(e.score * 100) / 100,
          biologyScore: Math.round(e.score * 100) / 100,
          sightingScore: 0,
          evidence: e.evidence
            .slice()
            .sort((a, b) => b.weight - a.weight || a.signal.localeCompare(b.signal))
            .map((ev) => ({
              signal: ev.signal,
              weight: ev.weight,
              detailLabel: ev.detail,
            })),
        };
      })
      .sort(
        (a, b) =>
          b.score - a.score ||
          String(a.commonName).localeCompare(String(b.commonName), undefined, {
            sensitivity: "base",
          })
      );

    return ranked.slice(0, Math.max(0, Math.min(limit, 50)));
  }

  global.OntologyBiologySimilarity = { rankBiology, WEIGHTS };
})(typeof window !== "undefined" ? window : globalThis);
