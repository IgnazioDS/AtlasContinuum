local auditPath = assert(arg[1], "path to Audit.lua is required")

Enum = { UIMapType = { Zone = 3 } }
SlashCmdList = {}
date = os.date
strtrim = function(value)
	return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local maps = {
	{ mapID = 101, name = "Ready Zone" },
	{ mapID = 102, name = "Artless City" },
	{ mapID = 103, name = "Detached Zone" },
	{ mapID = 104, name = "New Patch Zone" },
}

C_Map = {
	GetMapChildrenInfo = function(worldMapID, mapType, recursive)
		assert(worldMapID == 947)
		assert(mapType == Enum.UIMapType.Zone)
		assert(recursive == true)
		return maps
	end,
	GetMapRectOnMap = function(mapID, worldMapID)
		assert(worldMapID == 947)
		if mapID == 103 or mapID == 104 then return nil end
		return 0.1, 0.2, 0.3, 0.4
	end,
	GetMapArtLayers = function(mapID)
		if mapID == 102 then return {} end
		return { { layerWidth = 1002, layerHeight = 668 } }
	end,
}

GetBuildInfo = function()
	return "12.1.5", "70448", "Oct 21 2026", 120105
end

local messages = {}
local ns = {
	MapWorld = { zones = { [101] = 1, [102] = 2 } },
	ClientMaps = { awayMaps = { [103] = true } },
	Print = function(_, formatString, ...)
		messages[#messages + 1] = formatString:format(...)
	end,
}

assert(loadfile(auditPath))("WorldPane", ns)

assert(type(WorldPaneLab) == "table")
local result = WorldPaneLab.RunAudit()

assert(result.total == 4, "expected four discovered maps")
assert(result.covered == 2, "expected one stitched and one native map")
assert(#result.missingData == 1 and result.missingData[1].mapID == 104)
assert(#result.missingArt == 1 and result.missingArt[1].mapID == 102)
assert(#result.missingRect == 1 and result.missingRect[1].mapID == 104)
assert(#result.nativeFallback == 1 and result.nativeFallback[1].mapID == 103)
assert(WorldPaneLabDB.lastAudit == result, "audit result was not persisted")

SlashCmdList.WORLDPANEAUDIT("missing")
assert(#messages >= 5, "slash command did not print summary and missing rows")

print("OK: RetailLab/Audit.lua behavior")
