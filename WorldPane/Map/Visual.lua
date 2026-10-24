--------------------------------------------------------------------------------
-- WorldPane presentation layer
--
-- A lightweight, non-interactive layer over Blizzard's canvas: contextual map
-- header, zoom feedback, edge atmosphere and short map-to-map title transitions.
-- It never owns navigation or map data, so disabling it changes presentation only.
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

local function Clamp(value, low, high)
	return math.max(low, math.min(high, value))
end

function Visual.Breadcrumb(mapID, maxDepth)
	local chain, seen = {}, {}
	local current = mapID
	for _ = 1, maxDepth or 6 do
		if not current or current == 0 or seen[current] then break end
		seen[current] = true
		local ok, info = pcall(C_Map.GetMapInfo, current)
		if not ok or not info then break end
		chain[#chain + 1] = { mapID = current, name = info.name or tostring(current) }
		current = info.parentMapID
	end
	local ordered = {}
	for i = #chain, 1, -1 do ordered[#ordered + 1] = chain[i] end
	local title = chain[1] and chain[1].name or (WORLD_MAP or "World Map")
	local parents = {}
	for i = 1, math.max(0, #ordered - 1) do parents[#parents + 1] = ordered[i].name end
	return title, #parents > 0 and table.concat(parents, "  ›  ") or (WORLD_MAP or "World Map"), ordered
end

function Visual.ZoomProgress(zoom)
	zoom = math.max(1, tonumber(zoom) or 1)
	return Clamp(math.log(zoom) / math.log(64), 0, 1)
end

function Visual.TransitionAlpha(elapsed, duration)
	local t = Clamp((elapsed or 0) / (duration or 0.45), 0, 1)
	local smooth = t * t * (3 - 2 * t)
	return 1 - smooth
end

local map, sc
local chrome, header, atmosphere, grain, transition
local titleText, pathText, zoomText, zoomFill, transitionTitle, transitionPath
local transitionElapsed, lastMapID, updateElapsed = 0, nil, 0

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
	local _, _, stitchedZoom
	if mod.ViewNow then _, _, stitchedZoom = mod.ViewNow() end
	if stitchedZoom then return stitchedZoom end
	local base = sc.baseScale or (sc.zoomLevels and sc.zoomLevels[1] and sc.zoomLevels[1].scale) or 1
	local scale = sc.GetCanvasScale and sc:GetCanvasScale() or base
	return base > 0 and scale / base or 1
end

local function UpdateHeader()
	if not (map and map:GetMapID()) then return end
	local title, path = Visual.Breadcrumb(map:GetMapID())
	titleText:SetText(title)
	pathText:SetText(path)
	local zoom = CurrentZoom()
	zoomText:SetText(zoom < 10 and ("%.1f×"):format(zoom) or ("%.0f×"):format(zoom))
	zoomFill:SetWidth(math.max(1, 52 * Visual.ZoomProgress(zoom)))
end

local function StopTransition()
	transitionElapsed = nil
	if transition then transition:Hide() end
end

local function PlayTransition(mapID)
	if not (mod.db.visualTransitions and mapID and mapID ~= lastMapID) then
		lastMapID = mapID
		return
	end
	lastMapID = mapID
	local title, path = Visual.Breadcrumb(mapID)
	transitionTitle:SetText(title)
	transitionPath:SetText(path)
	transitionElapsed = 0
	transition:SetAlpha(1)
	transition:Show()
end

local function Apply()
	if not chrome then return end
	header:SetShown(mod.db.visualHeader)
	grain:SetShown(mod.db.visualGrain)
	for _, edge in ipairs(atmosphere.edges) do edge:SetShown(mod.db.visualVignette) end
	atmosphere.border:SetShown(mod.db.visualVignette)
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
	grain:SetBlendMode("OVERLAY")
	grain:SetAlpha(0.055)
	atmosphere.border = CreateFrame("Frame", nil, atmosphere, "BackdropTemplate")
	atmosphere.border:SetAllPoints()
	atmosphere.border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
	Theme.SetColor(atmosphere.border, "SetBackdropBorderColor", Theme.semantic.borderQuiet, 0.72)
end

local function BuildHeader(level)
	chrome = CreateFrame("Frame", nil, sc)
	chrome:SetAllPoints(sc)
	chrome:SetFrameLevel(level)
	chrome:EnableMouse(false)

	header = CreateFrame("Frame", nil, chrome, "BackdropTemplate")
	header:SetPoint("TOPLEFT", sc, "TOPLEFT", 14, -14)
	header:SetPoint("TOPRIGHT", sc, "TOPRIGHT", -68, -14)
	header:SetHeight(48)
	Theme.Backdrop(header, Theme.component.mapHeader, 0.88)
	header:EnableMouse(false)

	local shadow = header:CreateTexture(nil, "BACKGROUND", nil, -1)
	shadow:SetPoint("TOPLEFT", -5, 5)
	shadow:SetPoint("BOTTOMRIGHT", 5, -5)
	Color(shadow, Theme.semantic.shadow, 0.34)
	local accent = header:CreateTexture(nil, "ARTWORK")
	accent:SetPoint("TOPLEFT", 0, 0)
	accent:SetPoint("BOTTOMLEFT", 0, 0)
	accent:SetWidth(3)
	Color(accent, Theme.semantic.accent, 0.92)

	local icon = header:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(ns.Media.icon)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon:SetSize(30, 30)
	icon:SetPoint("LEFT", 12, 0)

	local brand = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	ns.Look:Font(brand, 10, "OUTLINE")
	brand:SetTextColor(unpack(Theme.semantic.accent))
	brand:SetPoint("TOPLEFT", icon, "TOPRIGHT", 9, -1)
	brand:SetText("WORLD PANE")

	titleText = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	ns.Look:Font(titleText, 16, "OUTLINE")
	titleText:SetTextColor(unpack(Theme.semantic.text))
	titleText:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 9, 0)
	titleText:SetPoint("RIGHT", header, "RIGHT", -80, 0)
	titleText:SetJustifyH("LEFT")

	pathText = header:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	ns.Look:Font(pathText, 10, "OUTLINE")
	pathText:SetTextColor(unpack(Theme.semantic.textMuted))
	pathText:SetPoint("TOPLEFT", header, "TOPLEFT", 200, -6)
	pathText:SetPoint("TOPRIGHT", header, "TOPRIGHT", -80, -6)
	pathText:SetJustifyH("RIGHT")

	local zoom = CreateFrame("Frame", nil, header, "BackdropTemplate")
	zoom:SetSize(62, 30)
	zoom:SetPoint("RIGHT", -9, 0)
	Theme.Backdrop(zoom, { background = Theme.semantic.surfaceStrong, border = Theme.semantic.borderQuiet }, 0.82)
	zoomText = zoom:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	ns.Look:Font(zoomText, 11, "OUTLINE")
	zoomText:SetTextColor(unpack(Theme.semantic.accent))
	zoomText:SetPoint("TOP", 0, -4)
	local track = zoom:CreateTexture(nil, "ARTWORK")
	track:SetSize(52, 2)
	track:SetPoint("BOTTOM", 0, 5)
	Color(track, Theme.semantic.borderQuiet, 0.75)
	zoomFill = zoom:CreateTexture(nil, "OVERLAY")
	zoomFill:SetHeight(2)
	zoomFill:SetPoint("LEFT", track, "LEFT")
	Color(zoomFill, Theme.semantic.accent, 1)
end

local function BuildTransition(level)
	transition = CreateFrame("Frame", nil, sc)
	transition:SetAllPoints(sc)
	transition:SetFrameLevel(level)
	transition:EnableMouse(false)
	local veil = transition:CreateTexture(nil, "BACKGROUND")
	veil:SetAllPoints()
	Color(veil, Theme.semantic.shadow, 0.30)
	local card = CreateFrame("Frame", nil, transition, "BackdropTemplate")
	card:SetSize(360, 78)
	card:SetPoint("CENTER")
	Theme.Backdrop(card, Theme.component.mapHeader, 0.84)
	local top = card:CreateTexture(nil, "ARTWORK")
	top:SetPoint("TOPLEFT", 34, -12)
	top:SetPoint("TOPRIGHT", -34, -12)
	top:SetHeight(1)
	Color(top, Theme.semantic.accent, 0.65)
	transitionTitle = card:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
	ns.Look:Font(transitionTitle, 23, "OUTLINE")
	transitionTitle:SetTextColor(unpack(Theme.semantic.text))
	transitionTitle:SetPoint("CENTER", 0, 6)
	transitionPath = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	ns.Look:Font(transitionPath, 10, "OUTLINE")
	transitionPath:SetTextColor(unpack(Theme.semantic.textMuted))
	transitionPath:SetPoint("TOP", transitionTitle, "BOTTOM", 0, -5)
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
	provider.OnHide = function() lastMapID = nil StopTransition() end
	map:AddDataProvider(provider)

	chrome:SetScript("OnUpdate", function(_, elapsed)
		updateElapsed = updateElapsed + elapsed
		if updateElapsed >= 0.10 then updateElapsed = 0 UpdateHeader() end
		if transitionElapsed then
			transitionElapsed = transitionElapsed + elapsed
			local alpha = Visual.TransitionAlpha(transitionElapsed, 0.48)
			transition:SetAlpha(alpha)
			if alpha <= 0.001 then StopTransition() end
		end
	end)
	Apply()
end

function mod.RefreshVisual()
	Apply()
end

function mod:VisualOptions(opts, get, set, off)
	opts.visualHeader = { type = "toggle", name = "Context header", order = 24.1, get = get, set = set, disabled = off,
		desc = "A compact WorldPane header with the current map hierarchy and live zoom depth." }
	opts.visualTransitions = { type = "toggle", name = "Map transitions", order = 24.2, get = get, set = set, disabled = off,
		desc = "A short title transition when the view enters another zone, continent, or world." }
	opts.visualVignette = { type = "toggle", name = "Edge atmosphere", order = 24.3, get = get, set = set, disabled = off,
		desc = "Soft edge depth and a fine bronze boundary around the map canvas." }
	opts.visualGrain = { type = "toggle", name = "Parchment grain", order = 24.4, get = get, set = set, disabled = off,
		desc = "A very subtle texture that visually unifies map art from different eras." }
end

