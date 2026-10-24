# WorldPane

**Every world. One map.** WorldPane turns the Retail World of Warcraft map into
one continuous, detailed canvas. Move from Azeroth to continents, zones, cities,
caves, and dungeons while retaining Blizzard's quest log, controls, and
compatible map pins.

WorldPane is an independent product with its own addon identity, saved data,
API, inter-addon protocol, validation, packaging, and support workflow.

## Current beta

- Version `0.3.0-beta.4`; Retail interface `120105`.
- A new Azeroth emblem anchors the addon identity across the in-game launcher,
  WorldPane interface, release archive, and CurseForge artwork.
- A responsive map HUD adapts to compact, standard, and wide windows while
  preserving map type, title, hierarchy, and live logarithmic zoom depth.
- Wheel input carries through a continuous damped zoom, while click navigation
  adapts its travel time to distance and depth for smoother movement.
- Major map changes use a restrained location announcement; routine stitched
  zone tracking stays quiet, and hover names wait until the pointer rests.
- Optional zoom-reactive edge atmosphere and parchment grain unify map art
  from different World of Warcraft eras.
- A token-driven obsidian, parchment, bronze, and gold component system covers
  map chrome, menus, tabs, search, coordinate pills, settings, and interaction
  states with consistent focus, hover, and selection feedback.
- Cross-zone active quest markers preserve watched, super-tracked, ready,
  campaign, recurring, legendary, calling, important, and meta treatments.
- Objective progress, focused-quest filtering, rich tooltips, marker controls,
  and an optional guide line to the super-tracked quest.
- Zooming beyond Azeroth reaches Blizzard's cosmic map for Outland, Draenor,
  and other world spaces; their continent maps gain live zone-detail previews
  and deeper, smoothly blended zoom levels.
- Voidstorm and Harandar map portals open their coordinate-correct native maps
  with either mouse button, including when their live link geometry arrives
  after WorldPane's first stitched-map build.
- Targeted current-Retail policies improve Quel'Thalas overlap and Silvermoon
  close-up rendering.
- Development installs retain a one-time bridge for settings from the previous
  package identity; the public release is a clean, single-addon install.

## Install

Extract the release archive into `_retail_/Interface/AddOns/`. The archive
contains one `WorldPane` folder. Enable **WorldPane**, open the map with `M`, and
use `/wpaudit` after major Retail patches to check map-data coverage.

## Commands

- `/worldpane` or `/wpmap` — settings.
- `/worldpane debug` — performance overlay.
- `/worldpane bench` — performance benchmark.
- `/worldpane pins` — saved pins.
- `/worldpane news` — release notes.
- `/wpaudit` — compare the current Retail client with the stitched dataset.
- `/wpaudit missing` — list missing map IDs.

## Develop and package

```sh
make check
make package
make install
```

`make package` creates `dist/WorldPane-<version>.zip`. `make install` safely
links both package folders into a detected Retail client; pass
`RETAIL_DIR="/path/to/_retail_"` to select one explicitly.

## Licensing and provenance

WorldPane is a mixed-license project: the historical MIT foundation remains
MIT, while original work after the documented boundary is All Rights Reserved.
WorldPane began as a permitted fork of the MIT-licensed
[OpenMap](https://www.curseforge.com/wow/addons/openmap) `v0.7.1-beta-retail`
codebase; the required notice and exact boundary are bundled in
[NOTICE.md](NOTICE.md) and [LICENSE.md](LICENSE.md). Third-party libraries retain
their own licenses. Blizzard map art is not licensed by the software licenses.
