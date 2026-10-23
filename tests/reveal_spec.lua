local revealPath = assert(arg[1], "path to Reveal.lua is required")

local ns = {}
assert(loadfile(revealPath))("WorldPane", ns)
local reveal = assert(ns.MapReveal, "reveal data was not loaded")

-- Representative art roots outside the Azeroth stitch. These ensure a data
-- regeneration cannot silently return to an Azeroth-only preview set.
for _, artID in ipairs({
	105,  -- Hellfire Peninsula (Outland)
	542,  -- Frostfire Ridge (Draenor)
	1306, -- Revendreth (Shadowlands)
	1936, -- Voidstorm
	1942, -- Harandar
}) do
	assert(type(reveal[artID]) == "table" and next(reveal[artID]),
		("missing regional reveal art %d"):format(artID))
end

print("OK: complete cross-world reveal data")
