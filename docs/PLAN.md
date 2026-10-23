# Delivery plan

## Completed foundation

- Imported OpenMap `v0.7.1-beta-retail` with license and asset provenance.
- Established the independent **Atlas Continuum** folder, manifest, saved
  variables, API, commands, addon-message prefix, UI globals, and package name.
- Added a Retail coverage audit and repeatable static/package validation.
- Diagnosed Blizzard's single-host-map quest-provider limitation.
- Added a cross-zone active quest bridge that preserves native quest pins and
  renders only missing ongoing quests.
- Added a mocked Retail behavior test for filtering, projection, rendering, and
  quest super-tracking.
- Added Retail Quest Layer 2.0 marker states, watched/super-tracked emphasis,
  objective progress, richer tooltips, configurable sizing, tracked-only mode,
  and refresh coverage for the full active-quest lifecycle.
- Added focused-quest behavior, campaign-aware marker treatments, marker
  opacity and progress-label controls, and a live super-tracked quest guide.
- Restored the parent/cosmic map transition so Outland, Draenor, and other
  world spaces remain reachable from the seamless Azeroth view.
- Added explicit native-map transitions for Voidstorm and Harandar.
- Added Retail overlap priority and shared-minimap masking policies for the
  rebuilt Quel'Thalas and Silvermoon maps.

## Maintenance independence

- Treat the imported OpenMap release as a frozen historical baseline; do not
  depend on future upstream changes or releases.
- Own Retail map policy, diagnostics, tests, packaging, source hosting, issue
  tracking, versioning, and release notes in this repository.
- Reconstruct an Atlas Continuum-owned generator toolchain for build-bound map
  tables before calling the addon patch-independent.
- Preserve the inherited MIT notices permanently. Zero derivative status would
  require a separately staffed clean-room rewrite; it cannot be achieved by
  deleting attribution from the current fork.

See `docs/INDEPENDENCE.md` for the technical and legal completion criteria.

## Next quest-layer increment

- Investigate rendering Blizzard quest objective areas for non-host zones.
  Blizzard's blob provider is bound to the map canvas's current `uiMapID`, so
  this requires a separate projected renderer rather than reusing its single
  native blob pin blindly.
- Add an in-game diagnostic that reports why an active quest could not be
  projected: missing waypoint, unstitched map, secret value, or native pin.
- Add an optional distance readout to the super-tracked quest guide after
  validating phased and cross-continent world-position behavior in game.

## Release gate 1 — in-game quest verification

- Fresh-install the generated beta zip.
- Test an active quest in the hosted zone and confirm there is no duplicate pin.
- Test active quests in two neighboring visible zones.
- Advance an objective and confirm its marker refreshes or moves.
- Complete a quest and confirm the turn-in marker appears.
- Click a bridged marker and confirm Blizzard super-tracking updates.
- Focus a quest from the quest log and confirm unrelated bridged markers hide.
- Move with a super-tracked quest and confirm its guide line follows the player.
- Verify campaign, important, recurring, legendary, calling, and meta markers.
- Toggle the game's quest POI setting and confirm bridged markers follow it.
- Test quests whose next step is in a city, cave, dungeon, or another continent.
- Save Lua errors/taint output and exact client build.

Exit: active quests remain visible and interactive with no duplicates or Lua
errors through progress, completion, host-map switching, and `/reload`.

## Release gate 2 — map smoke matrix

- Test first login, windowed/full-screen map, mouse/trackpad zoom, drag pan,
  click navigation, and saved view restore.
- Visit representative continents plus Stormwind, Orgrimmar, Ironforge,
  Undercity, Dornogal, Silvermoon, and Atal'Aman.
- Run `/acaudit` and retain the result with the exact build.
- Capture world, continent, zone, city, dungeon, and maximum-detail screenshots.
- Run `/atlascontinuum bench` and record frame time and memory.

Exit: no critical visual seams, offset player arrows, taint, or blocked actions.

## Release gate 3 — compatibility

- Test HandyNotes, TomTom, RareScanner, SilverDragon, GatherMate2, and World
  Quest Tracker one at a time.
- Verify Leatrix Maps/Mapster conflict messaging.
- Confirm `AtlasContinuumAPI` callbacks and menu integration with a small test
  addon.
- Document known-compatible versions.

Exit: no known critical interaction bug and a published compatibility table.

## Release gate 4 — publishing

- Verify the original icon at in-game, addon-list, and CurseForge thumbnail sizes.
- Re-check name availability, Blizzard addon policy, CurseForge rules, and
  derived-asset distribution rights.
- Run `make check`, `make package`, and a clean install of the exact zip.
- Publish source, notices, beta changelog, screenshots, checksums, and known
  limitations together.

Exit: `AtlasContinuum-0.5.0-beta.1.zip` is tested from a clean profile and ready
for a CurseForge Beta upload. Actual upload requires the owner's CurseForge
account and final project approval.
