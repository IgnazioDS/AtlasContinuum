local addon_file = assert(arg[1], "usage: lua quest_bridge_spec.lua path/to/QuestBridge.lua")

local quests = {
	{ title = "A Real Quest", questID = 101 },
	{ title = "Native Quest", questID = 102 },
	{ title = "Header", questID = 0, isHeader = true },
	{ title = "World Task", questID = 103, isTask = true },
	{ title = "Hidden", questID = 104, isHidden = true },
	{ title = "No World Position", questID = 105 },
}

local waypoints = {
	[101] = { 10, 0.25, 0.75 },
	[102] = { 10, 0.50, 0.50 },
	[103] = { 10, 0.60, 0.60 },
	[104] = { 10, 0.70, 0.70 },
	[105] = { 99, 0.20, 0.20 },
}

local added = {}
local tracked
local eventHandlers = {}

local stitch = {
	Rect = function(mapID) return mapID == 10 and { 0, 1, 0, 1 } or nil end,
	IsBuilt = function() return true end,
	PinSet = function() return { pins = {} } end,
	ClearPinSet = function(set) set.pins = {}; added = {} end,
	AddPin = function(set, u, v, look, data)
		local pin = {
			u = u, v = v, look = look, data = data,
			SetScript = function(self, script, fn) self[script] = fn end,
		}
		set.pins[#set.pins + 1] = pin
		added[#added + 1] = pin
		return pin
	end,
}

local worldmap = {
	ToWorld = function(_, x, y) return x + 0.1, y + 0.2 end,
	IsStitched = function() return true end,
}

local ns = {
	MapStitch = stitch,
	Safe = { IsSecret = function() return false end },
	L = setmetatable({}, { __index = function(_, key) return key end }),
	GetModule = function(_, key) assert(key == "worldmap"); return worldmap end,
	RegisterEvent = function(owner, event, fn) eventHandlers[event] = { owner, fn }; return true end,
}

C_QuestLog = {
	GetNumQuestLogEntries = function() return #quests, #quests end,
	GetInfo = function(index) return quests[index] end,
	GetNextWaypoint = function(questID)
		local waypoint = waypoints[questID]
		if waypoint then return waypoint[1], waypoint[2], waypoint[3] end
	end,
	ReadyForTurnIn = function() return false end,
	GetNextWaypointText = function() return "Do the thing" end,
	GetQuestObjectives = function() return {} end,
}

C_SuperTrack = {
	GetSuperTrackedQuestID = function() return 0 end,
	SetSuperTrackedQuestID = function(questID) tracked = questID end,
}

C_Map = { GetMapInfo = function() return { name = "Test Zone" } end }
C_Timer = { After = function(_, fn) fn() end }
EventRegistry = { RegisterCallback = function() end }
GetCVarBool = function() return true end
GameTooltip_Hide = function() end
QUEST = "Quest"

GameTooltip = {
	SetOwner = function() end,
	AddLine = function() end,
	Show = function() end,
}

local nativePin = { GetQuestID = function() return 102 end }
WorldMapFrame = {
	IsShown = function() return true end,
	EnumeratePinsByTemplate = function(_, template)
		assert(template == "QuestPinTemplate")
		local done = false
		return function()
			if not done then done = true; return nativePin end
		end
	end,
}

local chunk = assert(loadfile(addon_file))
chunk("AtlasContinuum", ns)

local bridge = assert(ns.QuestBridge)
assert(bridge.ShouldInclude(quests[1]))
assert(not bridge.ShouldInclude(quests[3]))
assert(not bridge.ShouldInclude(quests[4]))
assert(not bridge.ShouldInclude(quests[5]))

local mapID, x, y, u, v = bridge.ReadWaypoint(101)
assert(mapID == 10 and x == 0.25 and y == 0.75)
assert(u == 0.35 and v == 0.95)
assert(bridge.ReadWaypoint(105) == nil)

local native = bridge.NativeQuestIDs(WorldMapFrame)
assert(native[102] == true)
local collected = bridge.Collect(native)
assert(#collected == 1, "expected only the missing normal quest")
assert(collected[1].questID == 101)

bridge.Refresh()
assert(#added == 1 and added[1].data.questID == 101)
assert(type(added[1].OnEnter) == "function")
assert(type(added[1].OnLeave) == "function")
assert(type(added[1].OnClick) == "function")
added[1]:OnClick()
assert(tracked == 101)

assert(eventHandlers.QUEST_LOG_UPDATE)
assert(eventHandlers.QUEST_POI_UPDATE)

print("quest_bridge_spec: ok")
