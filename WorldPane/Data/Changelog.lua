-- WorldPane release notes shown by Map/News.lua.

local _, ns = ...

ns.MapChangelog = {
	{ version = "0.2.0-beta.1", date = "2026-10-24", heads = {
		[1] = "Visual system",
		[4] = "Map context",
	}, items = {
		"|cff6e2c0aA unified WorldPane identity|r now carries through map chrome, floating menus, tool windows, coordinate pills, and interactive tiles using a dedicated obsidian, parchment, bronze, and gold token system.",
		"Restrained depth, hairline borders, clearer type hierarchy, and consistent active and hover states replace the previous mixture of unrelated Blizzard surfaces.",
		"The shared presentation layer is independent of Blizzard's decorative window art, making it more stable across Retail interface changes.",

		"|cff6e2c0aA live context header|r identifies the current map, its parent hierarchy, and zoom depth without interrupting the canvas.",
		"Short map-title transitions clarify movement between worlds, continents, and zones; edge atmosphere and subtle parchment grain visually join map art from different eras.",
		"Context header, transitions, edge atmosphere, and parchment grain can each be disabled from the Look panel.",
	} },
	{ version = "0.1.1-beta.2", date = "2026-10-24", heads = {
		[1] = "Detached links",
	}, items = {
		"|cff6e2c0aVoidstorm and Harandar|r now use their actual Retail UiMapLink rectangles instead of child-zone rectangle inference.",
		"The complete painted medallions are clickable at every stitched zoom, with a WorldPane-owned centre target and a live-client API fallback.",
		"Clicks received by either the stitched canvas or Blizzard's native pins now share the same direct transition into each detailed regional map.",
	} },
	{ version = "0.1.1-beta.1", date = "2026-10-23", heads = {
		[1] = "Every world",
		[4] = "Detached zones",
	}, items = {
		"|cff6e2c0aRegional detail previews|r: Outland, Draenor, the Shadowlands, and other non-Azeroth continents now discover their zones from the live Retail client and blend detailed zone art into the native map while zooming.",
		"Regional maps gain deeper zoom levels without forcing unrelated world spaces into Azeroth's coordinate system.",
		"The renderer reuses art frames between regions and caps zone and texture work to keep transitions bounded.",

		"|cff6e2c0aVoidstorm and Harandar|r now resolve both detached hierarchy targets and Blizzard map-link pins before WorldPane's stitched click handling.",
		"Left- or right-clicking either detached destination opens its native map, then blends in its complete reveal art and deeper zoom levels; ordinary map links retain Blizzard's behavior.",
	} },
	{ version = "0.1.0-beta.1", date = "2026-10-23", heads = {
		[1] = "WorldPane",
		[4] = "Navigation",
		[7] = "Quests",
		[10] = "Continuity",
	}, items = {
		"|cff6e2c0aA new identity|r: WorldPane is now the product, addon folder, settings namespace, API, command family, message prefix, and release package.",
		"|cff6e2c0aEvery world. One map.|r The project has its own concise brand, documentation, release workflow, and support location.",
		"The bundled notices explain the legacy MIT foundation and the license boundary for original WorldPane work.",

		"|cff6e2c0aCosmic navigation|r: zoom out beyond Azeroth, or right-click its fitted view, to reach Blizzard's world-space map and select Outland, Draenor, and other worlds.",
		"Voidstorm and Harandar open their detailed native maps instead of being forced into invalid Azeroth stitch rectangles.",
		"Quel'Thalas overlap and Silvermoon close-up policies prevent legacy tiles and minimap bands from obscuring current Retail art.",

		"|cff6e2c0aCross-zone active quests|r: missing ongoing-quest positions appear across every visible zone while native Blizzard pins remain untouched.",
		"Watched, super-tracked, ready, failed, disabled, campaign, legendary, recurring, important, calling, and meta states retain distinct visual treatment.",
		"Objective progress, focused-quest filtering, richer tooltips, marker controls, and the optional super-tracked guide line are included.",

		"Existing settings from the previous package identity are adopted once through a small load-on-demand migration helper; current WorldPane settings always win.",
		"Use |cffffffff/worldpane|r or |cffffffff/wpmap|r for settings, and |cffffffff/wpaudit|r to inspect Retail map coverage.",
	} },
}
