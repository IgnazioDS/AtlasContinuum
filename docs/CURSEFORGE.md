# CurseForge release copy and checklist

## Listing

- Name: **WorldPane**
- Slug: `worldpane`
- Category: Map & Minimap
- Flavor: Retail
- Channel: Beta
- Summary: **One seamless Retail world map with cross-zone active quests.**

## Description

**Every world. One map.**

WorldPane turns Retail's world map into one continuous canvas. Zoom from
Azeroth into continents, zones, cities, caves, and dungeons while keeping the
normal quest log, controls, and compatible addon pins.

Features:

- Seamless world-to-zone zoom and cross-zone panning.
- Cosmic navigation plus detailed, smoothly blended zone previews for Outland,
  Draenor, and other world spaces.
- Native detailed transitions for detached zones such as Voidstorm and
  Harandar.
- Active quest positions across every visible zone, without replacing native
  Blizzard pins.
- Watched, ready, super-tracked, campaign, recurring, legendary, calling,
  important, and meta quest treatments.
- Objective progress, rich quest tooltips, focused-quest filtering, marker
  controls, and an optional super-tracked guide line.
- Dungeon entrances and maps, flight masters, routes, saved pins, drawing
  tools, exploration controls, and live coverage diagnostics.

WorldPane began from MIT-licensed OpenMap code; required attribution and the
mixed-license terms are bundled with every release. WorldPane is not affiliated
with or endorsed by Blizzard Entertainment.

## Beta notes

- A quest without a usable current waypoint cannot be placed.
- Voidstorm and Harandar use Blizzard's native canvas because they do not share
  the stitched Azeroth coordinate space.
- The archive includes a tiny load-on-demand helper that migrates settings from
  the previous package identity; it contains no map implementation.

## Release checklist

- Confirm the name and slug remain available.
- Upload `docs/assets/worldpane-icon.png` as the project icon.
- Run `make check` and `make package`.
- Install the exact generated zip into a clean Retail profile.
- Test login, `/reload`, windowed and maximized map modes, zoom, pan, cosmic
  navigation, quest progress, quest turn-in, super-tracking, city alignment,
  native transitions, and saved-settings migration.
- Test without other addons, then with common pin providers.
- Upload `dist/WorldPane-0.1.1-beta.1.zip` as a Beta file.
- Publish the source, `NOTICE.md`, and license files with the release.

The installable archive must contain both `WorldPane/` and the load-on-demand
`AtlasContinuum/` settings-migration helper. The latter is a compatibility
folder, not the public product name.
