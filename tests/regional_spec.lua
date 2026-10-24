local regionalPath = assert(arg[1], "path to Regional.lua is required")

Enum = { UIMapType = { Continent = 2, Zone = 3 } }

local positions = {
	[947] = { mapID = 2537, mapType = Enum.UIMapType.Continent },
	[2537] = { mapID = 2405, mapType = Enum.UIMapType.Zone },
}

local children = {
	[101] = {
		{ mapID = 201, name = "Large" },
		{ mapID = 202, name = "Detached" },
		{ mapID = 203, name = "Small" },
	},
}

C_Map = {
	GetMapInfo = function(mapID)
		if mapID == 2405 then return { mapID = mapID, name = "Voidstorm", mapType = Enum.UIMapType.Zone, parentMapID = 2537 } end
		if mapID == 2413 then return { mapID = mapID, name = "Harandar", mapType = Enum.UIMapType.Zone, parentMapID = 2537 } end
	end,
	GetMapInfoAtPosition = function(mapID)
		return positions[mapID]
	end,
	GetMapRectOnMap = function(mapID, rootMapID)
		if mapID == 2537 and rootMapID == 947 then return 0.75, 1, 0, 0.5 end
		if mapID == 2405 and rootMapID == 2537 then return nil end
		if mapID == 201 and rootMapID == 101 then return 0, 0.8, 0, 0.8 end
		if mapID == 203 and rootMapID == 101 then return 0.8, 1, 0.8, 1 end
	end,
	GetMapChildrenInfo = function(mapID, mapType, recursive)
		assert(mapType == Enum.UIMapType.Zone)
		assert(recursive == false)
		return children[mapID] or {}
	end,
	GetMapLinksForMap = function(mapID)
		if mapID ~= 2537 then return {} end
		return {
			{ linkedUiMapID = 2405, name = "Voidstorm", atlasName = "voidstorm",
				position = { GetXY = function() return 0.54, 0.23 end } },
		}
	end,
}

local module = { enabled = true }
local ns = {
	MapStitch = { WORLD = 947 },
	ClientMaps = { awayMaps = { [2405] = true, [2413] = true } },
	GetModule = function(_, name)
		assert(name == "worldmap")
		return module
	end,
}

assert(loadfile(regionalPath))("WorldPane", ns)
local regions = assert(ns.MapRegions)

local detached = regions.DetachedAt(947, 0.9, 0.25, { [2405] = true, [2413] = true })
assert(detached == 2405, "nested detached map must be resolved before its missing rectangle is rejected")
assert(regions.DetachedAt(947, 0.9, 0.25, { [2413] = true }) == nil,
	"an unlisted detached map must not be opened as a native policy target")
local linkPin = { GetLinkedUIMapID = function() return 2413 end }
assert(regions.LinkedAwayMap(linkPin, { [2413] = true }) == 2413,
	"a detached MapLink pin must resolve its linked native map")
assert(regions.LinkedAwayMap(linkPin, { [2405] = true }) == nil,
	"an ordinary or unlisted MapLink pin must retain Blizzard's behavior")

local configuredLinks = {
	[2537] = {
		{ mapID = 2405, minX = 0.435, minY = 0.065, maxX = 0.630, maxY = 0.400 },
		{ mapID = 2413, minX = 0.730, minY = 0.035, maxX = 0.905, maxY = 0.300 },
	},
}
local links = regions.AwayLinks({ [2405] = true, [2413] = true }, configuredLinks, function(mapID)
	if mapID == 2537 then return 0.75, 1, 0, 0.5 end
end)
assert(#links == 2, "runtime and fallback UiMapLink records must produce both detached destinations")
assert(links[1].mapID == 2405 and math.abs(links[1].u - 0.883125) < 0.00001,
	"the configured MapLink centre must be translated into stitched-world coordinates")
assert(links[2].mapID == 2413 and links[2].u0 and links[2].v1,
	"a destination absent from the runtime list must retain its configured full link rectangle")
assert(regions.AwayLinkAt(links[1].u0 + 0.001, links[1].v0 + 0.001, nil, nil, links) == 2405,
	"clicking anywhere in Voidstorm's painted medallion must open Voidstorm")
assert(regions.AwayLinkAt(links[2].u, links[2].v, 0.001, 0.001, links) == 2413,
	"the centre hit fallback must open Harandar")

local zones = regions.ZoneRects(101)
assert(#zones == 2, "regional discovery must ignore child maps without a root rectangle")
assert(zones[1].mapID == 201 and zones[2].mapID == 203, "regional zones must paint largest first")
local detachedPreview = regions.PreviewRects(2413)
assert(#detachedPreview == 1 and detachedPreview[1].mapID == 2413 and detachedPreview[1].l == 0 and detachedPreview[1].r == 1,
	"a detached zone must preview its own complete native canvas")

print("OK: detached map targeting and regional zone discovery")
