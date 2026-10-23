# Atlas Continuum

**Every horizon, one map.** Atlas Continuum is a Retail World of Warcraft addon
that turns Blizzard's world map into one continuous, detailed canvas. Zoom from
Azeroth into continents, zones, cities, caves, and dungeons without losing the
normal quest log, Blizzard controls, or compatible map pins.

Atlas Continuum is an independent fork of the MIT-licensed OpenMap
`v0.7.1-beta-retail`. Its first Retail-specific feature is a cross-zone active
quest bridge: Blizzard creates quest pins only for the single map hosted under
the stitched view, so Atlas Continuum adds only the missing ongoing-quest
positions across the other visible zones. Native Blizzard quest pins remain
untouched.

## Status

- Beta version: `0.2.0-beta.1`.
- Interface target: `120105` (Retail 12.1.5).
- Retail datasets: build `12.1.5.70448`.
- Quest bridge behavior is covered by a mocked Lua test.
- TOC entries, Retail data selection, Lua syntax, diagnostics, and packaging are
  validated by `make check`.
- An in-game smoke pass is still required before a public CurseForge upload.

## Install for testing

1. Copy the `AtlasContinuum` folder into
   `World of Warcraft/_retail_/Interface/AddOns/`.
2. Enable **Atlas Continuum** at the character screen.
3. Open the world map with `M`.
4. Run `/acaudit`, then `/acaudit missing` if drift is reported.

Do not enable Atlas Continuum and OpenMap at the same time. Their package names
and saved variables are distinct, but both intentionally control Blizzard's
world-map canvas.

## Commands

- `/atlascontinuum` or `/acmap` — open settings.
- `/atlascontinuum debug` — map performance overlay.
- `/atlascontinuum bench` — map performance benchmark.
- `/atlascontinuum pins` — saved map pins.
- `/atlascontinuum news` — release notes.
- `/acaudit` — compare the running Retail client with the stitching dataset.
- `/acaudit missing` — print missing map IDs, capped to avoid chat spam.

## Develop and package

```sh
make check
make package
make install
```

`make package` produces `dist/AtlasContinuum-<version>.zip` with the correct
installable folder. `make install` creates a development symlink in the locally
detected Retail client; pass `RETAIL_DIR="/path/to/_retail_"` to select one.
The installer refuses to replace an unrelated addon or symlink.

See [RESEARCH.md](docs/RESEARCH.md), [PLAN.md](docs/PLAN.md),
[BRAND.md](docs/BRAND.md), and [CURSEFORGE.md](docs/CURSEFORGE.md).

## Credits and licenses

Atlas Continuum is based on OpenMap `v0.7.1-beta-retail`. The original MIT
copyright and license are preserved in `AtlasContinuum/LICENSE.txt`, and full
provenance is recorded in [NOTICE.md](NOTICE.md). Bundled libraries retain their
own licenses. Blizzard map art and derived textures are not granted by the MIT
license; see the asset notice before redistribution.

- [OpenMap on CurseForge](https://www.curseforge.com/wow/addons/openmap)
- [Imported OpenMap Retail release](https://www.curseforge.com/wow/addons/openmap/files/9274335)
