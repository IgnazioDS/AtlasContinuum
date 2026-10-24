--------------------------------------------------------------------------------
-- WorldPane's core: saved settings, events, chat output, options plumbing and
-- the few look helpers the map uses. Loaded first; the map files (Map/*.lua)
-- add a module with ns:NewModule and Init.lua starts it at login.
--
-- Settings: WorldPaneDB (account), WorldPaneCharDB (per character), filled from
-- the module's defaults (missing keys only, so new defaults reach old saves).
--------------------------------------------------------------------------------

local ADDON, ns = ...
_G.WorldPane = ns

ns.name = ADDON
ns.version = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)(ADDON, "Version") or "dev"
if ns.version:find("^@") then ns.version = "dev" end   -- (a checkout: the packager fills it in for releases)
ns.ACCENT = "e6b85c"
-- where players send reports (the "Report a problem" button shows it to copy)
ns.ISSUES_URL = "https://github.com/IgnazioDS/WorldPane/issues"
ns.Media = { path = "Interface\\AddOns\\" .. ADDON .. "\\Media\\" }
ns.Media.icon = ns.Media.path .. "Brand\\Icon"
-- the textures are each client's own (Data\<client>\Client.lua, loaded before this, names it)
ns.Media.tex = ns.Media.path .. "Textures\\" .. ns.Client .. "\\"

-- Translations: ns.L["English text"] gives the text for the player's language once a
-- translation fills it in (none yet), else the English. Place names come from the game.
ns.L = setmetatable({}, { __index = function(_, k) return k end })

function ns:Print(fmt, ...)
	local msg = select("#", ...) > 0 and fmt:format(...) or tostring(fmt)
	DEFAULT_CHAT_FRAME:AddMessage("|cff" .. ns.ACCENT .. "WorldPane|r: " .. msg)
end

--------------------------------------------------------------------------------
-- Secret-safe reads (clients with secret values, e.g. WoW Forever)
--------------------------------------------------------------------------------

local Safe = {}
ns.Safe = Safe

function Safe.IsSecret(v)
	return issecretvalue ~= nil and issecretvalue(v) or false
end

function Safe.Value(v)
	if issecretvalue and issecretvalue(v) then return nil end
	return v
end

-- a position's x, y: Blizzard's vectors have GetXY, but some APIs on this client hand back
-- a plain { x, y } table
function Safe.XY(vec)
	if type(vec) ~= "table" then return end
	if vec.GetXY then return vec:GetXY() end
	return vec.x, vec.y
end

-- calls fn(...) and returns its first result when it is plain, else nil
function Safe.Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, v = pcall(fn, ...)
	if not ok then return nil end
	return Safe.Value(v)
end

--------------------------------------------------------------------------------
-- Events: any number of handlers per event, keyed by owner
--------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local handlers = {}
eventFrame:SetScript("OnEvent", function(_, event, ...)
	for owner, fn in pairs(handlers[event] or {}) do
		local ok, err = pcall(fn, owner, event, ...)
		if not ok then geterrorhandler()(err) end
	end
end)

function ns.RegisterEvent(owner, event, fn)
	if not handlers[event] then
		if not pcall(eventFrame.RegisterEvent, eventFrame, event) then return false end
		handlers[event] = {}
	end
	handlers[event][owner] = fn or owner[event]
	return true
end

function ns.UnregisterEvent(owner, event)
	local list = handlers[event]
	if not list then return end
	list[owner] = nil
	if next(list) == nil then
		handlers[event] = nil
		eventFrame:UnregisterEvent(event)
	end
end

--------------------------------------------------------------------------------
-- Modules (WorldPane has one, "worldmap")
--------------------------------------------------------------------------------

ns.modules = {}

function ns:NewModule(key, spec)
	local mod = spec or {}
	mod.key = key
	mod.defaults = mod.defaults or {}
	if mod.defaults.enabled == nil then mod.defaults.enabled = true end
	ns.modules[key] = mod
	return mod
end

function ns:GetModule(key)
	return ns.modules[key]
end

-- missing keys from defaults, recursively
local function Fill(t, defaults)
	for k, v in pairs(defaults) do
		if t[k] == nil then
			t[k] = type(v) == "table" and Fill({}, v) or v
		elseif type(v) == "table" and type(t[k]) == "table" then
			Fill(t[k], v)
		end
	end
	return t
end

function ns:InitDB()
	WorldPaneDB = WorldPaneDB or {}
	WorldPaneCharDB = WorldPaneCharDB or {}
	for key, mod in pairs(ns.modules) do
		mod.fresh = WorldPaneDB[key] == nil       -- (no saved settings yet: a new install)
		-- (an old save's settings carried to the keys that replace them, before the defaults fill those)
		if not mod.fresh and mod.Migrate then mod.Migrate(WorldPaneDB[key]) end
		WorldPaneDB[key] = Fill(WorldPaneDB[key] or {}, mod.defaults)
		WorldPaneCharDB[key] = WorldPaneCharDB[key] or {}
		mod.db, mod.char = WorldPaneDB[key], WorldPaneCharDB[key]
	end
end

function ns:EnableModules()
	for _, mod in pairs(ns.modules) do
		if mod.db.enabled and not mod.enabled then
			mod.enabled = true
			if mod.OnEnable then
				local ok, err = pcall(mod.OnEnable, mod)
				if not ok then
					mod.enabled = false
					ns:Print("|cffff6060failed to start|r: %s", tostring(err):sub(1, 300))
					geterrorhandler()(err)
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Options (AceConfig tables)
--------------------------------------------------------------------------------

-- get / set for options stored in getTable(info)[key]; refresh() after a change
function ns.Bind(getTable, refresh)
	local function get(info)
		local v = getTable(info)[info[#info]]
		if info.type == "color" then
			v = v or { 1, 1, 1, 1 }
			return v[1], v[2], v[3], v[4] or 1
		end
		return v
	end
	local function set(info, a, b, c, d)
		local t = getTable(info)
		if info.type == "color" then
			t[info[#info]] = { a, b, c, d or 1 }
		else
			t[info[#info]] = a
		end
		if refresh then refresh(info) end
	end
	return get, set
end

function ns.Header(name, order)
	return { type = "header", name = name, order = order }
end

function ns.Desc(text, order)
	return { type = "description", name = text, order = order, fontSize = "medium" }
end

--------------------------------------------------------------------------------
-- Look: fonts and the shared WorldPane surface treatment (other addons may
-- restyle these: every panel is frame.omBackdrop, every font goes through
-- ns.Look:Font). Theme.lua loads after Core.lua; these helpers resolve it when
-- a widget is built, after all addon files have loaded.
--------------------------------------------------------------------------------

local Look = {}
ns.Look = Look

function Look:Font(fs, size, flags)
	if not fs:SetFont(STANDARD_TEXT_FONT, size or 12, flags or "") then
		fs:SetFontObject(GameFontHighlight)
	end
	fs:SetShadowColor(0, 0, 0, 1)
	fs:SetShadowOffset(1, -1)
	return fs
end

-- a dark backdrop with a thin border behind `frame`; opts: inset, alpha
function Look:Panel(frame, opts)
	opts = opts or {}
	local bd = frame.omBackdrop
	if not bd then
		bd = CreateFrame("Frame", nil, frame, "BackdropTemplate")
		bd:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
		frame.omBackdrop = bd
	end
	local inset = opts.inset or 0
	bd:ClearAllPoints()
	bd:SetPoint("TOPLEFT", -inset, inset)
	bd:SetPoint("BOTTOMRIGHT", inset, -inset)
	bd:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
	local theme = ns.Theme
	local face = theme and theme.semantic.surface or { 0.03, 0.027, 0.024, 1 }
	local edge = theme and theme.semantic.borderQuiet or { 0.28, 0.20, 0.12, 1 }
	bd:SetBackdropColor(face[1], face[2], face[3], opts.alpha or 0.94)
	bd:SetBackdropBorderColor(edge[1], edge[2], edge[3], 0.95)
	if opts.shadow ~= false and not bd.omShadow then
		local shadow = bd:CreateTexture(nil, "BACKGROUND", nil, -1)
		shadow:SetPoint("TOPLEFT", -5, 5)
		shadow:SetPoint("BOTTOMRIGHT", 5, -5)
		shadow:SetColorTexture(0, 0, 0, 0.34)
		bd.omShadow = shadow
	end
	return bd
end

-- A compact dropdown surface using the same materials as the map chrome.
-- Returns the room to leave inside it: left, top, right, bottom
function Look:Dropdown(frame)
	local bd = Look:Panel(frame, { alpha = 0.97 })
	local accent = ns.Theme and ns.Theme.semantic.border or { 0.52, 0.39, 0.24, 1 }
	bd:SetBackdropBorderColor(accent[1], accent[2], accent[3], 0.92)
	return 8, 8, 8, 8
end

-- A WorldPane window: obsidian surface, restrained bronze edge, raised title
-- strip and a thin gold rule. Keeping this independent of Blizzard's nine-slice
-- art gives all WorldPane tools the same visual identity across Retail updates.
-- Returns the title bar's height (content starts below it), the title and the close button.
function Look:Window(frame, title, onClose)
	local top = 34
	Look:Panel(frame, { alpha = 0.975 })
	local theme = ns.Theme
	local raised = theme and theme.semantic.surfaceRaised or { 0.08, 0.07, 0.06, 1 }
	local accent = theme and theme.semantic.accent or { 1, 0.79, 0.28, 1 }
	local header = frame:CreateTexture(nil, "BACKGROUND")
	header:SetPoint("TOPLEFT", 1, -1)
	header:SetPoint("TOPRIGHT", -1, -1)
	header:SetHeight(top - 1)
	header:SetColorTexture(raised[1], raised[2], raised[3], 0.96)
	local rule = frame:CreateTexture(nil, "ARTWORK")
	rule:SetPoint("TOPLEFT", 1, -top)
	rule:SetPoint("TOPRIGHT", -1, -top)
	rule:SetHeight(1)
	rule:SetColorTexture(accent[1], accent[2], accent[3], 0.68)
	local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	Look:Font(text, 12, "OUTLINE")
	text:SetPoint("TOPLEFT", 34, -9)
	text:SetPoint("TOPRIGHT", -34, -9)
	text:SetJustifyH("CENTER")
	text:SetWordWrap(false)
	text:SetTextColor(accent[1], accent[2], accent[3], 1)
	text:SetText(title or "")
	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetFrameLevel(frame:GetFrameLevel() + 20)
	close:SetHitRectInsets(-4, -4, -4, -4)
	close:SetPoint("TOPRIGHT", 1, 0)
	close:SetScript("OnClick", onClose or function() frame:Hide() end)
	return top, text, close
end
