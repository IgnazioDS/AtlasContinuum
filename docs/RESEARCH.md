# Research: how OpenMap works on Retail

## Identification and availability

The described addon is OpenMap. Its defining behavior is a single pannable,
zoomable map that blends Blizzard's world, continent, zone, city, cave, and
minimap art instead of navigating one discrete map page at a time.

As of 22 October 2026, OpenMap has an official Retail beta:

- Version: `v0.7.1-beta-retail`
- Game version: Retail 12.1.5
- CurseForge project: 1735937
- CurseForge file: 9274335
- Code license: MIT
- Retail release archive: about 4.3 MB compressed / 125 MB installed

The release archive was used as the baseline because the upstream GitHub URL
was temporarily unavailable during a repository transition.

## Runtime architecture

OpenMap is not a replacement web map. It augments Blizzard's
`WorldMapFrame`, which preserves the quest log, map controls, Blizzard pins,
and compatible third-party pins.

The stitched coordinate space is rooted at Azeroth `uiMapID 947`:

1. `C_Map.GetMapRectOnMap(childMapID, 947)` locates continent, zone, and city
   art in normalized world coordinates.
2. `C_Map.GetMapArtLayers` and `C_Map.GetMapArtLayerTextures` provide the
   client's own map tiles.
3. Generated Retail tables supply map classification, world-yard transforms,
   exploration/reveal pieces, minimap tiles, caves, dungeons, flights, places,
   color matching, and territory masks.
4. The rendering stack cross-fades world art, continent art, zone overlays,
   city maps, caves, and close-range minimap terrain according to zoom.
5. View culling and baked layers keep thousands of potential textures from
   being simultaneously anchored and drawn.
6. Once panning settles, OpenMap changes the *underlying* Blizzard map to the
   zone under the view. Blizzard and addon pins therefore query the correct
   map while the stitched art remains visually continuous.

Important implementation files:

| Concern | File |
| --- | --- |
| Addon lifecycle/settings | `AtlasContinuum/Core.lua`, `AtlasContinuum/Init.lua` |
| Retail tuning | `AtlasContinuum/Data/Retail/Client.lua` |
| World geometry/classification | `AtlasContinuum/Data/Retail/World.lua` |
| Stitched renderer | `AtlasContinuum/Map/Stitch.lua` |
| Zoom, pan, and map-frame integration | `AtlasContinuum/Map/WorldMap.lua` |
| Cross-zone active quest bridge | `AtlasContinuum/Map/QuestBridge.lua` |
| Detailed minimap layer | `AtlasContinuum/Map/Close.lua` |
| Dungeon/cave transitions | `AtlasContinuum/Map/Dungeons.lua` |
| Public integration API | `AtlasContinuum/API.lua` |
| Patch-drift detector | `AtlasContinuum/RetailLab/Audit.lua` |

## Retail-specific findings

- Retail's Azeroth contains many more continents than Forever; the client
  tuning uses a `zoom = 2` detail factor.
- Retail continent maps vary dramatically in resolution. Detail fade is
  calculated per continent using density rather than one global threshold.
- Retail world and continent maps already paint their own sea and coasts, so
  OpenMap does not replace the sea layer (`sea = false`).
- Stormwind and some city rectangles derived only from map hierarchy can be
  offset. The engine falls back to world-position transforms for cities.
- Undercity and Ironforge are treated as underground cities so their own art
  remains above surface minimap terrain.
- Questie-backed townsfolk are disabled on Retail; Retail uses its native pin
  ecosystem instead.
- The generated data is tied to a client build. New patches, phased maps, new
  continents, or changed art IDs require regeneration and visual validation.

## APIs and compatibility surface

The project relies on Retail's map canvas and `C_Map` APIs, especially:

- `C_Map.GetMapInfo`
- `C_Map.GetMapChildrenInfo`
- `C_Map.GetMapInfoAtPosition`
- `C_Map.GetMapRectOnMap`
- `C_Map.GetMapArtLayers`
- `C_Map.GetMapArtLayerTextures`
- `C_Map.GetWorldPosFromMapPos`

The Blizzard map canvas exposes pan/zoom entry points such as
`InstantPanAndZoom`, `SetPanTarget`, scale getters, and view rectangles. These
are implementation dependencies and must be checked after every major patch.

Upstream OpenMap published `OpenMapAPI` (major 1, version 2). Atlas Continuum
publishes the independently named `AtlasContinuumAPI` with equivalent initial
surface. Its
coordinate conversion, view events, menu toggles, and dungeon-card sections
should remain backward-compatible throughout this fork.

## Legal and distribution boundaries

- Preserve the upstream MIT copyright and license.
- Preserve Ace3 notices.
- Do not describe Blizzard-derived texture masks as MIT assets.
- Do not sell the addon, gate features behind payment, or add advertising.
- Before publishing, re-check Blizzard's current addon policy and the target
  distribution platform's rules.
- This fork should remain clearly attributed and should not imply endorsement
  by Blizzard or the upstream author.

## Current risks

1. **Missing generator toolchain.** The CurseForge runtime archive omits the
   upstream `tools/` directory. Generated tables can be audited but should not
   be hand-maintained long-term.
2. **No in-game test in this workspace.** Static checks cannot detect taint,
   frame-level conflicts, GPU fill-rate issues, or incorrect visual alignment.
3. **Patch drift.** Interface `120105` and data build `12.1.5.70448` will age.
4. **Addon conflicts.** Other map-frame modifiers can rewrite the same zoom,
   size, scroll, and frame-level behavior.
5. **Performance.** Retail's high-resolution zones make culling, lazy loading,
   and memory profiling release blockers rather than later optimizations.

## Sources consulted

- OpenMap CurseForge project and Retail release notes.
- The downloaded OpenMap Retail source archive and preserved license notices.
- Blizzard's live MapCanvas/WorldMap implementation as mirrored from the game
  UI source at `github.com/Gethe/wow-ui-source`.
