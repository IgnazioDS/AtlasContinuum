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
local GUIDE_SET = "retail_quest_guide"
local QUEST_TEMPLATE = "QuestPinTemplate"
local GUIDE_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local IN_PROGRESS = {
	atlas = "Quest-In-Progress-Icon-yellow",
	texture = "Interface\\GossipFrame\\ActiveQuestIcon",
	size = 24,
}
local WATCHED = {
	atlas = "Quest-In-Progress-Icon-yellow",
	texture = "Interface\\GossipFrame\\ActiveQuestIcon",
	size = 27,
}
local READY = {
	atlas = "UI-QuestPoi-QuestBangTurnIn",
	texture = "Interface\\GossipFrame\\ActiveQuestIcon",
	size = 27,
}
local SUPER_TRACKED = {
	atlas = "Quest-In-Progress-Icon-Brown",
	texture = "Interface\\GossipFrame\\ActiveQuestIcon",
	size = 31,
}
local FAILED = {
	atlas = "Quest-In-Progress-Icon-yellow",
	texture = "Interface\\GossipFrame\\ActiveQuestIcon",
	color = { 1, 0.3, 0.3, 1 },
	size = 26,
}
local DISABLED = {
	atlas = "QuestSharing-QuestLog-Padlock",
	texture = "Interface\\GossipFrame\\ActiveQuestIcon",
	size = 25,
}

local set
local guideSet
local guideTicker
local refreshQueued = false
local focusCallbacksRegistered = false

local READY_ATLAS = {}
local GLOW_ATLAS = {}
do
	local classifications = Enum and Enum.QuestClassification
	local function Add(name, readyAtlas, glowAtlas)
		local value = classifications and classifications[name]
		if value ~= nil then
			READY_ATLAS[value] = readyAtlas
			GLOW_ATLAS[value] = glowAtlas
		end
	end
	Add("Legendary", "UI-QuestPoiLegendary-QuestBangTurnIn", "UI-QuestPoiLegendary-OuterGlow")
	Add("Campaign", "UI-QuestPoiCampaign-QuestBangTurnIn", "UI-QuestPoiCampaign-OuterGlow")
	Add("Calling", "UI-DailyQuestPoiCampaign-QuestBangTurnIn", "UI-QuestPoiCampaign-OuterGlow")
	Add("Recurring", "UI-QuestPoiRecurring-QuestBangTurnIn", "UI-QuestPoiRecurring-OuterGlow")
	Add("Important", "UI-QuestPoiImportant-QuestBangTurnIn", "UI-QuestPoiImportant-OuterGlow")
	Add("Meta", "UI-QuestPoiWrapper-QuestBangTurnIn", "UI-QuestPoiWrapper-OuterGlow")
end

local function IsPlainNumber(value)
	return type(value) == "number" and not ns.Safe.IsSecret(value)
end

local function IsPlainString(value)
	return type(value) == "string" and not ns.Safe.IsSecret(value)
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

local function ReadBoolean(fn, questID)
	local value = SafeResult(fn, questID)
	return value ~= nil and not ns.Safe.IsSecret(value) and value and true or false
end

function Bridge.ReadObjectives(questID)
	local result = {}
	if not C_QuestLog or type(C_QuestLog.GetQuestObjectives) ~= "function" then return result end
	local objectives = SafeResult(C_QuestLog.GetQuestObjectives, questID)
	if type(objectives) ~= "table" or ns.Safe.IsSecret(objectives) then return result end

	for _, objective in ipairs(objectives) do
		if type(objective) == "table" and not ns.Safe.IsSecret(objective) and IsPlainString(objective.text)
			and objective.text ~= "" then
			local fulfilled = IsPlainNumber(objective.numFulfilled) and objective.numFulfilled or nil
			local required = IsPlainNumber(objective.numRequired) and objective.numRequired or nil
			result[#result + 1] = {
				text = objective.text,
				finished = not ns.Safe.IsSecret(objective.finished) and objective.finished and true or false,
				numFulfilled = fulfilled,
				numRequired = required,
			}
		end
	end
	return result
end

