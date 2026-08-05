const assert = require("assert");
const {
  buildSpeciesSimilarity,
  publicFieldsFromPrivate,
  publicFieldsFromSiteReportPrivate,
} = require("./speciesSimilarity");

const rows = [
  {
    status: "active",
    marineLifeUUID: "marine-life-french-angelfish",
    odmSiteId: "s1",
    waterBody: "Caribbean Sea",
    timeOfDay: "day",
    sightingDepthM: 12,
  },
  {
    status: "active",
    marineLifeUUID: "marine-life-queen-angelfish",
    odmSiteId: "s1",
    waterBody: "Caribbean Sea",
    timeOfDay: "day",
    sightingDepthM: 14,
  },
  {
    status: "deleted",
    marineLifeUUID: "marine-life-gray-angelfish",
    odmSiteId: "s1",
  },
];

const result = buildSpeciesSimilarity(rows, { limit: 6 });
assert.ok(result.bySpecies["marine-life-french-angelfish"]);
const top = result.bySpecies["marine-life-french-angelfish"][0];
assert.strictEqual(top.uuid, "marine-life-queen-angelfish");
assert.ok(top.sightingScore >= 4);

const pub = publicFieldsFromPrivate({
  contributionId: "abc",
  marineLifeUUID: "marine-life-x",
  status: "active",
  timeOfDay: "night",
  sightingDate: "2026-01-01",
  activityKind: "dive",
  schemaVersion: 2,
  country: "Bonaire",
  region: "Kralendijk",
  waterBody: "Caribbean Sea",
});
assert.strictEqual(pub.contributionId, "abc");
assert.strictEqual(pub.country, "Bonaire");
assert.strictEqual(pub.region, "Kralendijk");
assert.strictEqual(publicFieldsFromPrivate({ status: "active" }), null);

const pubWithReport = publicFieldsFromPrivate({
  contributionId: "sight-1",
  marineLifeUUID: "marine-life-x",
  status: "active",
  siteReportId: "report-opaque-1",
  timeOfDay: "day",
  sightingDate: "2026-01-01",
  activityKind: "dive",
  schemaVersion: 3,
});
assert.strictEqual(pubWithReport.siteReportId, "report-opaque-1");

const siteReportPub = publicFieldsFromSiteReportPrivate({
  contributionId: "report-opaque-1",
  status: "active",
  activityKind: "dive",
  reportDate: "2026-01-01",
  timeOfDay: "day",
  reportedMaxDepthM: 28,
  reportedCurrent: "low",
  country: "Australia",
  schemaVersion: 1,
});
assert.strictEqual(siteReportPub.contributionId, "report-opaque-1");
assert.strictEqual(siteReportPub.kind, "siteReport");
assert.strictEqual(siteReportPub.reportedMaxDepthM, 28);
assert.strictEqual(siteReportPub.reportedCurrent, "low");

const sameReport = buildSpeciesSimilarity(
  [
    {
      status: "active",
      marineLifeUUID: "marine-life-tiger",
      siteReportId: "report-shared",
      timeOfDay: "day",
      sightingDepthM: 20,
    },
    {
      status: "active",
      marineLifeUUID: "marine-life-lemon",
      siteReportId: "report-shared",
      timeOfDay: "day",
      sightingDepthM: 22,
    },
  ],
  { limit: 6 }
);
assert.ok(sameReport.bySpecies["marine-life-tiger"]);
assert.ok(
  sameReport.bySpecies["marine-life-tiger"][0].sightingScore >= 5,
  "sameSiteReport should award at least 5"
);

const softGeo = buildSpeciesSimilarity(
  [
    {
      status: "active",
      marineLifeUUID: "marine-life-a",
      country: "Bonaire",
      waterBody: "Caribbean Sea",
      timeOfDay: "day",
    },
    {
      status: "active",
      marineLifeUUID: "marine-life-b",
      country: "Bonaire",
      waterBody: "Caribbean Sea",
      timeOfDay: "day",
    },
  ],
  { limit: 6 }
);
assert.ok(softGeo.bySpecies["marine-life-a"]);
assert.ok(softGeo.bySpecies["marine-life-a"][0].sightingScore > 0);

console.log("speciesSimilarity.test.js OK");
