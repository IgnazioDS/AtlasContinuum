# OpenMap Retail Lab

An attributed, Retail-focused development fork of **OpenMap**. It keeps the
seamless world-map experience—zooming from Azeroth into continents, zones,
cities, caves, and detailed terrain—inside Blizzard's normal map frame so the
quest log and compatible map pins continue to work.

This repository starts from OpenMap `v0.7.1-beta-retail`, released for WoW
Retail 12.1.5 on 21 October 2026. The upstream code is MIT-licensed. Blizzard
map art and textures derived from it are not covered by that MIT license; see
[`NOTICE.md`](NOTICE.md) and [`OpenMap/Media/Textures/Retail/NOTICE.md`](OpenMap/Media/Textures/Retail/NOTICE.md).

## Status

- Working Retail baseline vendored from the public OpenMap release.
- Interface target: `120105` (Retail 12.1.5).
- Retail datasets are generated against build `12.1.5.70448`.
- `/omraudit` adds a live client-vs-dataset coverage report.
- Static validation and reproducible zip packaging are included.
- In-game smoke testing is still required on a local Retail installation.

## Install for testing

1. Copy the `OpenMap` folder into:
   `World of Warcraft/_retail_/Interface/AddOns/`
2. Start or reload WoW and enable **OpenMap Retail Lab**.
3. Open the world map with `M`.
4. Run `/omraudit`, then `/omraudit missing` if drift is reported.

Do not install this beside another copy of OpenMap. Both use the same addon
folder, global API, and saved-variable names. Disable map-frame modifiers such
as Mapster or Leatrix Maps during the first smoke test.

## Develop

```sh
make check
make package
make install
```

The package is written to `dist/` and contains an installable `OpenMap/`
folder. `make install` creates a development symlink in the locally detected
Retail client; pass `RETAIL_DIR="/path/to/_retail_"` to select one explicitly.
It refuses to replace an existing `AddOns/OpenMap` installation.

See [`docs/RESEARCH.md`](docs/RESEARCH.md) for the technical model and
[`docs/PLAN.md`](docs/PLAN.md) for the delivery roadmap.

## Useful commands

- `/openmap` — OpenMap settings.
- `/openmap debug` — upstream diagnostic overlay.
- `/openmap bench` — upstream map performance benchmark.
- `/omraudit` — compare the running Retail client's zone/city maps with the
  generated stitching dataset.
- `/omraudit missing` — print missing map IDs (capped to avoid chat spam).

## Upstream

- [OpenMap on CurseForge](https://www.curseforge.com/wow/addons/openmap)
- [Retail baseline release](https://www.curseforge.com/wow/addons/openmap/files/9274335)

The upstream GitHub repository was being transitioned when this project was
created. Reconcile this fork with the public repository, including its omitted
data-generation tools, as soon as that source is available again.
