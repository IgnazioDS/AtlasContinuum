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
	parchment100 = { 0.965, 0.925, 0.830, 1.00 },
	parchment300 = { 0.790, 0.730, 0.620, 1.00 },
	bronze500 = { 0.520, 0.390, 0.235, 1.00 },
	bronze700 = { 0.285, 0.205, 0.125, 1.00 },
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
	text = primitive.parchment100,
	textMuted = primitive.parchment300,
	border = primitive.bronze500,
	borderQuiet = primitive.bronze700,
	accent = primitive.gold400,
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
	menu = {
		background = semantic.surfaceStrong,
		backgroundRaised = semantic.surfaceRaised,
		border = semantic.border,
		divider = semantic.borderQuiet,
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
		label = semantic.accent,
		value = semantic.text,
	},
}

local Theme = { primitive = primitive, semantic = semantic, component = component }
ns.Theme = Theme

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

