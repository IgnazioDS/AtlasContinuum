local addon_file = assert(arg[1], "usage: lua quest_bridge_spec.lua path/to/QuestBridge.lua")

Enum = { QuestClassification = {
	Legendary = 1, Campaign = 2, Calling = 3, Recurring = 4, Important = 5, Meta = 6,
} }

local quests = {
	{ title = "A Real Quest", questID = 101 },
	{ title = "Native Quest", questID = 102 },
	{ title = "Header", questID = 0, isHeader = true },
	{ title = "World Task", questID = 103, isTask = true },
	{ title = "Hidden", questID = 104, isHidden = true },
	{ title = "No World Position", questID = 105 },
	{ title = "Ready Quest", questID = 106, questClassification = Enum.QuestClassification.Campaign },
	{ title = "Failed Quest", questID = 107 },
	{ title = "Disabled Quest", questID = 108 },
}

local waypoints = {
	[101] = { 10, 0.25, 0.75 },
	[102] = { 10, 0.50, 0.50 },
	[103] = { 10, 0.60, 0.60 },
	[104] = { 10, 0.70, 0.70 },
	[105] = { 99, 0.20, 0.20 },
	[106] = { 10, 0.30, 0.40 },
	[107] = { 10, 0.40, 0.30 },
	[108] = { 10, 0.45, 0.35 },
}

local objectives = {
	[101] = { { text = "Collect widgets: 4/10", finished = false, numFulfilled = 4, numRequired = 10 } },
	[106] = { { text = "Return to the keeper", finished = true, numFulfilled = 1, numRequired = 1 } },
	[107] = { { text = "Survive the trial", finished = false, numFulfilled = 0, numRequired = 1 } },
}

local added = {}
local guideLines = {}
local tracked = 101
local focusedQuest
local eventHandlers = {}
local focusCallbacks = {}
local tooltipLines = {}
local highlighted

