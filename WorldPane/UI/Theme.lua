--------------------------------------------------------------------------------
-- WorldPane visual system
--
-- Raw colours live in primitives, intent lives in semantic aliases, and widgets
-- consume component tokens. Keeping the three layers here prevents the map chrome,
-- floating menu and information pills from drifting into unrelated visual styles.
--------------------------------------------------------------------------------

local _, ns = ...

local primitive = {
	ink1000 = { 0.018, 0.016, 0.014, 0.99 },
	ink950 = { 0.030, 0.027, 0.024, 0.96 },
	ink900 = { 0.050, 0.044, 0.038, 0.94 },
	ink800 = { 0.085, 0.072, 0.058, 0.90 },
	ink700 = { 0.135, 0.108, 0.078, 0.88 },
	parchment100 = { 0.965, 0.925, 0.830, 1.00 },
	parchment300 = { 0.790, 0.730, 0.620, 1.00 },
	parchment500 = { 0.610, 0.555, 0.465, 1.00 },
	bronze500 = { 0.520, 0.390, 0.235, 1.00 },
	bronze700 = { 0.285, 0.205, 0.125, 1.00 },
	gold300 = { 1.000, 0.870, 0.455, 1.00 },
	gold400 = { 1.000, 0.790, 0.275, 1.00 },
	gold500 = { 0.900, 0.660, 0.235, 1.00 },
	black = { 0, 0, 0, 1 },
	white = { 1, 1, 1, 1 },
}

local semantic = {
	surface = primitive.ink950,
	surfaceStrong = primitive.ink1000,
	surfaceRaised = primitive.ink900,
	surfaceHover = primitive.ink800,
	surfaceSelected = primitive.ink700,
	text = primitive.parchment100,
	textMuted = primitive.parchment300,
	textSubtle = primitive.parchment500,
	border = primitive.bronze500,
	borderQuiet = primitive.bronze700,
	borderBright = primitive.gold500,
	accent = primitive.gold400,
	accentBright = primitive.gold300,
	accentMuted = primitive.gold500,
	shadow = primitive.black,
}

local component = {
	mapHeader = {
		background = semantic.surface,
		border = semantic.border,
		accent = semantic.accent,
		text = semantic.text,
		muted = semantic.textMuted,
	},
	transitionCard = {
		background = semantic.surfaceStrong,
		border = semantic.border,
		accent = semantic.accentBright,
		text = semantic.text,
		muted = semantic.textMuted,
	},
	menu = {
		background = semantic.surfaceStrong,
		backgroundRaised = semantic.surfaceRaised,
		border = semantic.border,
		divider = semantic.borderQuiet,
	},
	navTab = {
		background = semantic.surface,
		backgroundHover = semantic.surfaceHover,
		backgroundSelected = semantic.surfaceSelected,
		border = semantic.borderQuiet,
		borderSelected = semantic.borderBright,
		text = semantic.textMuted,
		textSelected = semantic.accentBright,
	},
	actionTile = {
		background = semantic.surfaceRaised,
		backgroundActive = semantic.surfaceHover,
		border = semantic.borderQuiet,
		borderActive = semantic.accent,
		hover = semantic.accent,
	},
	infoPill = {
		background = semantic.surfaceStrong,
		border = semantic.borderQuiet,
		accent = semantic.accent,
		divider = semantic.borderQuiet,
		label = semantic.accent,
		value = semantic.text,
	},
}

local spacing = { hairline = 1, xs = 4, sm = 8, md = 12, lg = 16, xl = 24 }
local motion = {
	fast = 0.12,
	enter = 0.16,
	hold = 0.14,
	exit = 0.26,
	zoomFrequency = 17,
	glideMin = 0.28,
	glideMax = 0.52,
	locationDwell = 0.34,
	locationTransition = 0.58,
}

local Theme = { primitive = primitive, semantic = semantic, component = component, spacing = spacing, motion = motion }
ns.Theme = Theme

-- An exact critically damped spring step. Zoom uses this in logarithmic space,
-- so repeated wheel notches add to one continuous movement without overshoot or
-- the velocity reset that makes conventional ease-out animation feel sticky.
function Theme.CriticalDamped(value, velocity, target, frequency, elapsed)
	value = tonumber(value) or 0
	velocity = tonumber(velocity) or 0
	target = tonumber(target) or value
	frequency = math.max(0.001, tonumber(frequency) or motion.zoomFrequency)
	elapsed = math.max(0, tonumber(elapsed) or 0)
	local delta = value - target
	local decay = math.exp(-frequency * elapsed)
	local impulse = (velocity + frequency * delta) * elapsed
	return target + (delta + impulse) * decay, (velocity - frequency * impulse) * decay
end

function Theme.SetColor(target, method, color, alpha)
	if not (target and target[method] and color) then return end
	target[method](target, color[1], color[2], color[3], alpha or color[4] or 1)
end

function Theme.Backdrop(frame, spec, alpha)
	if not (frame and frame.SetBackdrop and spec) then return end
	frame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 1,
	})
	Theme.SetColor(frame, "SetBackdropColor", spec.background, alpha)
	Theme.SetColor(frame, "SetBackdropBorderColor", spec.border)
end

