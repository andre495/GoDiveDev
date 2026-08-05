/**
 * Community sighting → species similarity cache (Node port of ontology sighting weights).
 * Cross-user: emphasize sameSite / waterBody / timeOfDay / similarDepth / co-occurrence.
 * Soft geography: country / region when present.
 */

const SIGHTING_WEIGHTS = {
  sameSite: 4.0,
  sameSiteReport: 5.0,
  sameWaterBody: 3.0,
  coOccurrence: 3.0,
  sameTimeOfDay: 2.0,
  similarDepth: 2.0,
  sameCountry: 1.5,
  sameRegion: 1.0,
};

function siteKey(row) {
  if (row.odmSiteId && String(row.odmSiteId).trim()) {
    return `odm:${String(row.odmSiteId).trim().toLowerCase()}`;
  }
  if (row.diveSiteCatalogUUID && String(row.diveSiteCatalogUUID).trim()) {
    return `cat:${String(row.diveSiteCatalogUUID).trim().toLowerCase()}`;
  }
  return null;
}

function normPlace(value) {
  if (!value || typeof value !== "string") return null;
  const trimmed = value.trim().toLowerCase();
  return trimmed || null;
}

function addSignal(entry, signal, weight, detail) {
  if (entry.signals[signal]) return;
  entry.signals[signal] = true;
  entry.score += weight;
  entry.evidence.push({ signal, weight, detail: detail || null });
}

function scorePair(entry, a, b, opts = {}) {
  const { awardSite = false, awardCoOccurrence = false, awardSiteReport = false } = opts;
  if (awardSiteReport) {
    const reportId =
      a.siteReportId && String(a.siteReportId).trim()
        ? String(a.siteReportId).trim().toLowerCase()
        : null;
    addSignal(entry, "sameSiteReport", SIGHTING_WEIGHTS.sameSiteReport, reportId);
  }
  if (awardSite) {
    addSignal(entry, "sameSite", SIGHTING_WEIGHTS.sameSite, siteKey(a));
  }
  if (awardCoOccurrence) {
    addSignal(entry, "coOccurrence", SIGHTING_WEIGHTS.coOccurrence, siteKey(a) || normPlace(a.waterBody));
  }
  const waterA = normPlace(a.waterBody);
  const waterB = normPlace(b.waterBody);
  if (waterA && waterB && waterA === waterB) {
    addSignal(entry, "sameWaterBody", SIGHTING_WEIGHTS.sameWaterBody, a.waterBody);
  }
  const countryA = normPlace(a.country);
  const countryB = normPlace(b.country);
  if (countryA && countryB && countryA === countryB) {
    addSignal(entry, "sameCountry", SIGHTING_WEIGHTS.sameCountry, a.country);
  }
  const regionA = normPlace(a.region);
  const regionB = normPlace(b.region);
  if (regionA && regionB && regionA === regionB) {
    addSignal(entry, "sameRegion", SIGHTING_WEIGHTS.sameRegion, a.region);
  }
  if (a.timeOfDay && b.timeOfDay && a.timeOfDay === b.timeOfDay) {
    addSignal(entry, "sameTimeOfDay", SIGHTING_WEIGHTS.sameTimeOfDay, a.timeOfDay);
  }
  const d1 = Number(a.sightingDepthM);
  const d2 = Number(b.sightingDepthM);
  if (Number.isFinite(d1) && Number.isFinite(d2) && Math.abs(d1 - d2) <= 5) {
    addSignal(entry, "similarDepth", SIGHTING_WEIGHTS.similarDepth, `${d2}m`);
  }
}

/**
 * @param {Array<object>} rows active communitySightings docs
 * @param {{ limit?: number }} [opts]
 */