function Bridge.ReadState(questID)
	local objectives = Bridge.ReadObjectives(questID)
	local completeObjectives = 0
	for _, objective in ipairs(objectives) do
		if objective.finished then completeObjectives = completeObjectives + 1 end
	end

	local disabled = C_QuestLog and ReadBoolean(C_QuestLog.IsQuestDisabledForSession, questID) or false
	local failed = C_QuestLog and ReadBoolean(C_QuestLog.IsFailed, questID) or false
	local ready = C_QuestLog and ReadBoolean(C_QuestLog.ReadyForTurnIn, questID) or false
	local complete = C_QuestLog and ReadBoolean(C_QuestLog.IsComplete, questID) or false
	local watchType = C_QuestLog and SafeResult(C_QuestLog.GetQuestWatchType, questID) or nil
	if watchType ~= nil and ns.Safe.IsSecret(watchType) then watchType = nil end

	local state = "progress"
	if disabled then state = "disabled"
	elseif failed then state = "failed"
	elseif ready or complete then state = "ready" end

	return {
		state = state,
		disabled = disabled,
		failed = failed,
		ready = ready or complete,
		watched = watchType ~= nil,
		watchType = watchType,
		objectives = objectives,
		completeObjectives = completeObjectives,
		totalObjectives = #objectives,
	}
end

