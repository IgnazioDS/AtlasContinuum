--------------------------------------------------------------------------------
-- WorldPane regional previews
--
-- Azeroth has one shared coordinate space and is handled by Stitch.lua. Retail's
-- other continents (Outland, Draenor, the Shadowlands, and later world spaces)
-- do not. This renderer stays on Blizzard's native canvas and fades the live
-- client's child-zone art into continents, or complete reveal art into a
-- detached zone, as the player zooms closer. Nothing here depends on a fixed
-- list of expansion continent IDs.
--------------------------------------------------------------------------------

local ADDON, ns = ...
local S = ns.MapStitch
local mod = ns:GetModule("worldmap")

local R = {}
ns.MapRegions = R
local Unpack = unpack or table.unpack

local MAX_DEPTH = 8
local MAX_ZONES = 32
local MAX_TEXTURES = 2048
local ZOOM_STEP = 1.25
local MAX_REGIONAL_ZOOM = 6
local FADE_FROM, FADE_TO = 1.1, 2.6
local FEATHER = "Interface\\AddOns\\" .. ADDON .. "\\Media\\Textures\\Retail\\MapFeatherRound"

local function SafeCall(fn, ...)
	if type(fn) ~= "function" then return end
	local result = { pcall(fn, ...) }
	if not result[1] then return end
	return Unpack(result, 2)
end

local function Rect(mapID, rootMapID)
	local l, r, t, b = SafeCall(C_Map.GetMapRectOnMap, mapID, rootMapID)
	if l and r and t and b and r > l and b > t then return l, r, t, b end
end

-- A detached zone may be returned by GetMapInfoAtPosition even though it has no
-- rectangle in its parent. Keep descending while rectangles exist, but test the
-- returned map before asking for one. The old click path did those in the other
-- order, which made this branch unreachable for exactly these maps.
function R.DetachedAt(rootMapID, x, y, awayMaps)
	if not (rootMapID and x and y and awayMaps) then return end
	local mapID = rootMapID
	for _ = 1, MAX_DEPTH do
		local info = SafeCall(C_Map.GetMapInfoAtPosition, mapID, x, y)
		if not info or not info.mapID or info.mapID == mapID then return end
		if awayMaps[info.mapID] then return info.mapID end
		if info.mapType ~= Enum.UIMapType.Continent and info.mapType ~= Enum.UIMapType.Zone then return end
		local l, r, t, b = Rect(info.mapID, mapID)
		if not l then return end
		mapID, x, y = info.mapID, (x - l) / (r - l), (y - t) / (b - t)
	end
end

-- Midnight's detached destinations are also exposed as MapLink pins. Those pins
-- are not part of the canvas hierarchy at all, so resolve their linked map ID
-- directly when the global pin click hook sees one.
function R.LinkedAwayMap(pin, awayMaps)
	if not (pin and awayMaps and type(pin.GetLinkedUIMapID) == "function") then return end
	local mapID = SafeCall(pin.GetLinkedUIMapID, pin)
	return mapID and awayMaps[mapID] and mapID or nil
end

-- Direct zone children are the stable, visible generation for a continent.
-- Recursive discovery is only a fallback for unusual roots that insert an
-- intermediate map in their UI hierarchy.
function R.ZoneRects(rootMapID)
	local children = SafeCall(C_Map.GetMapChildrenInfo, rootMapID, Enum.UIMapType.Zone, false) or {}
	if #children == 0 then
		children = SafeCall(C_Map.GetMapChildrenInfo, rootMapID, Enum.UIMapType.Zone, true) or {}
	end
	local zones, seen = {}, {}
	for _, info in ipairs(children) do
		if info.mapID and not seen[info.mapID] then
			seen[info.mapID] = true
			local l, r, t, b = Rect(info.mapID, rootMapID)
			if l then
				zones[#zones + 1] = { mapID = info.mapID, name = info.name, l = l, r = r, t = t, b = b,
					area = (r - l) * (b - t) }
			end
		end
	end
	table.sort(zones, function(a, b)
		if a.area ~= b.area then return a.area > b.area end
		return a.mapID < b.mapID
	end)
	return zones
end

function R.PreviewRects(rootMapID)
	local info = SafeCall(C_Map.GetMapInfo, rootMapID)
	local away = ns.ClientMaps and ns.ClientMaps.awayMaps
	if info and info.mapType == Enum.UIMapType.Zone and away and away[rootMapID] then
		return { { mapID = rootMapID, name = info.name, l = 0, r = 1, t = 0, b = 1, area = 1 } }
	end
	return R.ZoneRects(rootMapID)
end

local function Pow2(n)
	local p = 16
	while p < n do p = p * 2 end
	return p
end

