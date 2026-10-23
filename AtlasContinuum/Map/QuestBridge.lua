--------------------------------------------------------------------------------
-- Retail quest bridge: Blizzard's quest provider only creates active-quest pins
-- for WorldMapFrame's current uiMapID.  The stitched map can show many zones at
-- once, so the other visible zones otherwise have no quest positions.  Keep the
-- native pins where Blizzard already made one and add only the missing quests.
--------------------------------------------------------------------------------

local _, ns = ...
local S = ns.MapStitch
local mod = ns:GetModule("worldmap")

local Bridge = {}
ns.QuestBridge = Bridge

local QUEST_SET = "retail_active_quests"
local QUEST_TEMPLATE = "QuestPinTemplate"
local IN_PROGRESS = {
	atlas = "Quest-In-Progress-Icon-yellow",
	texture = "Interface\\GossipFrame\\ActiveQuestIcon",
	size = 24,
}
local READY = {
	atlas = "UI-QuestPoi-QuestBangTurnIn",
	texture = "Interface\\GossipFrame\\ActiveQuestIcon",
	size = 27,
}
local SUPER_TRACKED = {
	atlas = "Quest-In-Progress-Icon-yellow",
	texture = "Interface\\GossipFrame\\ActiveQuestIcon",
	size = 29,
}

local set
local refreshQueued = false

local function IsPlainNumber(value)
	return type(value) == "number" and not ns.Safe.IsSecret(value)
end

local function SafeResult(fn, ...)
	if type(fn) ~= "function" then return end
	local ok, a, b, c = pcall(fn, ...)
	if ok then return a, b, c end
end

function Bridge.ShouldInclude(info)
	return type(info) == "table"
		and not info.isHeader
		and not info.isHidden
		and not info.isInternalOnly
		and not info.isTask
		and not info.isBounty
		and IsPlainNumber(info.questID)
		and info.questID > 0
end

function Bridge.ReadWaypoint(questID)
	if not C_QuestLog or not IsPlainNumber(questID) then return end
	local mapID, x, y = SafeResult(C_QuestLog.GetNextWaypoint, questID)
	if not IsPlainNumber(mapID) or not IsPlainNumber(x) or not IsPlainNumber(y) then return end
	if x < 0 or x > 1 or y < 0 or y > 1 or not S.Rect(mapID) then return end
	local u, v = mod.ToWorld(mapID, x, y)
	if not IsPlainNumber(u) or not IsPlainNumber(v) then return end
	return mapID, x, y, u, v
end

-- questID -> true for Blizzard pins which are already present on the host map.
function Bridge.NativeQuestIDs(mapCanvas)
	local found = {}
	if not mapCanvas or type(mapCanvas.EnumeratePinsByTemplate) ~= "function" then return found end
	pcall(function()
		for pin in mapCanvas:EnumeratePinsByTemplate(QUEST_TEMPLATE) do
			local questID = pin.GetQuestID and pin:GetQuestID()
			if IsPlainNumber(questID) then found[questID] = true end
		end
	end)
	return found
end

-- Kept public for the Lua behavior test and future diagnostics.
function Bridge.Collect(native)
	local quests, seen = {}, {}
	if not C_QuestLog then return quests end
	local count = SafeResult(C_QuestLog.GetNumQuestLogEntries)
	if not IsPlainNumber(count) then return quests end

	for index = 1, count do
		local info = SafeResult(C_QuestLog.GetInfo, index)
		if Bridge.ShouldInclude(info) and not seen[info.questID] and not (native and native[info.questID]) then
			seen[info.questID] = true
			local mapID, x, y, u, v = Bridge.ReadWaypoint(info.questID)
			if mapID then
				quests[#quests + 1] = {
					questID = info.questID,
					title = type(info.title) == "string" and info.title or (QUEST or "Quest"),
					mapID = mapID, x = x, y = y, u = u, v = v,
				}
			end
		end
	end

	return quests
end

local function IsReady(questID)
	if not C_QuestLog then return false end
	local ready = SafeResult(C_QuestLog.ReadyForTurnIn, questID)
	if ready ~= nil then return ready and true or false end
	return SafeResult(C_QuestLog.IsComplete, questID) and true or false
end

