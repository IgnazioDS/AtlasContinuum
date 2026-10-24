# CurseForge release copy and checklist

## Listing

- Name: **WorldPane**
- Slug: `worldpane`
- Category: Map & Minimap
- Flavor: Retail
- Channel: Beta
- Summary: **One seamless Retail world map with cross-zone active quests.**
- License: Custom (mixed-license terms; use `LICENSE.md`)
- Source: `https://github.com/IgnazioDS/WorldPane`
- Issues: `https://github.com/IgnazioDS/WorldPane/issues`

## Description

**Every world. One map.**

WorldPane turns Retail's world map into one continuous canvas. Zoom from
Azeroth into continents, zones, cities, caves, and dungeons while keeping the
normal quest log, controls, and compatible addon pins.

Features:

- Responsive map HUD for compact, standard, and wide windows, with map type,
  hierarchy, and logarithmic zoom feedback.
- Continuous damped wheel zoom, distance-aware click glides, restrained major
  map transitions, and optional parchment atmosphere.
- Calm location labeling: stitched host-map changes stay quiet and hover names
  wait for the pointer to rest, with immediate and hidden modes available.
- Unified WorldPane component language across map chrome, navigation tabs,
  search, settings, tool windows, coordinate pills, and action states.
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

WorldPane began as a permitted fork of OpenMap `v0.7.1-beta-retail`, published
by jigrobbulus with source credited to jiforever, under the MIT License. The
original project is available at
https://www.curseforge.com/wow/addons/openmap.

Since that baseline, WorldPane has been independently re-engineered with its
own product identity, settings and API; cross-zone active quest markers;
multi-world navigation and live zone previews; native Voidstorm and Harandar
transitions; a new motion and visual system; and a current-Retail validation and
release workflow. Required attribution, the original MIT notice, and the exact
mixed-license boundary are bundled with every release.

The WorldPane project icon is original AI-assisted artwork created for this
project. It is not a Blizzard asset or a gameplay screenshot. WorldPane is not
affiliated with or endorsed by Blizzard Entertainment.

## Beta notes

- A quest without a usable current waypoint cannot be placed.
- Voidstorm and Harandar use Blizzard's native canvas because they do not share
  the stitched Azeroth coordinate space.
- The public archive contains one `WorldPane/` addon root. The legacy settings
  bridge remains only in the source repository for pre-release development
  installs.

## File changelog

Paste this into the `0.3.0-beta.4` file upload:

> **WorldPane 0.3.0-beta.4**
>
> - Adds one continuous Retail map from cosmic view through continents, zones,
>   cities, caves, and dungeons.
> - Adds cross-zone active quest markers with watched, ready, campaign,
>   recurring, legendary, calling, important, meta, and super-tracked states.
> - Adds live detailed previews and deeper zoom for Outland, Draenor, and other
>   non-Azeroth world spaces.
> - Opens Voidstorm and Harandar on Blizzard's coordinate-correct native maps.
> - Introduces responsive map chrome, continuous damped zoom, distance-aware
>   navigation, calmer labels, and optional parchment atmosphere.
> - Adds `/wpaudit` coverage diagnostics for Retail map-data changes.
> - Introduces the original WorldPane Azeroth emblem for the addon and project
>   avatar.

## Release checklist

- Confirm the name and slug remain available.
- Select **Custom License** and use the mixed-license statement from
  `LICENSE.md`; do not label the entire project as MIT.
- Upload the 400 x 400 PNG at `docs/assets/worldpane-icon.png` as the project
  avatar.
- Run `make check` and `make package`.
- Install the exact generated zip into a clean Retail profile.
- Test login, `/reload`, windowed and maximized map modes, zoom, pan, cosmic
  navigation, quest progress, quest turn-in, super-tracking, city alignment,
  and native transitions.
- Test without other addons, then with common pin providers.
- Upload `dist/WorldPane-0.3.0-beta.4.zip` as a Beta file.
- Publish the source, `NOTICE.md`, and license files with the release.

The installable archive must contain exactly one top-level folder named
`WorldPane/`. The folder name intentionally has no version suffix and matches
the addon's `.toc` filename.
