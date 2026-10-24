--------------------------------------------------------------------------------
-- WorldPane: live Retail coverage audit.
--
-- The stitched map's generated tables describe a specific Retail build. This
-- module compares those tables with the maps exposed by the running client so
-- patch drift is visible immediately. It never mutates generated map data.
--
-- Commands:
--   /wpaudit          run the audit and print a concise report
--   /wpaudit missing  print missing map IDs (up to 40 lines)
--------------------------------------------------------------------------------

local ADDON, ns = ...

local WORLD_MAP_ID = 947
local MAX_CHAT_ROWS = 40

local Lab = {
	version = "0.3.0",
	upstreamVersion = "0.7.1-beta-retail",
}
_G.WorldPaneLab = Lab

local function SafeCall(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d = pcall(fn, ...)
	if not ok then return nil end
	return a, b, c, d
end

local function HasUsableRect(mapID)
	local left, right, top, bottom = SafeCall(C_Map.GetMapRectOnMap, mapID, WORLD_MAP_ID)
	return left ~= nil and right ~= nil and top ~= nil and bottom ~= nil and right > left and bottom > top
end

local function HasArt(mapID)
	local layers = SafeCall(C_Map.GetMapArtLayers, mapID)
	return type(layers) == "table" and layers[1] ~= nil
end

local function SortMaps(a, b)
	if a.name == b.name then return a.mapID < b.mapID end
	return a.name < b.name
end

local function AddIssue(result, bucket, info, reason)
	result[bucket][#result[bucket] + 1] = {
		mapID = info.mapID,
		name = info.name or ("Map " .. tostring(info.mapID)),
		reason = reason,
	}
end

function Lab.RunAudit()
	local gameVersion, build, buildDate, interfaceVersion = GetBuildInfo()
	local result = {
		timestamp = date("!%Y-%m-%dT%H:%M:%SZ"),
		gameVersion = gameVersion,
		build = build,
		buildDate = buildDate,
		interfaceVersion = interfaceVersion,
		worldMapID = WORLD_MAP_ID,
		total = 0,
		covered = 0,
		missingData = {},
		missingArt = {},
		missingRect = {},
		nativeFallback = {},
	}

	local mapWorld = ns.MapWorld or {}
	local known = mapWorld.zones or {}
	local away = ns.ClientMaps and ns.ClientMaps.awayMaps or {}
	local children = SafeCall(C_Map.GetMapChildrenInfo, WORLD_MAP_ID, Enum.UIMapType.Zone, true) or {}

	for _, info in ipairs(children) do
		if type(info) == "table" and type(info.mapID) == "number" then
			result.total = result.total + 1
			local native = away[info.mapID] == true
			local listed = known[info.mapID] ~= nil
			local art = HasArt(info.mapID)
			local rect = HasUsableRect(info.mapID)

			if native then
				AddIssue(result, "nativeFallback", info, "opens Blizzard's native map")
			elseif not listed then
				AddIssue(result, "missingData", info, "not listed in Data/Retail/World.lua")
			end
			if not art then AddIssue(result, "missingArt", info, "C_Map.GetMapArtLayers returned no art") end
			if not native and not rect then AddIssue(result, "missingRect", info, "no usable rectangle on uiMapID 947") end
			if art and (native or (listed and rect)) then result.covered = result.covered + 1 end
		end
	end

	for _, bucket in ipairs({ "missingData", "missingArt", "missingRect", "nativeFallback" }) do
		table.sort(result[bucket], SortMaps)
	end

	WorldPaneLabDB = WorldPaneLabDB or {}
	WorldPaneLabDB.lastAudit = result
	Lab.lastAudit = result
	return result
end

local function PrintSummary(result)
	local missing = #result.missingData
	local noArt = #result.missingArt
	local noRect = #result.missingRect
	local native = #result.nativeFallback
	ns:Print(
		"Retail audit: |cffffffff%d/%d|r zone/city maps ready on %s (build %s, interface %s).",
		result.covered,
		result.total,
		tostring(result.gameVersion or "unknown"),
		tostring(result.build or "unknown"),
		tostring(result.interfaceVersion or "unknown")
	)
	ns:Print(
		"Drift: |cffffffff%d|r missing from generated data, |cffffffff%d|r without art, |cffffffff%d|r without a world rectangle; |cffffffff%d|r intentional native transitions.",
		missing,
		noArt,
		noRect,
		native
	)
	if missing + noArt + noRect > 0 then
		ns:Print("Use |cffffffff/wpaudit missing|r for IDs; the complete table is WorldPaneLabDB.lastAudit.")
	end
end

local function PrintMissing(result)
	local printed = 0
	for _, spec in ipairs({
		{ key = "missingData", label = "DATA" },
		{ key = "missingArt", label = "ART" },
		{ key = "missingRect", label = "RECT" },
	}) do
		for _, item in ipairs(result[spec.key]) do
			if printed >= MAX_CHAT_ROWS then
				ns:Print("More results omitted; inspect WorldPaneLabDB.lastAudit with /dump or DevTools.")
				return
			end
			ns:Print("[%s] %d - %s", spec.label, item.mapID, item.name)
			printed = printed + 1
		end
	end
	if printed == 0 then ns:Print("No missing zone/city maps detected.") end
end

SLASH_WORLDPANEAUDIT1 = "/wpaudit"
SlashCmdList.WORLDPANEAUDIT = function(message)
	local result = Lab.RunAudit()
	PrintSummary(result)
	if strtrim(message or ""):lower() == "missing" then PrintMissing(result) end
end

Lab.PrintSummary = PrintSummary