local function PinEnter(pin)
	local quest = pin.data
	if not quest then return end
	GameTooltip:SetOwner(pin, "ANCHOR_CURSOR_RIGHT", 5, 2)
	GameTooltip:AddLine(quest.title, 1, 0.82, 0, true)

	local mapInfo = C_Map and C_Map.GetMapInfo and SafeResult(C_Map.GetMapInfo, quest.mapID)
	if mapInfo and type(mapInfo.name) == "string" then
		GameTooltip:AddLine(("%s  %.1f, %.1f"):format(mapInfo.name, quest.x * 100, quest.y * 100), 1, 1, 1)
	end

	local waypoint = C_QuestLog and SafeResult(C_QuestLog.GetNextWaypointText, quest.questID)
	if type(waypoint) == "string" and waypoint ~= "" then
		GameTooltip:AddLine(waypoint, 0.9, 0.9, 0.9, true)
	else
		local objectives = C_QuestLog and SafeResult(C_QuestLog.GetQuestObjectives, quest.questID)
		if type(objectives) == "table" then
			local shown = 0
			for _, objective in ipairs(objectives) do
				if not objective.finished and type(objective.text) == "string" and objective.text ~= "" then
					GameTooltip:AddLine(objective.text, 0.9, 0.9, 0.9, true)
					shown = shown + 1
					if shown >= 4 then break end
				end
			end
		end
	end
	GameTooltip:AddLine(ns.L["Click to track this quest"], 0.6, 0.8, 1, true)
	GameTooltip:Show()
end

local function PinClick(pin)
	local quest = pin.data
	if quest and C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
		pcall(C_SuperTrack.SetSuperTrackedQuestID, quest.questID)
		Bridge.QueueRefresh()
	end
end

function Bridge.Refresh()
	refreshQueued = false
	if set then S.ClearPinSet(set) end

	local mapCanvas = _G.WorldMapFrame
	if not mapCanvas or not mapCanvas:IsShown() or not mod.IsStitched() or not S.IsBuilt() then return end
	if GetCVarBool and not GetCVarBool("questPOI") then return end

	set = set or S.PinSet(QUEST_SET, 1, 5)
	local native = Bridge.NativeQuestIDs(mapCanvas)
	local superTracked = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID
		and SafeResult(C_SuperTrack.GetSuperTrackedQuestID) or 0

	for _, quest in ipairs(Bridge.Collect(native)) do
		local look = quest.questID == superTracked and SUPER_TRACKED or (IsReady(quest.questID) and READY or IN_PROGRESS)
		local pin = S.AddPin(set, quest.u, quest.v, look, quest)
		pin:SetScript("OnEnter", PinEnter)
		pin:SetScript("OnLeave", GameTooltip_Hide)
		pin.OnClick = PinClick
	end
end

function Bridge.QueueRefresh()
	if refreshQueued then return end
	refreshQueued = true
	if C_Timer and C_Timer.After then
		C_Timer.After(0, Bridge.Refresh)
	else
		Bridge.Refresh()
	end
end

for _, event in ipairs({
	"PLAYER_ENTERING_WORLD",
	"QUEST_LOG_UPDATE",
	"QUEST_WATCH_LIST_CHANGED",
	"QUEST_POI_UPDATE",
	"QUEST_DATA_LOAD_RESULT",
}) do
	ns.RegisterEvent(Bridge, event, Bridge.QueueRefresh)
end

ns.RegisterEvent(Bridge, "CVAR_UPDATE", function(_, _, cvar)
	if cvar == "questPOI" then Bridge.QueueRefresh() end
end)

if EventRegistry and EventRegistry.RegisterCallback then
	EventRegistry:RegisterCallback("Supertracking.OnChanged", Bridge.QueueRefresh, Bridge)
end

local onHostMapChanged = mod.OnHostMapChanged
mod.OnHostMapChanged = function(...)
	if onHostMapChanged then onHostMapChanged(...) end
	Bridge.QueueRefresh()
end

local onMapShown = mod.OnMapShown
mod.OnMapShown = function(...)
	if onMapShown then onMapShown(...) end
	Bridge.QueueRefresh()
end

local onMapHidden = mod.OnMapHidden
mod.OnMapHidden = function(...)
	if onMapHidden then onMapHidden(...) end
	if set then S.ClearPinSet(set) end
end