local stitch = {
	Rect = function(mapID) return mapID == 10 and { 0, 1, 0, 1 } or nil end,
	IsBuilt = function() return true end,
	PinSet = function(key) return { key = key, pins = {}, lines = {} } end,
	ClearPinSet = function(set)
		set.pins = {}
		set.lines = {}
		if set.key == "retail_active_quests" then added = {} end
		if set.key == "retail_quest_guide" then guideLines = {} end
	end,
	AddPin = function(set, u, v, look, data)
		local function Texture()
			return {
				SetPoint = function() end,
				SetBlendMode = function() end,
				SetAtlas = function(self, atlas) self.atlas = atlas end,
				SetSize = function(self, width, height) self.width, self.height = width, height end,
				SetAlpha = function(self, alpha) self.alpha = alpha end,
				SetShown = function(self, shown) self.shown = shown end,
			}
		end
		local function FontString()
			return {
				SetPoint = function() end,
				SetTextColor = function() end,
				SetText = function(self, text) self.text = text end,
				SetAlpha = function(self, alpha) self.alpha = alpha end,
				SetShown = function(self, shown) self.shown = shown end,
			}
		end
		local pin = {
			u = u, v = v, look = look, data = data,
			Icon = { SetAlpha = function(self, alpha) self.alpha = alpha end },
			Highlight = { SetAlpha = function(self, alpha) self.alpha = alpha end },
			GetWidth = function() return look.size end,
			GetHeight = function() return look.size end,
			CreateTexture = function() return Texture() end,
			CreateFontString = function() return FontString() end,
			SetScript = function(self, script, fn) self[script] = fn end,
		}
		set.pins[#set.pins + 1] = pin
		added[#added + 1] = pin
		return pin
	end,
	AddLine = function(set, u1, v1, u2, v2, thickness, r, g, b, a, texture)
		local line = { u1 = u1, v1 = v1, u2 = u2, v2 = v2, thickness = thickness,
			r = r, g = g, b = b, a = a, texture = texture }
		set.lines[#set.lines + 1] = line
		guideLines[#guideLines + 1] = line
		return line
	end,
}

local worldmap = {
	ToWorld = function(_, x, y) return x + 0.1, y + 0.2 end,
	IsStitched = function() return true end,
	db = { questMarkerScale = 1, questMarkerOpacity = 1, questProgressLabels = true,
		questGuideLine = true, questOnlyTracked = false },
}

local ns = {
	MapStitch = stitch,
	Safe = {
		IsSecret = function() return false end,
		XY = function(position) return position.x, position.y end,
	},
	L = setmetatable({}, { __index = function(_, key) return key end }),
	GetModule = function(_, key) assert(key == "worldmap"); return worldmap end,
	RegisterEvent = function(owner, event, fn) eventHandlers[event] = { owner, fn }; return true end,
	Header = function(name, order) return { type = "header", name = name, order = order } end,
}

C_QuestLog = {
	GetNumQuestLogEntries = function() return #quests, #quests end,
	GetInfo = function(index) return quests[index] end,
	GetNextWaypoint = function(questID)
		local waypoint = waypoints[questID]
		if waypoint then return waypoint[1], waypoint[2], waypoint[3] end
	end,
	ReadyForTurnIn = function(questID) return questID == 106 end,
	IsComplete = function(questID) return questID == 106 end,
	IsFailed = function(questID) return questID == 107 end,
	IsQuestDisabledForSession = function(questID) return questID == 108 end,
	GetQuestWatchType = function(questID) return questID == 101 and 0 or nil end,
	GetNextWaypointText = function() return "Do the thing" end,
	GetQuestObjectives = function(questID) return objectives[questID] or {} end,
}

C_SuperTrack = {
	GetSuperTrackedQuestID = function() return tracked end,
	SetSuperTrackedQuestID = function(questID) tracked = questID end,
}

C_Map = {
	GetMapInfo = function() return { name = "Test Zone" } end,
	GetBestMapForUnit = function(unit) assert(unit == "player"); return 10 end,
	GetPlayerMapPosition = function(mapID, unit)
		assert(mapID == 10 and unit == "player")
		return { x = 0.1, y = 0.2 }
	end,
}
C_Timer = { After = function(_, fn) fn() end }
EventRegistry = { RegisterCallback = function() end }
GetCVarBool = function() return true end
GameTooltip_Hide = function() end
QUEST = "Quest"
QUEST_DASH = "- "
COMPLETE = "Complete"
FAILED = "Failed"
READY_FOR_TURN_IN = "Ready for turn-in"
TRACKED = "Tracked"

GameTooltip = {
	SetOwner = function() end,
	AddLine = function(_, text) tooltipLines[#tooltipLines + 1] = text end,
	Show = function() end,
}

POIButtonHighlightManager = {
	SetHighlight = function(_, questID) highlighted = questID end,
	ClearHighlight = function() highlighted = nil end,
}

local nativePin = { GetQuestID = function() return 102 end }
WorldMapFrame = {
	IsShown = function() return true end,
	RegisterCallback = function(_, name, fn, owner) focusCallbacks[name] = { fn, owner } end,
	EnumeratePinsByTemplate = function(_, template)
		assert(template == "QuestPinTemplate")
		local done = false
		return function()
			if not done then done = true; return nativePin end
		end
	end,
}
QuestMapFrame_GetFocusedQuestID = function() return focusedQuest end

local chunk = assert(loadfile(addon_file))
chunk("WorldPane", ns)

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
assert(#collected == 4, "expected the four missing normal quests")
assert(collected[1].questID == 101)
assert(collected[1].state == "progress" and collected[1].watched)
assert(bridge.ProgressText(collected[1]) == "4/10")
assert(collected[2].state == "ready")
assert(collected[2].classification == Enum.QuestClassification.Campaign)
assert(collected[3].state == "failed")
assert(collected[4].state == "disabled")

local watchedLook = bridge.LookFor(collected[1], false, 1)
assert(watchedLook.size == 27 and watchedLook.atlas == "Quest-In-Progress-Icon-yellow")
local trackedLook = bridge.LookFor(collected[1], true, 1)
assert(trackedLook.size == 31 and trackedLook.atlas == "Quest-In-Progress-Icon-Brown")
assert(bridge.LookFor(collected[2], false, 1).atlas == "UI-QuestPoiCampaign-QuestBangTurnIn")
assert(bridge.GlowAtlas(collected[2]) == "UI-QuestPoiCampaign-OuterGlow")
assert(bridge.LookFor(collected[3], false, 1).color[1] == 1)
assert(bridge.LookFor(collected[4], false, 1).atlas == "QuestSharing-QuestLog-Padlock")
assert(bridge.LookFor(collected[1], true, 0.5).size == 20, "scale should clamp to 65%")

bridge.Refresh()
assert(#added == 4 and added[1].data.questID == 101)
assert(#guideLines == 1)
assert(guideLines[1].u1 == 0.2 and guideLines[1].v1 == 0.4)
assert(guideLines[1].u2 == 0.35 and guideLines[1].v2 == 0.95)
assert(focusCallbacks.SetFocusedQuestID and focusCallbacks.ClearFocusedQuestID)
assert(added[1].QuestBridgeProgress.shown and added[1].QuestBridgeProgress.text == "4/10")
assert(added[2].QuestBridgeGlow.atlas == "UI-QuestPoiCampaign-OuterGlow")
assert(added[2].QuestBridgeGlow.shown == true)
assert(type(added[1].OnEnter) == "function")
assert(type(added[1].OnLeave) == "function")
assert(type(added[1].OnClick) == "function")
added[1]:OnEnter()
assert(highlighted == 101)
assert(table.concat(tooltipLines, "\n"):find("Collect widgets: 4/10", 1, true))
added[1]:OnLeave()
assert(highlighted == nil)

added[2]:OnClick()
assert(tracked == 106)

worldmap.db.questOnlyTracked = true
bridge.Refresh()
assert(#added == 2, "watched and super-tracked quests should remain")
assert(added[1].data.questID == 101 and added[2].data.questID == 106)

worldmap.db.questOnlyTracked = false
worldmap.db.questMarkerOpacity = 0.55
worldmap.db.questProgressLabels = false
focusedQuest = 106
bridge.Refresh()
assert(#added == 1 and added[1].data.questID == 106, "focused quest should hide other bridged pins")
assert(added[1].Icon.alpha == 0.55)
assert(added[1].QuestBridgeProgress.shown == false)

focusedQuest = nil
tracked = 102
bridge.RefreshGuide()
assert(#guideLines == 1 and guideLines[1].u2 == 0.6 and guideLines[1].v2 == 0.7,
	"guide should reach a native host-zone quest too")

worldmap.db.questGuideLine = false
bridge.RefreshGuide()
assert(#guideLines == 0, "guide setting should clear the line")
worldmap.db.questGuideLine = true

local options = {}
worldmap:QuestBridgeOptions(options, function() end, function() end, function() return false end)
assert(options.questMarkerScale.type == "range")
assert(options.questMarkerOpacity.type == "range")
assert(options.questProgressLabels.type == "toggle")
assert(options.questGuideLine.type == "toggle")
assert(options.questOnlyTracked.type == "toggle")

assert(eventHandlers.QUEST_LOG_UPDATE)
assert(eventHandlers.QUEST_POI_UPDATE)
assert(eventHandlers.QUEST_WATCH_UPDATE)
assert(eventHandlers.WAYPOINT_UPDATE)

print("quest_bridge_spec: ok")
