# Delivery plan

The baseline import and project scaffolding are complete. The remaining work is
ordered to protect the two hardest qualities of this addon: visual continuity
and compatibility with Blizzard/addon map pins.

## Phase 0 — Baseline and provenance (complete)

- Identify OpenMap and verify its public Retail release.
- Vendor `v0.7.1-beta-retail` without dropping license or asset notices.
- Record the Retail architecture, APIs, build coupling, risks, and legal
  boundaries.
- Add repeatable static checks and zip packaging.
- Add `/omraudit` to compare the live client with generated world data.

Exit: the repository produces an installable addon zip and all vendored TOC
entries resolve.

## Phase 1 — Retail smoke test (next)

- Install into a clean `_retail_` AddOns directory with only BugSack/BugGrabber
  optionally enabled.
- Test first login, `/reload`, opening/closing the map, windowed/fullscreen map,
  mouse and trackpad zoom, drag pan, click navigation, and saved view restore.
- Visit at least one map from each supported continent plus Stormwind,
  Orgrimmar, Ironforge, Undercity, Dornogal, Silvermoon, and Atal'Aman.
- Run `/omraudit` and save its result with the exact game build.
- Capture screenshots at world, continent, zone, city, cave/dungeon, and
  maximum-detail zoom levels.
- Profile `/openmap bench`; establish frame-time and memory baselines.

Exit: no Lua errors or taint warnings, no invisible/offset player arrow, and no
critical visual seams in the smoke matrix.

## Phase 2 — Restore reproducible data generation

- Recover the upstream public repository after its transition, including the
  `tools/` directory and data-source documentation.
- Diff the release archive against the source tag/commit and record the exact
  baseline commit.
- Make generation accept an explicit WoW client/build input and write to a
  staging directory.
- Add deterministic comparisons for `World.lua`, reveal data, minimap data,
  caves, dungeons, flights, places, tones, and masks.
- Fail CI when generated outputs differ from committed files.

Exit: a clean machine with the permitted game-data inputs can reproduce every
generated Retail data file and mask.

## Phase 3 — Retail coverage and quality

- Resolve every actionable `/omraudit` result.
- Add new continents, zones, cities, phased aliases, and world-yard mappings.
- Build screenshot fixtures for city alignment and major zone borders.
- Tune culling/fade thresholds per continent where art density differs.
- Validate ultrawide, 16:9, 16:10, Retina/high-DPI, and UI scales 75–100%.
- Test controller/gamepad behavior and combat/open-map transitions.

Exit: all supported zone/city maps with usable art and world geometry are
covered, and the visual regression matrix is accepted.

## Phase 4 — Compatibility

- Test Blizzard quest/world-quest/scenario pins and waypoint navigation.
- Test popular Retail pin providers one at a time: HandyNotes, TomTom,
  RareScanner, SilverDragon, GatherMate2, and World Quest Tracker.
- Detect conflicting full map modifiers and show one actionable warning.
- Keep `OpenMapAPI` major 1 compatible and document any version increment.

Exit: a published compatibility table and no known critical interaction bug.

## Phase 5 — Release

- Re-check the current Blizzard UI Add-On Development Policy.
- Update changelog/version metadata and remove development branding only after
  upstream coordination determines whether this is a contribution, fork, or
  successor package.
- Run `make check`, `make package`, and `unzip -t` on the artifact.
- Fresh-install the exact zip and repeat the smoke matrix.
- Publish source, commit/tag provenance, checksums, known limitations, and
  installation/conflict notes together.

Exit: installable artifact tested from a clean profile, public source and
license notices available, and rollback artifact retained.