function Bridge.ProgressText(quest)
	local objectives = quest and quest.objectives
	if type(objectives) ~= "table" or #objectives == 0 then return end
	if #objectives == 1 then
		local objective = objectives[1]
		if IsPlainNumber(objective.numRequired) and objective.numRequired > 1
			and IsPlainNumber(objective.numFulfilled) then
			return ("%d/%d"):format(objective.numFulfilled, objective.numRequired)
		end
	end
	return ("%d/%d"):format(quest.completeObjectives or 0, quest.totalObjectives or #objectives)
end

local function ScaledLook(source, scale)
	local look = {}
	for key, value in pairs(source) do look[key] = value end
	look.size = math.floor((source.size or 24) * scale + 0.5)
	return look
end

function Bridge.LookFor(quest, superTracked, scale)
	scale = IsPlainNumber(scale) and math.max(0.65, math.min(1.75, scale)) or 1
	local look = IN_PROGRESS
	if superTracked then look = SUPER_TRACKED
	elseif quest.state == "disabled" then look = DISABLED
	elseif quest.state == "failed" then look = FAILED
	elseif quest.state == "ready" then look = READY
	elseif quest.watched then look = WATCHED end
	look = ScaledLook(look, scale)
	if quest.state == "ready" and not superTracked then
		look.atlas = READY_ATLAS[quest.classification] or look.atlas
	end
	return look
end

function Bridge.GlowAtlas(quest)
	return GLOW_ATLAS[quest and quest.classification] or "UI-QuestPoi-OuterGlow"
end

function Bridge.FocusedQuestID()
	local questID = SafeResult(_G.QuestMapFrame_GetFocusedQuestID)
	if IsPlainNumber(questID) and questID > 0 then return questID end
end

function Bridge.PlayerWorld()
	if not C_Map then return end
	local mapID = SafeResult(C_Map.GetBestMapForUnit, "player")
	if not IsPlainNumber(mapID) or not S.Rect(mapID) then return end
	local position = SafeResult(C_Map.GetPlayerMapPosition, mapID, "player")
	if not position then return end
	local x, y = ns.Safe.XY(position)
	if not IsPlainNumber(x) or not IsPlainNumber(y) or (x == 0 and y == 0) then return end
	local u, v = mod.ToWorld(mapID, x, y)
	if IsPlainNumber(u) and IsPlainNumber(v) then return u, v end
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
				local quest = {
					questID = info.questID,
					title = type(info.title) == "string" and info.title or (QUEST or "Quest"),
					mapID = mapID, x = x, y = y, u = u, v = v,
					classification = info.questClassification,
				}
				local state = Bridge.ReadState(info.questID)
				for key, value in pairs(state) do quest[key] = value end
				quests[#quests + 1] = quest
			end
		end
	end

	return quests
end

local function StateLine(quest)
	if quest.state == "disabled" then return QUEST_SESSION_ON_HOLD or "Quest temporarily disabled", 0.7, 0.7, 0.7 end
	if quest.state == "failed" then return _G.FAILED or "Failed", 1, 0.25, 0.25 end
	if quest.state == "ready" then return READY_FOR_TURN_IN or "Ready for turn-in", 0.2, 1, 0.2 end
	if quest.watched then return TRACKED or "Tracked", 0.35, 0.75, 1 end
end

local function PinEnter(pin)
	local quest = pin.data
	if not quest then return end
	GameTooltip:SetOwner(pin, "ANCHOR_CURSOR_RIGHT", 5, 2)
	GameTooltip:AddLine(quest.title, 1, 0.82, 0, true)
	if QuestUtils_AddQuestTypeToTooltip then
		pcall(QuestUtils_AddQuestTypeToTooltip, GameTooltip, quest.questID, NORMAL_FONT_COLOR)
	end
	if GameTooltip_CheckAddQuestTimeToTooltip then
		pcall(GameTooltip_CheckAddQuestTimeToTooltip, GameTooltip, quest.questID)
	end
	local status, sr, sg, sb = StateLine(quest)
	if status then GameTooltip:AddLine(status, sr, sg, sb, true) end

	local mapInfo = C_Map and C_Map.GetMapInfo and SafeResult(C_Map.GetMapInfo, quest.mapID)
	if mapInfo and type(mapInfo.name) == "string" then
		GameTooltip:AddLine(("%s  %.1f, %.1f"):format(mapInfo.name, quest.x * 100, quest.y * 100), 1, 1, 1)
	end

	local waypoint = C_QuestLog and SafeResult(C_QuestLog.GetNextWaypointText, quest.questID)
	if type(waypoint) == "string" and waypoint ~= "" then
		GameTooltip:AddLine((QUEST_DASH or "- ") .. waypoint, 0.9, 0.9, 0.9, true)
	end

	local shown = 0
	for _, objective in ipairs(quest.objectives or {}) do
		local text = (QUEST_DASH or "- ") .. objective.text
		if objective.finished then
			text = text .. " (" .. (COMPLETE or "Complete") .. ")"
			GameTooltip:AddLine(text, 0.35, 0.9, 0.35, true)
		else
			GameTooltip:AddLine(text, 0.9, 0.9, 0.9, true)
		end
		shown = shown + 1
		if shown >= 5 then break end
	end
	if quest.superTracked then
		GameTooltip:AddLine(ns.L["This quest is currently super-tracked"], 0.6, 0.8, 1, true)
	else
		GameTooltip:AddLine(ns.L["Click to super-track this quest"], 0.6, 0.8, 1, true)
	end
	GameTooltip:Show()
	if POIButtonHighlightManager and POIButtonHighlightManager.SetHighlight then
		pcall(POIButtonHighlightManager.SetHighlight, POIButtonHighlightManager, quest.questID)
	end
end

local function PinLeave()
	if POIButtonHighlightManager and POIButtonHighlightManager.ClearHighlight then
		pcall(POIButtonHighlightManager.ClearHighlight, POIButtonHighlightManager)
	end
	GameTooltip_Hide()
end

local function PinClick(pin)
	local quest = pin.data
	if quest and C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
		pcall(C_SuperTrack.SetSuperTrackedQuestID, quest.questID)
		Bridge.QueueRefresh()
	end
end

local function ConfigurePin(pin, quest, opacity, showProgress)
	opacity = IsPlainNumber(opacity) and math.max(0.3, math.min(1, opacity)) or 1
	if pin.SetFrameLevel and pin.GetFrameLevel then
		pin:SetFrameLevel(pin:GetFrameLevel() + (quest.superTracked and 2 or quest.ready and 1 or 0))
	end
	if pin.Icon and pin.Icon.SetAlpha then pin.Icon:SetAlpha(opacity) end
	if pin.Highlight and pin.Highlight.SetAlpha then
		pin.Highlight:SetAlpha((quest.superTracked and 0.65 or 0.3) * opacity)
	end

	if pin.CreateTexture then
		if not pin.QuestBridgeGlow then
			pin.QuestBridgeGlow = pin:CreateTexture(nil, "BACKGROUND")
			pin.QuestBridgeGlow:SetPoint("CENTER")
			pin.QuestBridgeGlow:SetBlendMode("ADD")
		end
		local glow = pin.QuestBridgeGlow
		local classified = GLOW_ATLAS[quest.classification] ~= nil
		if glow.SetAtlas then glow:SetAtlas(Bridge.GlowAtlas(quest)) end
		glow:SetSize(pin:GetWidth() * 1.55, pin:GetHeight() * 1.55)
		glow:SetAlpha((quest.superTracked and 0.9 or quest.watched and 0.5 or 0.38) * opacity)
		glow:SetShown(quest.superTracked or quest.watched or classified)
	end

	if pin.CreateFontString then
		if not pin.QuestBridgeProgress then
			pin.QuestBridgeProgress = pin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			pin.QuestBridgeProgress:SetPoint("TOP", pin, "BOTTOM", 0, -1)
			pin.QuestBridgeProgress:SetTextColor(1, 0.82, 0, 1)
		end
		local progress = Bridge.ProgressText(quest)
		pin.QuestBridgeProgress:SetText(progress or "")
		if pin.QuestBridgeProgress.SetAlpha then pin.QuestBridgeProgress:SetAlpha(opacity) end
		pin.QuestBridgeProgress:SetShown(showProgress and progress ~= nil and (quest.superTracked or quest.watched))
	end
end

function Bridge.RefreshGuide()
	if guideSet then S.ClearPinSet(guideSet) end
	local mapCanvas = _G.WorldMapFrame
	if not mapCanvas or not mapCanvas:IsShown() or not mod.IsStitched() or not S.IsBuilt() then return end
	if GetCVarBool and not GetCVarBool("questPOI") then return end
	if mod.db and mod.db.questGuideLine == false then return end

	local questID = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID
		and SafeResult(C_SuperTrack.GetSuperTrackedQuestID) or 0
	if not IsPlainNumber(questID) or questID <= 0 then return end
	local _, _, _, targetU, targetV = Bridge.ReadWaypoint(questID)
	if not targetU then return end
	local playerU, playerV = Bridge.PlayerWorld()
	if not playerU then return end

	guideSet = guideSet or S.PinSet(GUIDE_SET, 1, 4)
	S.AddLine(guideSet, playerU, playerV, targetU, targetV, 2.5, 1, 0.72, 0.18, 0.72, GUIDE_TEXTURE)
end

local function SetGuideTicker(shown)
	if not guideTicker and type(CreateFrame) == "function" then
		local ok, frame = pcall(CreateFrame, "Frame")
		if ok and frame and frame.SetScript then
			guideTicker = frame
			local elapsed = 0
			guideTicker:SetScript("OnUpdate", function(_, delta)
				elapsed = elapsed + delta
				if elapsed >= 0.25 then
					elapsed = 0
					Bridge.RefreshGuide()
				end
			end)
		end
	end
	if not guideTicker then return end
	if shown and guideTicker.Show then guideTicker:Show()
	elseif guideTicker.Hide then guideTicker:Hide() end
end

local function RegisterFocusCallbacks(mapCanvas)
	if focusCallbacksRegistered or not mapCanvas or type(mapCanvas.RegisterCallback) ~= "function" then return end
	local focused = pcall(mapCanvas.RegisterCallback, mapCanvas, "SetFocusedQuestID", Bridge.QueueRefresh, Bridge)
	local cleared = pcall(mapCanvas.RegisterCallback, mapCanvas, "ClearFocusedQuestID", Bridge.QueueRefresh, Bridge)
	focusCallbacksRegistered = focused or cleared
end

function Bridge.Refresh()
	refreshQueued = false
	if set then S.ClearPinSet(set) end
	Bridge.RefreshGuide()

	local mapCanvas = _G.WorldMapFrame
	if not mapCanvas or not mapCanvas:IsShown() or not mod.IsStitched() or not S.IsBuilt() then return end
	if GetCVarBool and not GetCVarBool("questPOI") then return end
	RegisterFocusCallbacks(mapCanvas)

	set = set or S.PinSet(QUEST_SET, 1, 5)
	local native = Bridge.NativeQuestIDs(mapCanvas)
	local superTracked = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID
		and SafeResult(C_SuperTrack.GetSuperTrackedQuestID) or 0
	local scale = mod.db and mod.db.questMarkerScale or 1
	local opacity = mod.db and mod.db.questMarkerOpacity or 1
	local showProgress = not mod.db or mod.db.questProgressLabels ~= false
	local onlyTracked = mod.db and mod.db.questOnlyTracked
	local focusedQuestID = Bridge.FocusedQuestID()

	for _, quest in ipairs(Bridge.Collect(native)) do
		quest.superTracked = quest.questID == superTracked
		if (not focusedQuestID or quest.questID == focusedQuestID)
			and (not onlyTracked or quest.superTracked or quest.watched) then
			local pin = S.AddPin(set, quest.u, quest.v, Bridge.LookFor(quest, quest.superTracked, scale), quest)
			ConfigurePin(pin, quest, opacity, showProgress)
			pin:SetScript("OnEnter", PinEnter)
			pin:SetScript("OnLeave", PinLeave)
			pin.OnClick = PinClick
		end
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
	"QUEST_ACCEPTED",
	"QUEST_REMOVED",
	"QUEST_TURNED_IN",
	"QUEST_LOG_UPDATE",
	"QUEST_LOG_CRITERIA_UPDATE",
	"QUEST_WATCH_LIST_CHANGED",
	"QUEST_WATCH_UPDATE",
	"QUEST_POI_UPDATE",
	"QUEST_DATA_LOAD_RESULT",
	"TASK_PROGRESS_UPDATE",
	"WAYPOINT_UPDATE",
}) do
	ns.RegisterEvent(Bridge, event, Bridge.QueueRefresh)
