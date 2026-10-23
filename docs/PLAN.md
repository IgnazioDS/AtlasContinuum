# WorldPane roadmap

## Release foundation

- Complete the WorldPane identity and automatic settings migration.
- Maintain repeatable validation, packaging, and local development installation.
- Publish a beta only after the exact archive passes a clean-profile smoke test.

## Map fidelity

- Record Retail map drift with `/wpaudit` after every patch.
- Expand native-transition policies for worlds that do not share Azeroth's
  coordinate space.
- Fix art ownership at zone overlaps before adding decorative effects.
- Audit city minimap bands, land masks, exploration overlays, and labels at all
  zoom levels.

## Motion and navigation

- Standardize world, continent, zone, city, and native-map transitions.
- Add duration and easing rules based on travel distance and zoom delta.
- Preserve cursor focus and spatial context through transitions.
- Ensure right-click, Escape, wheel zoom, map breadcrumbs, and gamepad actions
  produce the same navigation hierarchy.

## Quest quality

- Verify active positions during accept, progress, failure, completion, and
  turn-in flows.
- Maintain native marker semantics and focused-quest filtering.
- Add mocked coverage for new quest-state branches before release.

## Visual refinement

- Improve title hierarchy, coordinate readability, edge controls, and menu
  spacing without obscuring map content.
- Normalize icon scale, hover states, selection glows, and tooltips.
- Test 16:9, ultrawide, high-DPI, windowed, maximized, and gamepad layouts.

## Independence

- Keep public identifiers and support surfaces under WorldPane control.
- Remove the migration helper after the supported upgrade window.
- Preserve all required legacy and third-party notices.
