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
		if mapID == 2413 then return { mapID = mapID, name = "Harandar", mapType = Enum.UIMapType.Zone } end
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

local zones = regions.ZoneRects(101)
assert(#zones == 2, "regional discovery must ignore child maps without a root rectangle")
assert(zones[1].mapID == 201 and zones[2].mapID == 203, "regional zones must paint largest first")
local detachedPreview = regions.PreviewRects(2413)
assert(#detachedPreview == 1 and detachedPreview[1].mapID == 2413 and detachedPreview[1].l == 0 and detachedPreview[1].r == 1,
	"a detached zone must preview its own complete native canvas")

print("OK: detached map targeting and regional zone discovery")
