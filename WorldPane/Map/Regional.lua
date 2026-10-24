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

local function PositionXY(position)
	if not position then return end
	if type(position.GetXY) == "function" then return SafeCall(position.GetXY, position) end
	return position.x or position[1], position.y or position[2]
end

-- Map links are not children with rectangles: they are portals painted into a parent map. Resolve the
-- live API's link centres into stitched-world coordinates and enrich them with the client's full link
-- rectangles. The static rectangles are intentionally only a fallback/pointer hit area; names and atlas
-- art continue to come from the live client.
function R.AwayLinks(awayMaps, configured, rectFn)
	if not awayMaps then return {} end
	rectFn = rectFn or S.Rect
	local links, byTarget, parents = {}, {}, {}

	for mapID in pairs(awayMaps) do
		local info = SafeCall(C_Map.GetMapInfo, mapID)
		if info and info.parentMapID and info.parentMapID ~= 0 then parents[info.parentMapID] = true end
	end
	for parentMapID in pairs(configured or {}) do parents[parentMapID] = true end

	local function Add(parentMapID, mapID, x, y, name, atlasName)
		if not (awayMaps[mapID] and x and y) then return end
		local l, r, t, b = rectFn(parentMapID)
		if not l then return end
		local link = byTarget[mapID]
		if not link then
			local mapInfo = SafeCall(C_Map.GetMapInfo, mapID)
			link = { mapID = mapID, parentMapID = parentMapID }
			links[#links + 1], byTarget[mapID] = link, link
			link.name = name or (mapInfo and mapInfo.name)
		end
		link.u, link.v = l + x * (r - l), t + y * (b - t)
		link.atlasName = atlasName or link.atlasName
		return link, l, r, t, b
	end

	for parentMapID in pairs(parents) do
		for _, info in ipairs(SafeCall(C_Map.GetMapLinksForMap, parentMapID) or {}) do
			local x, y = PositionXY(info.position)
			Add(parentMapID, info.linkedUiMapID, x, y, info.name, info.atlasName)
		end
	end

	for parentMapID, entries in pairs(configured or {}) do
		for _, entry in ipairs(entries) do
			local x = entry.x or (entry.minX and entry.maxX and (entry.minX + entry.maxX) / 2)
			local y = entry.y or (entry.minY and entry.maxY and (entry.minY + entry.maxY) / 2)
			local link, l, r, t, b = Add(parentMapID, entry.mapID or entry[1], x, y, entry.name, entry.atlasName)
			if link and entry.minX and entry.minY and entry.maxX and entry.maxY then
				link.u0, link.u1 = l + entry.minX * (r - l), l + entry.maxX * (r - l)
				link.v0, link.v1 = t + entry.minY * (b - t), t + entry.maxY * (b - t)
			end
		end
	end

	table.sort(links, function(a, b) return a.mapID < b.mapID end)
	return links
end

R.links = {}

-- Blizzard's MapLink pins use right-click to navigate while WorldPane's stitched
-- canvas uses left-click to descend. Detached portals support both conventions;
-- middle-click remains reserved for Find Me.
function R.IsOpenButton(button)
	return button == "LeftButton" or button == "RightButton"
end

-- Hit the real UiMapLink rectangle first. The pixel-radius fallback also covers live-only future links
-- that have a centre but no client policy bounds yet.
function R.AwayLinkAt(u, v, pxU, pxV, links, reach)
	if not (u and v) then return end
	if links == nil then
		links = R.links
		-- Link geometry is cheap and comes from client policy plus C_Map. Rebuild it
		-- lazily if the first stitched-map build occurred before this provider was
		-- ready; click handling must not depend on one initialization ordering.
		if #links == 0 then
			local policy = ns.ClientMaps
			if policy and policy.awayMaps then
				R.links = R.AwayLinks(policy.awayMaps, policy.awayLinks, S.Rect)
				links = R.links
			end
		end
	end
	reach = reach or 48
	for _, link in ipairs(links or {}) do
		if link.u0 and u >= link.u0 and u <= link.u1 and v >= link.v0 and v <= link.v1 then
			return link.mapID
		end
	end
	if not (pxU and pxV and pxU > 0 and pxV > 0) then return end
	local best, bestD = nil, reach * reach
	for _, link in ipairs(links or {}) do
		local dx, dy = (u - link.u) / pxU, (v - link.v) / pxV
		local d = dx * dx + dy * dy
		if d < bestD then best, bestD = link.mapID, d end
	end
	return best
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
local linkSet
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

function mod:BuildRegionalLinks()
	local policy = ns.ClientMaps
	if not (policy and policy.awayMaps and S.PinSet and S.AddPin) then return end
	R.links = R.AwayLinks(policy.awayMaps, policy.awayLinks, S.Rect)
	linkSet = linkSet or S.PinSet("regionalLinks", 0, 5)
	S.ClearPinSet(linkSet)
	for _, link in ipairs(R.links) do
		-- The destination is already painted as a large medallion in Quel'Thalas art. This transparent
		-- WorldPane button owns its centre and provides a tooltip; AwayLinkAt owns the whole painted area.
		local pin = S.AddPin(linkSet, link.u, link.v,
			{ texture = "Interface\\Buttons\\WHITE8x8", size = 64, color = { 1, 1, 1, 0 } }, link)
		pin.Icon:SetAlpha(0)
		pin.Highlight:SetAlpha(0)
		pin.openAwayMap = true
		local mapID, name = link.mapID, link.name
		pin.OnClick = function(_, button)
			if not R.IsOpenButton(button or "LeftButton") then return end
			if mod.OpenRegionalMap then mod.OpenRegionalMap(mapID) end
		end
		pin:SetScript("OnEnter", function(self)
			if not GameTooltip then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(name or tostring(mapID), 1, 0.82, 0)
			GameTooltip:Show()
		end)
		pin:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	end
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
