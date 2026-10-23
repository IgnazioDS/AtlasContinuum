# WorldPane Retail architecture

## Rendering model

WorldPane augments Blizzard's `WorldMapFrame`. A stitched coordinate system
places supported Azeroth continents, zones, cities, exploration overlays, and
detail layers into one pannable canvas. Blizzard remains responsible for the
host frame, quest log, many pin providers, and native maps outside that shared
coordinate space.

The central rule is ownership by map depth: broad parchment and continent art
appear at low zoom; zone and city art become authoritative as the view closes
in. Overlap policies decide which current-Retail layer wins where old and new
map rectangles intersect.

## Navigation hierarchy

1. Azeroth uses the stitched canvas.
2. Wheel zoom and clicks descend into supported continent, zone, and city art.
3. Detached world spaces and maps without a valid Azeroth rectangle transition
   to Blizzard's native canvas.
4. Zooming or navigating outward from the fitted Azeroth view reaches the
   cosmic map, where Outland, Draenor, and other worlds remain selectable.
5. Back, right-click, Escape, breadcrumbs, and gamepad actions must preserve a
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