local function SplitIDs(value)
	local out = {}
	for id in tostring(value or ""):gmatch("[^,%s]+") do out[#out + 1] = tonumber(id) or id end
	return out
end

local map, sc, canvas, root, artLevel, levelRange
local zonePool, activeZones = {}, 0
local currentRoot, previewing
local stats = { root = 0, zones = 0, textures = 0 }
R.stats = stats

local function ResetZone(zone)
	for _, tex in ipairs(zone.textures) do
		if zone.mask and tex.RemoveMaskTexture then pcall(tex.RemoveMaskTexture, tex, zone.mask) end
		tex:SetTexture(nil)
		tex:Hide()
	end
	zone.used = 0
	zone.rect = nil
	if zone.mask then zone.mask:SetTexture(nil) end
	zone.frame:Hide()
end

local function AcquireZone(index)
	local zone = zonePool[index]
	if not zone then
		local frame = CreateFrame("Frame", nil, root)
		frame:EnableMouse(false)
		local mask = frame:CreateMaskTexture()
		mask:SetAllPoints(frame)
		zone = { frame = frame, mask = mask, textures = {}, used = 0 }
		zonePool[index] = zone
	end
	ResetZone(zone)
	zone.frame:Show()
	return zone
end

local function LayoutZone(zone, rootWidth, rootHeight)
	local r = zone.rect
	if not r then return end
	local width, height = (r.r - r.l) * rootWidth, (r.b - r.t) * rootHeight
	zone.frame:ClearAllPoints()
	zone.frame:SetPoint("TOPLEFT", root, "TOPLEFT", r.l * rootWidth, -r.t * rootHeight)
	zone.frame:SetSize(width, height)
	for i = 1, zone.used do
		local tex, box = zone.textures[i], zone.textures[i].box
		tex:ClearAllPoints()
		tex:SetPoint("TOPLEFT", zone.frame, "TOPLEFT", box[1] * width, -box[2] * height)
		tex:SetSize((box[3] - box[1]) * width, (box[4] - box[2]) * height)
	end
end

local function LayoutAll(_, width, height)
	width, height = width or root:GetWidth(), height or root:GetHeight()
	if not width or not height or width <= 0 or height <= 0 then return end
	for i = 1, activeZones do LayoutZone(zonePool[i], width, height) end
end

local function AddTexture(zone, file, u0, v0, u1, v1, texRight, texBottom, subLevel)
	if not file or stats.textures >= MAX_TEXTURES then return false end
	zone.used = zone.used + 1
	local tex = zone.textures[zone.used]
	if not tex then
		tex = zone.frame:CreateTexture(nil, "ARTWORK")
		zone.textures[zone.used] = tex
	end
	tex:SetDrawLayer("ARTWORK", subLevel or 0)
	tex:SetTexture(tonumber(file) or file, nil, nil, "TRILINEAR")
	tex:SetTexCoord(0, texRight or 1, 0, texBottom or 1)
	tex.box = { u0, v0, u1, v1 }
	if zone.mask and tex.AddMaskTexture then tex:AddMaskTexture(zone.mask) end
	tex:Show()
	stats.textures = stats.textures + 1
	return true
end

local function AddTiles(zone, layer, files, x, y, width, height, overlay, subLevel)
	if type(files) ~= "table" or #files == 0 then return end
	local tw, th = layer.tileWidth or 256, layer.tileHeight or 256
	local aw, ah = layer.layerWidth, layer.layerHeight
	if not aw or not ah or aw <= 0 or ah <= 0 then return end
	local cols, rows = math.ceil(width / tw), math.ceil(height / th)
	for row = 1, rows do
		local ph = row < rows and th or height - (rows - 1) * th
		local fileHeight = (row < rows or not overlay) and th or Pow2(ph)
		for col = 1, cols do
			local pw = col < cols and tw or width - (cols - 1) * tw
			local fileWidth = (col < cols or not overlay) and tw or Pow2(pw)
			local px, py = x + (col - 1) * tw, y + (row - 1) * th
			if pw > 0 and ph > 0 then
				AddTexture(zone, files[(row - 1) * cols + col], px / aw, py / ah,
					(px + pw) / aw, (py + ph) / ah, pw / fileWidth, ph / fileHeight, subLevel)
			end
		end
	end
end

local function AddExploration(zone, mapID, layer)
	local explored = C_MapExplorationInfo and
		SafeCall(C_MapExplorationInfo.GetExploredMapTextures, mapID) or {}
	local seen = {}
	for _, info in ipairs(explored or {}) do
		local key = info.textureWidth .. ":" .. info.textureHeight .. ":" .. info.offsetX .. ":" .. info.offsetY
		seen[key] = true
		if not info.isShownByMouseOver then
			AddTiles(zone, layer, info.fileDataIDs, info.offsetX, info.offsetY,
				info.textureWidth, info.textureHeight, true, 1)
		end
	end
	local artID = SafeCall(C_Map.GetMapArtID, mapID)
	local reveal = ns.MapReveal and ns.MapReveal[artID or 0]
	for key, ids in pairs(reveal or {}) do
		if not seen[key] then
			local width, height, x, y = key:match("^(%d+):(%d+):(%-?%d+):(%-?%d+)$")
			width, height, x, y = tonumber(width), tonumber(height), tonumber(x), tonumber(y)
			if width and height and x and y then
				AddTiles(zone, layer, SplitIDs(ids), x, y, width, height, true, 0)
			end
		end
	end
end

local function RenderZone(index, entry)
	local layers = SafeCall(C_Map.GetMapArtLayers, entry.mapID)
	local layer = layers and layers[1]
	local files = layer and SafeCall(C_Map.GetMapArtLayerTextures, entry.mapID, 1)
	if not layer or type(files) ~= "table" or #files == 0 then return false end
	local zone = AcquireZone(index)
	zone.rect = entry
	zone.mapID = entry.mapID
	zone.frame:SetFrameLevel(math.min(artLevel + index, artLevel + levelRange - 1))
	zone.mask:SetTexture(FEATHER, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	AddTiles(zone, layer, files, 0, 0, layer.layerWidth, layer.layerHeight, false, -1)
	AddExploration(zone, entry.mapID, layer)
	return zone.used > 0
end

local function IsRegionalRoot(mapID)
	if not mapID or mapID == S.WORLD or not mod.enabled then return false end
	local info = SafeCall(C_Map.GetMapInfo, mapID)
	if not info then return false end
	local away = ns.ClientMaps and ns.ClientMaps.awayMaps
	if info.mapType == Enum.UIMapType.Zone and away and away[mapID] then return true end
	if info.mapType ~= Enum.UIMapType.Continent then return false end
	local l = S.Rect(mapID)
	return not (l and S.Stitched(mapID, true))
end
R.IsRegionalRoot = IsRegionalRoot

local function Build(mapID)
	for i = 1, #zonePool do ResetZone(zonePool[i]) end
	activeZones, stats.root, stats.zones, stats.textures = 0, mapID or 0, 0, 0
	if not IsRegionalRoot(mapID) then return false end
	for _, entry in ipairs(R.PreviewRects(mapID)) do
		if activeZones >= MAX_ZONES or stats.textures >= MAX_TEXTURES then break end
		local index = activeZones + 1
		if RenderZone(index, entry) then activeZones = index end
	end
	stats.zones = activeZones
	LayoutAll()
	return activeZones > 0
end

local function Fade()
	if not previewing then root:Hide() return end
	local base = sc.baseScale or (sc.zoomLevels and sc.zoomLevels[1] and sc.zoomLevels[1].scale) or 1
	local scale = sc:GetCanvasScale() or base
	local ratio = base > 0 and scale / base or 1
	local t = math.max(0, math.min(1, (ratio - FADE_FROM) / (FADE_TO - FADE_FROM)))
	-- smoothstep keeps the first and last frames of the transition visually still.
	t = t * t * (3 - 2 * t)
	root:SetAlpha(t)
	root:SetShown(t > 0.001)
end

local function Refresh()
	local mapID = map and map:GetMapID()
	if currentRoot ~= mapID then
		currentRoot = mapID
		previewing = Build(mapID)
	else
		previewing = IsRegionalRoot(mapID) and activeZones > 0
	end
	Fade()
end

local function ExtendZoomLevels(self)
	if not IsRegionalRoot(self.mapID) then return end
	local levels = self.zoomLevels
	if type(levels) ~= "table" or #levels == 0 then return end
	local base = self.baseScale or levels[1].scale
	local last = levels[#levels]
	local scale = last.scale or base
	local target = base * MAX_REGIONAL_ZOOM
	while scale < target / 1.001 do
		scale = math.min(scale * ZOOM_STEP, target)
		levels[#levels + 1] = { scale = scale, layerIndex = last.layerIndex or 1 }
	end
	self.baseScale = base
end

function mod:SetupRegional(worldMap, stitchArtLevel, stitchRange)
	map, sc, artLevel, levelRange = worldMap, worldMap.ScrollContainer, stitchArtLevel, stitchRange
	canvas = map:GetCanvas()
	if not canvas then return end
	root = CreateFrame("Frame", nil, canvas)
	root:SetAllPoints(canvas)
	root:SetFrameLevel(artLevel)
	root:EnableMouse(false)
	root:Hide()
	root:SetScript("OnSizeChanged", LayoutAll)

	-- WorldMap.lua's zoom-level hook runs first and decides whether Azeroth owns the canvas.
	-- Regional roots extend Blizzard's native levels only after that decision.
	hooksecurefunc(sc, "CreateZoomLevels", ExtendZoomLevels)

	local provider = CreateFromMixins(MapCanvasDataProviderMixin)
	provider.OnMapChanged = Refresh
	provider.OnCanvasScaleChanged = Fade
	provider.OnShow = Refresh
	provider.OnHide = function() root:Hide() end
	map:AddDataProvider(provider)

	if map:IsShown() and map:GetMapID() then Refresh() end
end
