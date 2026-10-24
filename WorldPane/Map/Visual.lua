--------------------------------------------------------------------------------
-- WorldPane presentation layer
--
-- A responsive, non-interactive HUD over Blizzard's canvas: map context,
-- hierarchy, depth feedback, edge atmosphere and restrained transitions. It
-- owns no map data or navigation, so presentation can fail or be disabled
-- without changing the underlying map.
--------------------------------------------------------------------------------

local _, ns = ...
local mod = ns:GetModule("worldmap")
local Theme = ns.Theme

local Visual = {}
ns.MapVisual = Visual

local d = mod.defaults
d.visualHeader = true
d.visualVignette = true
d.visualGrain = true
d.visualTransitions = true
d.visualIntensity = 0.85

local function Clamp(value, low, high)
	return math.max(low, math.min(high, value))
end

local function SmoothStep(value)
	local t = Clamp(value, 0, 1)
	return t * t * (3 - 2 * t)
end

local function EaseOutCubic(value)
	local t = 1 - Clamp(value, 0, 1)
	return 1 - t * t * t
end

local MAP_KINDS = {
	[0] = "COSMIC", [1] = "WORLD", [2] = "CONTINENT", [3] = "ZONE",
	[4] = "DUNGEON", [5] = "MICRO MAP", [6] = "REGION",
}
if Enum and Enum.UIMapType then
	for key, label in pairs({ Cosmic = "COSMIC", World = "WORLD", Continent = "CONTINENT", Zone = "ZONE",
		Dungeon = "DUNGEON", Micro = "MICRO MAP", Orphan = "REGION" }) do
		local value = Enum.UIMapType[key]
		if value ~= nil then MAP_KINDS[value] = label end
	end
end

function Visual.MapKind(info)
	return info and MAP_KINDS[info.mapType] or "MAP"
end