end

ns.RegisterEvent(Bridge, "CVAR_UPDATE", function(_, _, cvar)
	if cvar == "questPOI" then Bridge.QueueRefresh() end
end)

if EventRegistry and EventRegistry.RegisterCallback then
	EventRegistry:RegisterCallback("Supertracking.OnChanged", Bridge.QueueRefresh, Bridge)
end

function mod:QuestBridgeOptions(opts, get, setOption, off)
	opts.questBridgeHeader = ns.Header(ns.L["Active quests"], 34.2)
	opts.questMarkerScale = { type = "range", name = ns.L["Quest marker size"], order = 34.3,
		min = 0.65, max = 1.75, step = 0.05, isPercent = true, get = get,
		set = function(info, value) setOption(info, value); Bridge.QueueRefresh() end, disabled = off,
		desc = ns.L["The size of Atlas Continuum's bridged quest markers. Blizzard's native marker in the host zone keeps the game's size."] }
	opts.questMarkerOpacity = { type = "range", name = ns.L["Quest marker opacity"], order = 34.4,
		min = 0.3, max = 1, step = 0.05, isPercent = true, get = get,
		set = function(info, value) setOption(info, value); Bridge.QueueRefresh() end, disabled = off,
		desc = ns.L["The opacity of Atlas Continuum's bridged quest markers."] }
	opts.questProgressLabels = { type = "toggle", name = ns.L["Show quest progress labels"], order = 34.5,
		width = "full", get = get, set = function(info, value) setOption(info, value); Bridge.QueueRefresh() end, disabled = off,
		desc = ns.L["Show compact objective progress below tracked bridged quest markers."] }
	opts.questGuideLine = { type = "toggle", name = ns.L["Guide line to the super-tracked quest"], order = 34.6,
		width = "full", get = get, set = function(info, value) setOption(info, value); Bridge.QueueRefresh() end, disabled = off,
		desc = ns.L["Draw a live line from your position to the super-tracked quest when both positions are on the stitched world."] }
	opts.questOnlyTracked = { type = "toggle", name = ns.L["Only tracked quests outside the host zone"], order = 34.7,
		width = "full", get = get, set = function(info, value) setOption(info, value); Bridge.QueueRefresh() end, disabled = off,
		desc = ns.L["Hide untracked bridged quests. The super-tracked quest always remains visible."] }
end

local onHostMapChanged = mod.OnHostMapChanged
mod.OnHostMapChanged = function(...)
	if onHostMapChanged then onHostMapChanged(...) end
	Bridge.QueueRefresh()
end

local onMapShown = mod.OnMapShown
mod.OnMapShown = function(...)
	if onMapShown then onMapShown(...) end
	SetGuideTicker(true)
	Bridge.QueueRefresh()
end

local onMapHidden = mod.OnMapHidden
mod.OnMapHidden = function(...)
	if onMapHidden then onMapHidden(...) end
	SetGuideTicker(false)
	if set then S.ClearPinSet(set) end
	if guideSet then S.ClearPinSet(guideSet) end
end