function buildSpeciesSimilarity(rows, opts = {}) {
  const limit = Math.max(1, Math.min(opts.limit || 15, 50));
  const active = (rows || []).filter(
    (r) => r && r.status === "active" && r.marineLifeUUID
  );

  /** @type {Map<string, object[]>} */
  const bySite = new Map();
  /** @type {Map<string, object[]>} */
  const bySiteReport = new Map();
  /** @type {Map<string, object[]>} */
  const byWater = new Map();
  /** @type {Map<string, object[]>} */
  const byCountry = new Map();

  for (const row of active) {
    const key = siteKey(row);
    if (key) {
      if (!bySite.has(key)) bySite.set(key, []);
      bySite.get(key).push(row);
    }
    const reportId =
      row.siteReportId && String(row.siteReportId).trim()
        ? String(row.siteReportId).trim().toLowerCase()
        : null;
    if (reportId) {
      if (!bySiteReport.has(reportId)) bySiteReport.set(reportId, []);
      bySiteReport.get(reportId).push(row);
    }
    const water = normPlace(row.waterBody);
    if (water) {
      if (!byWater.has(water)) byWater.set(water, []);
      byWater.get(water).push(row);
    }
    const country = normPlace(row.country);
    if (country) {
      if (!byCountry.has(country)) byCountry.set(country, []);
      byCountry.get(country).push(row);
    }
  }

  /** @type {Map<string, Map<string, { score: number, signals: object, evidence: any[] }>>} */
  const scores = new Map();

  function ensure(seed, cand) {
    if (!scores.has(seed)) scores.set(seed, new Map());
    const m = scores.get(seed);
    if (!m.has(cand)) {
      m.set(cand, { score: 0, signals: {}, evidence: [] });
    }
    return m.get(cand);
  }

  function pairWithin(groups, opts) {
    for (const [, events] of groups) {
      for (let i = 0; i < events.length; i++) {
        for (let j = 0; j < events.length; j++) {
          if (i === j) continue;
          const a = events[i];
          const b = events[j];
          if (a.marineLifeUUID === b.marineLifeUUID) continue;
          const entry = ensure(a.marineLifeUUID, b.marineLifeUUID);
          scorePair(entry, a, b, opts);
        }
      }
    }
  }

  // Strongest: same SiteReport (1:1 activity visit) then same site.
  pairWithin(bySiteReport, { awardSiteReport: true, awardCoOccurrence: true });
  pairWithin(bySite, { awardSite: true, awardCoOccurrence: true });
  // Soft: same water body / country when site ids are sparse.
  pairWithin(byWater, { awardSite: false, awardCoOccurrence: false });
  pairWithin(byCountry, { awardSite: false, awardCoOccurrence: false });

  const bySpecies = {};
  for (const [seed, candMap] of scores) {
    const ranked = [...candMap.entries()]
      .map(([uuid, entry]) => ({
        uuid,
        sightingScore: Math.round(entry.score * 100) / 100,
        evidence: entry.evidence.sort(
          (x, y) => y.weight - x.weight || x.signal.localeCompare(y.signal)
        ),
      }))
      .filter((r) => r.sightingScore > 0)
      .sort(
        (a, b) =>
          b.sightingScore - a.sightingScore || a.uuid.localeCompare(b.uuid)
      )
      .slice(0, limit);
    if (ranked.length) bySpecies[seed] = ranked;
  }

  return {
    schemaVersion: 1,
    updatedAt: new Date().toISOString(),
    weights: SIGHTING_WEIGHTS,
    bySpecies,
  };
}

function publicFieldsFromPrivate(data) {
  if (!data || typeof data !== "object") return null;
  const contributionId = data.contributionId;
  if (typeof contributionId !== "string" || !contributionId.trim()) return null;
  const status = data.status === "deleted" ? "deleted" : "active";
  const out = {
    contributionId: contributionId.trim(),
    marineLifeUUID: String(data.marineLifeUUID || "").trim(),
    timeOfDay: String(data.timeOfDay || "day"),
    sightingDate: String(data.sightingDate || ""),
    activityKind: String(data.activityKind || "dive"),
    status,
    schemaVersion: Number(data.schemaVersion) || 1,
  };
  if (!out.marineLifeUUID && status === "active") return null;
  if (data.odmSiteId) out.odmSiteId = String(data.odmSiteId);
  if (data.diveSiteCatalogUUID) {
    out.diveSiteCatalogUUID = String(data.diveSiteCatalogUUID);
  }
  if (data.waterBody) out.waterBody = String(data.waterBody);
  if (data.country) out.country = String(data.country);
  if (data.region) out.region = String(data.region);
  if (typeof data.sightingDepthM === "number") {
    out.sightingDepthM = data.sightingDepthM;
  }
  if (data.siteReportId) out.siteReportId = String(data.siteReportId).trim();
  return out;
}

/** SiteReport staging → public communitySiteReports (no marineLifeUUID required). */
function publicFieldsFromSiteReportPrivate(data) {
  if (!data || typeof data !== "object") return null;
  const contributionId = data.contributionId;
  if (typeof contributionId !== "string" || !contributionId.trim()) return null;
  const status = data.status === "deleted" ? "deleted" : "active";
  const out = {
    contributionId: contributionId.trim(),
    activityKind: String(data.activityKind || "dive"),
    reportDate: String(data.reportDate || ""),
    timeOfDay: String(data.timeOfDay || "day"),
    status,
    schemaVersion: Number(data.schemaVersion) || 1,
    kind: "siteReport",
  };
  if (data.odmSiteId) out.odmSiteId = String(data.odmSiteId);
  if (data.diveSiteCatalogUUID) {
    out.diveSiteCatalogUUID = String(data.diveSiteCatalogUUID);
  }
  if (data.waterBody) out.waterBody = String(data.waterBody);
  if (data.country) out.country = String(data.country);
  if (data.region) out.region = String(data.region);
  if (typeof data.reportedMaxDepthM === "number") {
    out.reportedMaxDepthM = data.reportedMaxDepthM;
  }
  if (data.reportedCurrent) out.reportedCurrent = String(data.reportedCurrent);
  if (data.reportedVisibility) {
    out.reportedVisibility = String(data.reportedVisibility);
  }
  if (typeof data.reportedWaterTempC === "number") {
    out.reportedWaterTempC = data.reportedWaterTempC;
  }
  if (data.reportedWaterType) {
    out.reportedWaterType = String(data.reportedWaterType);
  }
  return out;
}

module.exports = {
  SIGHTING_WEIGHTS,
  buildSpeciesSimilarity,
  publicFieldsFromPrivate,
  publicFieldsFromSiteReportPrivate,
  siteKey,
};
