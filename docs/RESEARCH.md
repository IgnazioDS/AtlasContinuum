# WorldPane Retail architecture

## Rendering model

WorldPane augments Blizzard's `WorldMapFrame`. A stitched coordinate system
places supported Azeroth continents, zones, cities, exploration overlays, and
detail layers into one pannable canvas. World spaces outside Azeroth retain
Blizzard's native coordinate system while WorldPane discovers their child
zones at runtime and crossfades detailed zone art into the regional canvas.
Blizzard remains responsible for the host frame, quest log, pin providers, and
the native coordinate system.

The central rule is ownership by map depth: broad parchment and continent art
appear at low zoom; zone and city art become authoritative as the view closes
in. Overlap policies decide which current-Retail layer wins where old and new
map rectangles intersect.

## Presentation architecture

The visual layer is separate from navigation and map ownership. Raw palette
values become semantic roles, then component tokens shared by map chrome,
menus, tool windows, information pills, and action tiles. The default language
uses obsidian surfaces, parchment text, bronze structure, and a restrained gold
accent so map artwork remains the visual focus.

A non-interactive canvas overlay supplies an adaptive context HUD, logarithmic
zoom feedback, edge atmosphere, subtle grain, and staged map-title transitions.
The HUD has compact, standard, and wide contracts with an intentional maximum
measure, progressively compressed breadcrumbs, and stable zoom controls. Map
changes use entrance, hold, and exit phases so context is readable without
delaying navigation. Each effect can be disabled independently and none owns
clicks, map state, or navigation. This keeps presentation changes reversible
and prevents visual polish from changing map behavior.

Interactive components share explicit default, hover, selected, focused, and
disabled states. Navigation tabs, checklist rows, coordinate pills, and place
search consume the same semantic tokens rather than inheriting unrelated
Blizzard art from different interface generations. The atmosphere intensity is
adjustable independently from the map artwork.

## Navigation hierarchy

1. Azeroth uses the stitched canvas.
2. Wheel zoom and clicks descend into supported continent, zone, and city art.
3. Non-Azeroth continents stay on their native canvas but gain dynamically
   discovered zone previews and deeper zoom levels.
4. Detached zones without a parent rectangle, including map-link medallions,
   transition directly to their detailed native canvas. Their `UiMapLink`
   rectangles are navigation portals rather than zone geometry, so WorldPane
   resolves their live link centres and retains complete client-specific hit
   bounds instead of feeding them into the stitched child-map hierarchy.
5. Zooming or navigating outward from the fitted Azeroth view reaches the
   cosmic map, where Outland, Draenor, and other worlds remain selectable.
6. Back, right-click, Escape, breadcrumbs, and gamepad actions must preserve a
   predictable parent chain.

## Quest bridge

Blizzard normally creates quest pins for the single map hosted beneath the
canvas. A stitched view may expose several zones, so WorldPane asks current
quest APIs for active waypoints, converts usable positions into stitched world
coordinates, and adds only markers that native providers did not create.

The bridge refreshes on quest-log, watch, waypoint, criteria, task, acceptance,
removal, and turn-in events. It preserves focused-quest behavior and treats
super-tracking as a stronger visual and navigation state.

## Data and drift

Generated Retail tables describe map rectangles, hierarchy, art, exploration,
places, caves, dungeons, flights, minimap detail, tones, edits, and territories.
`RetailLab/Audit.lua` compares those expectations with the running client.
Missing data, missing art, missing rectangles, and intentional native fallbacks
are reported separately so a correct transition is not mistaken for a defect.

## Compatibility and performance

WorldPane keeps compatible third-party pins above stitched art and yields window
ownership where another addon explicitly manages the frame. Art is loaded and
placed on demand. Debug and benchmark tools expose frame time, update cost,
memory growth, pin counts, and active art regions.

Public integrations use `WorldPaneAPI`. Inter-addon pin sharing uses the
`WorldPane` prefix. Both are versioned independently of display copy.
