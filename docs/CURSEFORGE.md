# CurseForge release copy and checklist

## Listing fields

- Project name: **Atlas Continuum**
- Working slug: `atlas-continuum`
- Category: Map & Minimap
- Game flavor: Retail
- Initial release channel: Beta
- Summary: **One seamless Retail world map, from Azeroth to city detail, with
  cross-zone active quest positions.**

## Description

**Every horizon, one map.**

Atlas Continuum transforms the Retail world map into one continuous canvas.
Zoom smoothly from Azeroth into continents, zones, cities, caves, and dungeons
while keeping Blizzard's normal map frame, quest log, controls, and compatible
pins.

Its Retail quest bridge restores the active quest positions that disappear in
a stitched map: Blizzard supplies quest pins only for the one zone hosted under
the canvas, while Atlas Continuum may show several zones at once. Atlas
Continuum preserves native pins and adds only the missing ongoing quests.

Features:

- Seamless world-to-zone zoom and cross-zone panning.
- Detailed Retail zone, city, cave, and dungeon views.
- Missing active quest positions across visible zones, with watched, ready,
  failed, disabled, and super-tracked visual states.
- Objective progress, richer tooltips, click-to-super-track, marker sizing,
  and an optional tracked-only mode.
- Blizzard quest log and map controls remain in their normal frame.
- Dungeon entrances, flight masters, boats, zeppelins, routes, map pins, and
  drawing tools.
- Configurable exploration, detail, coordinates, icons, and map window.
- In-game Retail dataset audit with `/acaudit`.

Atlas Continuum is an independent fork of the MIT-licensed OpenMap project.
OpenMap's original copyright and license are included with the addon. World of
Warcraft and its art are trademarks/property of Blizzard Entertainment; Atlas
Continuum is not affiliated with or endorsed by Blizzard.

## Beta notes

- Do not enable Atlas Continuum and OpenMap together; both control the same map
  canvas.
- The active-quest bridge intentionally excludes hidden/internal quests and
  task/bounty entries handled by Blizzard's other map providers.
- A quest whose next waypoint has no usable position on the stitched Azeroth
  map cannot be rendered by the bridge.

## Screenshots to capture

1. Whole-world view showing the continuous parchment.
2. Continent-to-zone transition.
3. City detail.
4. Two visible neighboring zones with bridged active quest markers.
5. Quest marker tooltip and super-tracked state.
6. Dungeon map and side panel.
7. Settings menu.

## Before upload

- Confirm the project name and slug are still available.
- Upload `docs/assets/atlas-continuum-icon.png` as the project icon.
- Re-check Blizzard's current UI Add-On Development Policy and CurseForge rules,
  especially redistribution of derived map masks.
- Run `make check` and `make package`.
- Install the exact generated zip into a clean Retail profile.
- Test login, `/reload`, windowed/full-screen map, zoom, pan, quest progress,
  quest turn-in, super-tracking, city alignment, and saved settings.
- Test with no other addons, then with common pin providers.
- Upload `dist/AtlasContinuum-0.3.0-beta.1.zip` as a Beta file.
- Publish the source and `NOTICE.md` with the release.

## Policy notes

- Distribute the addon free of charge with unobfuscated, publicly viewable code.
- Keep advertisements and donation requests out of the in-game UI.
- Keep the archive to one `AtlasContinuum/` root containing the matching
  `AtlasContinuum_Mainline.toc`.
- The code/license requirements are satisfied by the current archive; derived
  Blizzard map-mask redistribution still needs a final rights/policy review.

## Initial changelog

### New

- Status-aware cross-zone active quest markers on the seamless map.
- Objective progress, enhanced quest tooltips, marker sizing, and tracked-only
  mode.

### Attribution

- Based on OpenMap `v0.7.1-beta-retail`; original MIT notices preserved.
