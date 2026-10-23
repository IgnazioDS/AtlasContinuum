# Atlas Continuum independence standard

## What independent means for this project

Atlas Continuum is already a separate addon product: it has its own repository,
package name, saved variables, public API, commands, inter-addon protocol,
branding, diagnostics, tests, and release artifacts. It has no runtime or
installation dependency on OpenMap. The imported `v0.7.1-beta-retail` release
is a frozen historical baseline; future Atlas Continuum work does not require
upstream releases or permission beyond the granted MIT license.

The current codebase remains a derivative fork. The OpenMap copyright and MIT
license notices must stay with inherited and modified inherited files. Product
and maintenance independence does not erase provenance.

## Completion criteria

Atlas Continuum can be called operationally independent when all of the
following are true:

1. Retail map tables and derived masks can be regenerated from documented
   Blizzard client inputs by Atlas Continuum-owned tools.
2. Patch drift is detected automatically and classified as stitchable,
   native-transition, unsupported, or intentionally excluded.
3. Navigation, stitching policy, quests, saved-data migrations, and packaging
   have automated regression coverage owned by this repository.
4. A clean Retail smoke matrix is completed for every supported client build,
   including world-space navigation, representative zones/cities, quests,
   `/reload`, combat lockdown, and common map addons.
5. Source hosting, issue tracking, release notes, checksums, CurseForge files,
   and compatibility policy are maintained under Atlas Continuum accounts.
6. Every redistributed code and art asset has documented provenance and a
   redistribution basis.

## Clean-room option

If the goal changes from operational independence to a codebase with no
inherited OpenMap implementation, create a separate clean-room project. One
team writes behavior-only specifications and public API tests; another team,
without access to OpenMap source, implements them against Blizzard's APIs.
That is a new engineering program. Renaming symbols, rewriting comments, or
removing notices from this repository would not make the current fork
clean-room and would violate its license obligations.
