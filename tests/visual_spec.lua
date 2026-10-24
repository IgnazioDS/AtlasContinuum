local themePath = assert(arg[1], "path to Theme.lua is required")
local visualPath = assert(arg[2], "path to Visual.lua is required")

WORLD_MAP = "World Map"

local maps = {
	[946] = { mapID = 946, name = "Cosmic", parentMapID = 0 },
	[947] = { mapID = 947, name = "Azeroth", parentMapID = 946 },
	[13] = { mapID = 13, name = "Eastern Kingdoms", parentMapID = 947 },
	[2537] = { mapID = 2537, name = "Quel'Thalas", parentMapID = 13 },
	[2405] = { mapID = 2405, name = "Voidstorm", parentMapID = 2537 },
}

C_Map = { GetMapInfo = function(mapID) return maps[mapID] end }

local module = { defaults = {} }
local ns = {
	GetModule = function(_, key)
		assert(key == "worldmap")
		return module
	end,
}

assert(loadfile(themePath))("WorldPane", ns)
assert(loadfile(visualPath))("WorldPane", ns)

local theme = assert(ns.Theme)
assert(theme.component.mapHeader.background == theme.semantic.surface,
	"component surfaces must resolve through semantic tokens")
assert(theme.semantic.accent == theme.primitive.gold400,
	"the interaction accent must resolve through a primitive token")

local visual = assert(ns.MapVisual)
local title, path, chain = visual.Breadcrumb(2405)
assert(title == "Voidstorm", "the current map must lead the context header")
assert(path == "Cosmic  ›  Azeroth  ›  Eastern Kingdoms  ›  Quel'Thalas",
	"the parent hierarchy must read from broadest to nearest")
assert(#chain == 5 and chain[#chain].mapID == 2405,
	"the breadcrumb chain must retain ordered map IDs for future interaction")

assert(visual.ZoomProgress(1) == 0, "the fitted map must begin the zoom meter")
assert(math.abs(visual.ZoomProgress(8) - 0.5) < 0.00001, "8x must be the midpoint of a 1x-64x logarithmic meter")
assert(visual.ZoomProgress(128) == 1, "the zoom meter must clamp beyond its visual range")
assert(visual.TransitionAlpha(0, 0.5) == 1, "a transition must begin fully visible")
assert(visual.TransitionAlpha(0.5, 0.5) == 0, "a transition must finish fully clear")

assert(module.defaults.visualHeader and module.defaults.visualVignette
	and module.defaults.visualGrain and module.defaults.visualTransitions,
	"the complete visual system must be enabled by default")

print("OK: visual tokens, hierarchy, zoom meter and transition easing")

-- Exercise the actual visual setup against a small Retail UI model. The mock
-- intentionally validates blend modes: WoW's texture API accepts BLEND/ADD/MOD
-- style modes, while OVERLAY is a draw layer and aborts addon initialization.
local function Widget(kind)
	local widget = { kind = kind, shown = true, width = 0 }
	function widget:CreateTexture()
		return Widget("texture")
	end
	function widget:CreateFontString()
		return Widget("font")
	end
	function widget:SetBlendMode(mode)
		assert(mode == "BLEND" or mode == "ADD" or mode == "MOD" or mode == "DISABLE" or mode == "ALPHAKEY",
			"invalid Retail texture blend mode: " .. tostring(mode))
	end
	function widget:SetScript(script, callback)
		self.scripts = self.scripts or {}
		self.scripts[script] = callback
	end
	function widget:SetShown(shown) self.shown = shown end
	function widget:Show() self.shown = true end
	function widget:Hide() self.shown = false end
	function widget:SetWidth(width) self.width = width end
	setmetatable(widget, { __index = function(_, key)
		if key:match("^Set") or key:match("^Clear") or key:match("^Enable") then return function() end end
	end })
	return widget
end

local scroll = Widget("scroll")
scroll.baseScale = 1
function scroll:GetFrameLevel() return 20 end
function scroll:GetCanvasScale() return 2 end

local worldMap = Widget("map")
function worldMap:GetMapID() return 2405 end
function worldMap:AddDataProvider(provider) self.provider = provider end

CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end
CreateFrame = function(kind, name, parent) return Widget(kind) end
CreateFromMixins = function() return {} end
MapCanvasDataProviderMixin = {}
ns.Media = { icon = "WorldPaneIcon", tex = "WorldPaneTextures\\" }
ns.Look = { Font = function(_, font) return font end }
module.db = {}
for key, value in pairs(module.defaults) do module.db[key] = value end
module.ViewNow = function() return nil, nil, 2 end

local actualMap = setmetatable({ ScrollContainer = scroll }, { __index = worldMap })
module:SetupVisual(actualMap)
assert(actualMap.provider, "visual setup must register its map data provider")

print("OK: visual layer initializes against the Retail UI contract")