function Visual.Breadcrumb(mapID, maxDepth)
	local chain, seen = {}, {}
	local current = mapID
	for _ = 1, maxDepth or 7 do
		if not current or current == 0 or seen[current] then break end
		seen[current] = true
		local ok, info = pcall(C_Map.GetMapInfo, current)
		if not ok or not info then break end
		chain[#chain + 1] = {
			mapID = current,
			name = info.name or tostring(current),
			mapType = info.mapType,
			parentMapID = info.parentMapID,
		}
		current = info.parentMapID
	end
	local ordered = {}
	for i = #chain, 1, -1 do ordered[#ordered + 1] = chain[i] end
	local title = chain[1] and chain[1].name or (WORLD_MAP or "World Map")
	local parents = {}
	for i = 1, math.max(0, #ordered - 1) do parents[#parents + 1] = ordered[i].name end
	return title, #parents > 0 and table.concat(parents, "  ›  ") or (WORLD_MAP or "World Map"), ordered
end

function Visual.CompactPath(ordered, maxParents)
	local last = math.max(0, #(ordered or {}) - 1)
	if last == 0 then return WORLD_MAP or "World Map" end
	maxParents = math.max(1, maxParents or 3)
	local first = math.max(1, last - maxParents + 1)
	local names = {}
	if first > 1 then names[#names + 1] = "…" end
	for i = first, last do names[#names + 1] = ordered[i].name end
	return table.concat(names, "  ›  ")
end

function Visual.ZoomProgress(zoom)
	zoom = math.max(1, tonumber(zoom) or 1)
	return Clamp(math.log(zoom) / math.log(64), 0, 1)
end

-- The stitched canvas quietly changes its host map as the view crosses zones.
-- That is an implementation detail, not a new destination: the persistent
-- header may update, but a large location announcement would interrupt normal
-- browsing. Reserve announcements for explicit native hierarchy changes.
function Visual.ShouldAnnounce(previous, current, stitched)
	if not previous or not current or previous.mapID == current.mapID then return false end
	if stitched then return false end
	local continent = Enum and Enum.UIMapType and Enum.UIMapType.Continent or 2
	return (current.mapType or 99) <= continent or (previous.mapType or 99) <= continent
end

function Visual.HeaderLayout(canvasWidth)
	local width = math.max(360, tonumber(canvasWidth) or 900)
	if width < 680 then
		return { mode = "compact", width = math.max(280, width - 84), height = 42, pathDepth = 1,
			icon = 26, zoomWidth = 54, trackWidth = 42 }
	elseif width < 1050 then
		return { mode = "standard", width = math.min(780, width - 96), height = 54, pathDepth = 2,
			icon = 32, zoomWidth = 64, trackWidth = 52 }
	end
	return { mode = "wide", width = math.min(800, width - 112), height = 56, pathDepth = 3,
		icon = 34, zoomWidth = 68, trackWidth = 56 }
end

-- A short entrance, a readable hold and a soft exit. Returning scale with alpha
-- keeps the motion spatially legible without sliding the map or delaying input.
function Visual.TransitionState(elapsed, duration)
	duration = math.max(0.01, duration or 0.72)
	local t = Clamp(elapsed or 0, 0, duration)
	local enter = duration * 0.20
	local holdEnd = duration * 0.48
	local alpha, scale
	if t < enter then
		local p = SmoothStep(t / enter)
		alpha, scale = p, 0.965 + 0.035 * EaseOutCubic(p)
	elseif t < holdEnd then
		alpha, scale = 1, 1
	else
		local p = SmoothStep((t - holdEnd) / (duration - holdEnd))
		alpha, scale = 1 - p, 1 + 0.012 * p
	end
	return alpha, scale, t >= duration, t / duration
end

function Visual.TransitionAlpha(elapsed, duration)
	local alpha = Visual.TransitionState(elapsed, duration)
	return alpha
end

local map, sc
local chrome, header, atmosphere, grain, transition
local headerIcon, brandText, titleText, pathText, zoomFrame, zoomText, zoomTrack, zoomFill
local transitionCard, transitionKind, transitionTitle, transitionPath, transitionRule
local currentLayout, layoutKey, zoomTrackWidth = nil, nil, 52
local transitionElapsed, lastMapInfo, updateElapsed = 0, nil, 0

local function Color(texture, color, alpha)
	texture:SetColorTexture(color[1], color[2], color[3], alpha or color[4] or 1)
end

local function Gradient(texture, orientation, first, second)
	if texture.SetGradient and CreateColor then
		local ok = pcall(texture.SetGradient, texture, orientation,
			CreateColor(first[1], first[2], first[3], first[4]),
			CreateColor(second[1], second[2], second[3], second[4]))
		if ok then return end
	end
	if texture.SetGradientAlpha then
		local ok = pcall(texture.SetGradientAlpha, texture, orientation,
			first[1], first[2], first[3], first[4], second[1], second[2], second[3], second[4])
		if ok then return end
	end
	texture:SetColorTexture(first[1], first[2], first[3], math.min(first[4], 0.14))
end

local function MakeEdge(parent, side, size, orientation, first, second)
	local tex = parent:CreateTexture(nil, "BACKGROUND")
	if side == "left" then
		tex:SetPoint("TOPLEFT") tex:SetPoint("BOTTOMLEFT") tex:SetWidth(size)
	elseif side == "right" then
		tex:SetPoint("TOPRIGHT") tex:SetPoint("BOTTOMRIGHT") tex:SetWidth(size)
	elseif side == "top" then
		tex:SetPoint("TOPLEFT") tex:SetPoint("TOPRIGHT") tex:SetHeight(size)
	else
		tex:SetPoint("BOTTOMLEFT") tex:SetPoint("BOTTOMRIGHT") tex:SetHeight(size)
	end
	Gradient(tex, orientation, first, second)
	return tex
end

local function CurrentZoom()
	local stitchedZoom
	if mod.ViewNow then
		local _, _, value = mod.ViewNow()
		stitchedZoom = value
	end
	if stitchedZoom then return stitchedZoom end
	local base = sc.baseScale or (sc.zoomLevels and sc.zoomLevels[1] and sc.zoomLevels[1].scale) or 1
	local scale = sc.GetCanvasScale and sc:GetCanvasScale() or base
	return base > 0 and scale / base or 1
end

local function LayoutHeader(force)
	if not (header and sc) then return end
	local layout = Visual.HeaderLayout(sc:GetWidth())
	local key = layout.mode .. ":" .. math.floor(layout.width + 0.5)
	if not force and key == layoutKey then return end
	layoutKey, currentLayout, zoomTrackWidth = key, layout, layout.trackWidth

	header:ClearAllPoints()
	header:SetPoint("TOPLEFT", sc, "TOPLEFT", 14, -14)
	header:SetSize(layout.width, layout.height)
	headerIcon:SetSize(layout.icon, layout.icon)
	headerIcon:ClearAllPoints()
	headerIcon:SetPoint("LEFT", layout.mode == "compact" and 8 or 11, 0)

	zoomFrame:ClearAllPoints()
	zoomFrame:SetSize(layout.zoomWidth, layout.mode == "compact" and 27 or 32)
	zoomFrame:SetPoint("RIGHT", layout.mode == "compact" and -7 or -10, 0)
	zoomTrack:SetSize(layout.trackWidth, 2)

	brandText:ClearAllPoints()
	titleText:ClearAllPoints()
	pathText:ClearAllPoints()
	if layout.mode == "compact" then
		brandText:Hide()
		pathText:Hide()
		titleText:SetPoint("LEFT", headerIcon, "RIGHT", 8, 0)
		titleText:SetPoint("RIGHT", zoomFrame, "LEFT", -8, 0)
	else
		brandText:Show()
		pathText:Show()
		brandText:SetPoint("TOPLEFT", headerIcon, "TOPRIGHT", 9, -1)
		brandText:SetPoint("RIGHT", header, "RIGHT", -layout.zoomWidth - 24, 0)
		titleText:SetPoint("BOTTOMLEFT", headerIcon, "BOTTOMRIGHT", 9, 1)
		titleText:SetPoint("RIGHT", header, "RIGHT", -layout.zoomWidth - 24, 0)
		pathText:SetPoint("TOPLEFT", header, "TOPLEFT", layout.mode == "wide" and 330 or 285, -7)
		pathText:SetPoint("TOPRIGHT", header, "TOPRIGHT", -layout.zoomWidth - 24, -7)
	end
end

local function LayoutTransition()
	if not (transitionCard and sc) then return end
	transitionCard:SetWidth(math.min(360, math.max(260, sc:GetWidth() - 96)))
end

local function UpdateHeader()
	if not (map and map:GetMapID()) then return end
	LayoutHeader()
	local mapID = map:GetMapID()
	local title, _, chain = Visual.Breadcrumb(mapID)
	local info = chain[#chain]
	titleText:SetText(title)
	brandText:SetText("WORLDPANE   /   " .. Visual.MapKind(info))
	pathText:SetText(Visual.CompactPath(chain, currentLayout and currentLayout.pathDepth or 3))
	local zoom = CurrentZoom()
	local progress = Visual.ZoomProgress(zoom)
	zoomText:SetText(zoom < 10 and ("%.1f×"):format(zoom) or ("%.0f×"):format(zoom))
	zoomFill:SetWidth(math.max(1, zoomTrackWidth * progress))
	if atmosphere then
		local intensity = Clamp(tonumber(mod.db.visualIntensity) or 0.85, 0, 1)
		atmosphere:SetAlpha(intensity * (0.82 + 0.18 * progress))
	end
end

local function StopTransition()
	transitionElapsed = nil
	if transition then transition:Hide() end
end

local function PlayTransition(mapID)
	local info = mapID and C_Map.GetMapInfo(mapID)
	local announce = mod.db.visualTransitions and Visual.ShouldAnnounce(lastMapInfo, info,
		mod.IsStitched and mod.IsStitched())
	if not announce then
		lastMapInfo = info
		StopTransition()
		return
	end
	lastMapInfo = info
	local title, _, chain = Visual.Breadcrumb(mapID)
	transitionKind:SetText(Visual.MapKind(chain[#chain]))
	transitionTitle:SetText(title)
	transitionPath:SetText(Visual.CompactPath(chain, 3))
	transitionElapsed = 0
	transition:SetAlpha(0)
	transitionCard:SetScale(0.965)
	transition:Show()
end

local function Apply()
	if not chrome then return end
	LayoutHeader(true)
	header:SetShown(mod.db.visualHeader)
	local vignette, paper = mod.db.visualVignette, mod.db.visualGrain
	atmosphere:SetShown(vignette or paper)
	grain:SetShown(paper)
	for _, edge in ipairs(atmosphere.edges) do edge:SetShown(vignette) end
	for _, corner in ipairs(atmosphere.corners) do corner:SetShown(vignette) end
	atmosphere.border:SetShown(vignette)
	if not mod.db.visualTransitions then StopTransition() end
	UpdateHeader()
end

local function BuildAtmosphere(level)
	atmosphere = CreateFrame("Frame", nil, sc)
	atmosphere:SetAllPoints(sc)
	atmosphere:SetFrameLevel(level)
	atmosphere:EnableMouse(false)
	local dark = { 0.012, 0.010, 0.008, 0.58 }
	local clear = { 0.012, 0.010, 0.008, 0 }
	atmosphere.edges = {
		MakeEdge(atmosphere, "left", 84, "HORIZONTAL", dark, clear),
		MakeEdge(atmosphere, "right", 84, "HORIZONTAL", clear, dark),
		MakeEdge(atmosphere, "top", 64, "VERTICAL", dark, clear),
		MakeEdge(atmosphere, "bottom", 70, "VERTICAL", clear, dark),
	}
	grain = atmosphere:CreateTexture(nil, "ARTWORK")
	grain:SetAllPoints()
	grain:SetTexture(ns.Media.tex .. "MapGrain", "REPEAT", "REPEAT")
	grain:SetHorizTile(true)
	grain:SetVertTile(true)
	grain:SetBlendMode("BLEND")
	grain:SetAlpha(0.045)
	atmosphere.border = CreateFrame("Frame", nil, atmosphere, "BackdropTemplate")
	atmosphere.border:SetAllPoints()
	atmosphere.border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
	Theme.SetColor(atmosphere.border, "SetBackdropBorderColor", Theme.semantic.borderQuiet, 0.74)

	-- Four short corner marks make the canvas feel precisely framed without a
	-- heavy ornamental border competing with the map art.
	atmosphere.corners = {}
	for _, spec in ipairs({
		{ "TOPLEFT", 1, -1, 30, 1 }, { "TOPLEFT", 1, -1, 1, 30 },
		{ "TOPRIGHT", -1, -1, 30, 1 }, { "TOPRIGHT", -1, -1, 1, 30 },
		{ "BOTTOMLEFT", 1, 1, 30, 1 }, { "BOTTOMLEFT", 1, 1, 1, 30 },
		{ "BOTTOMRIGHT", -1, 1, 30, 1 }, { "BOTTOMRIGHT", -1, 1, 1, 30 },
	}) do
		local mark = atmosphere:CreateTexture(nil, "OVERLAY")
		mark:SetPoint(spec[1], spec[2], spec[3])
		mark:SetSize(spec[4], spec[5])
		Color(mark, Theme.semantic.accentMuted, 0.38)
		atmosphere.corners[#atmosphere.corners + 1] = mark
	end
end

local function BuildHeader(level)
	chrome = CreateFrame("Frame", nil, sc)
	chrome:SetAllPoints(sc)
	chrome:SetFrameLevel(level)
	chrome:EnableMouse(false)

	header = CreateFrame("Frame", nil, chrome, "BackdropTemplate")
	Theme.Backdrop(header, Theme.component.mapHeader, 0.91)
	header:EnableMouse(false)
	local shadow = header:CreateTexture(nil, "BACKGROUND", nil, -1)
	shadow:SetPoint("TOPLEFT", -6, 6)
	shadow:SetPoint("BOTTOMRIGHT", 6, -6)
	Color(shadow, Theme.semantic.shadow, 0.38)
	local sheen = header:CreateTexture(nil, "ARTWORK", nil, -1)
	sheen:SetAllPoints()
	Gradient(sheen, "HORIZONTAL", { 0.52, 0.39, 0.23, 0.13 }, { 0.03, 0.027, 0.024, 0 })
	local accent = header:CreateTexture(nil, "ARTWORK")
	accent:SetPoint("TOPLEFT") accent:SetPoint("BOTTOMLEFT") accent:SetWidth(3)
	Color(accent, Theme.semantic.accent, 0.94)
	local cap = header:CreateTexture(nil, "ARTWORK")
	cap:SetPoint("TOPLEFT", 3, 0) cap:SetPoint("TOPRIGHT", 0, 0) cap:SetHeight(1)
	Gradient(cap, "HORIZONTAL", { 1, 0.79, 0.275, 0.42 }, { 0.52, 0.39, 0.23, 0.04 })

	headerIcon = header:CreateTexture(nil, "ARTWORK")
	headerIcon:SetTexture(ns.Media.icon)
	headerIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	brandText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	ns.Look:Font(brandText, 9, "OUTLINE")
	Theme.SetColor(brandText, "SetTextColor", Theme.semantic.accent)
	brandText:SetJustifyH("LEFT")
	brandText:SetWordWrap(false)

	titleText = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	ns.Look:Font(titleText, 17, "OUTLINE")
	Theme.SetColor(titleText, "SetTextColor", Theme.semantic.text)
	titleText:SetJustifyH("LEFT")
	titleText:SetWordWrap(false)

	pathText = header:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	ns.Look:Font(pathText, 9, "OUTLINE")
	Theme.SetColor(pathText, "SetTextColor", Theme.semantic.textSubtle)
	pathText:SetJustifyH("RIGHT")
	pathText:SetWordWrap(false)

	zoomFrame = CreateFrame("Frame", nil, header, "BackdropTemplate")
	Theme.Backdrop(zoomFrame, { background = Theme.semantic.surfaceStrong, border = Theme.semantic.borderQuiet }, 0.86)
	zoomText = zoomFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	ns.Look:Font(zoomText, 11, "OUTLINE")
	Theme.SetColor(zoomText, "SetTextColor", Theme.semantic.accentBright)
	zoomText:SetPoint("TOP", 0, -4)
	zoomTrack = zoomFrame:CreateTexture(nil, "ARTWORK")
	zoomTrack:SetPoint("BOTTOM", 0, 5)
	Color(zoomTrack, Theme.semantic.borderQuiet, 0.82)
	zoomFill = zoomFrame:CreateTexture(nil, "OVERLAY")
	zoomFill:SetHeight(2)
	zoomFill:SetPoint("LEFT", zoomTrack, "LEFT")
	Color(zoomFill, Theme.semantic.accentBright, 1)
	LayoutHeader(true)
end

local function BuildTransition(level)
	transition = CreateFrame("Frame", nil, sc)
	transition:SetAllPoints(sc)
	transition:SetFrameLevel(level)
	transition:EnableMouse(false)
	local veil = transition:CreateTexture(nil, "BACKGROUND")
	veil:SetAllPoints()
	Color(veil, Theme.semantic.shadow, 0.055)
	transitionCard = CreateFrame("Frame", nil, transition, "BackdropTemplate")
	transitionCard:SetHeight(72)
	transitionCard:SetPoint("TOP", transition, "TOP", 0, -76)
	Theme.Backdrop(transitionCard, Theme.component.transitionCard, 0.84)
	local shadow = transitionCard:CreateTexture(nil, "BACKGROUND", nil, -1)
	shadow:SetPoint("TOPLEFT", -8, 8)
	shadow:SetPoint("BOTTOMRIGHT", 8, -8)
	Color(shadow, Theme.semantic.shadow, 0.30)
	transitionRule = transitionCard:CreateTexture(nil, "ARTWORK")
	transitionRule:SetPoint("TOP", 0, -10)
	transitionRule:SetSize(68, 1)
	Color(transitionRule, Theme.semantic.accentBright, 0.58)
	transitionKind = transitionCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	ns.Look:Font(transitionKind, 9, "OUTLINE")
	Theme.SetColor(transitionKind, "SetTextColor", Theme.semantic.accent)
	transitionKind:SetPoint("TOP", 0, -15)
	transitionTitle = transitionCard:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
	ns.Look:Font(transitionTitle, 19, "OUTLINE")
	Theme.SetColor(transitionTitle, "SetTextColor", Theme.semantic.text)
	transitionTitle:SetPoint("CENTER", 0, -1)
	transitionPath = transitionCard:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	ns.Look:Font(transitionPath, 9, "OUTLINE")
	Theme.SetColor(transitionPath, "SetTextColor", Theme.semantic.textMuted)
	transitionPath:SetPoint("TOP", transitionTitle, "BOTTOM", 0, -5)
	LayoutTransition()
	transition:Hide()
end

function mod:SetupVisual(worldMap)
	map, sc = worldMap, worldMap.ScrollContainer
	if not (map and sc and Theme) then return end
	local base = math.min(sc:GetFrameLevel() + 9050, 9920)
	BuildAtmosphere(base)
	BuildHeader(math.min(base + 30, 9950))
	BuildTransition(math.min(base + 45, 9970))

	local provider = CreateFromMixins(MapCanvasDataProviderMixin)
	provider.OnMapChanged = function()
		UpdateHeader()
		PlayTransition(map:GetMapID())
	end
	provider.OnCanvasScaleChanged = UpdateHeader
	provider.OnShow = function()
		Apply()
		PlayTransition(map:GetMapID())
	end
	provider.OnHide = function() lastMapInfo = nil StopTransition() end
	map:AddDataProvider(provider)
	sc:HookScript("OnSizeChanged", function()
		LayoutHeader(true)
		LayoutTransition()
		UpdateHeader()
	end)

	chrome:SetScript("OnUpdate", function(_, elapsed)
		updateElapsed = updateElapsed + elapsed
		if updateElapsed >= 0.10 then updateElapsed = 0 UpdateHeader() end
		if transitionElapsed then
			transitionElapsed = transitionElapsed + elapsed
			local duration = Theme.motion and Theme.motion.locationTransition or 0.58
			local alpha, scale, done, progress = Visual.TransitionState(transitionElapsed, duration)
			transition:SetAlpha(alpha)
			transitionCard:SetScale(scale)
			transitionRule:SetWidth(68 + 64 * math.min(1, progress * 2.5))
			if done then StopTransition() end
		end
	end)
	Apply()
end

function mod.RefreshVisual()
	Apply()
end

function mod:VisualOptions(opts, get, set, off)
	opts.visualHeader = { type = "toggle", name = "Context header", order = 24.1, get = get, set = set, disabled = off,
		desc = "An adaptive WorldPane header with the current map type, hierarchy, and live zoom depth." }
	opts.visualTransitions = { type = "toggle", name = "Map transitions", order = 24.2, get = get, set = set, disabled = off,
		desc = "A short staged title transition when the view enters another zone, continent, or world." }
	opts.visualVignette = { type = "toggle", name = "Edge atmosphere", order = 24.3, get = get, set = set, disabled = off,
		desc = "Soft edge depth, precise corner marks, and a fine bronze boundary around the map canvas." }
	opts.visualGrain = { type = "toggle", name = "Parchment grain", order = 24.4, get = get, set = set, disabled = off,
		desc = "A very subtle texture that visually unifies map art from different eras." }
	opts.visualIntensity = { type = "range", name = "Atmosphere intensity", order = 24.5, min = 0, max = 1, step = 0.05,
		isPercent = true, get = get, set = set, disabled = off,
		desc = "The strength of edge depth and framing. It does not change the map artwork itself." }
end
