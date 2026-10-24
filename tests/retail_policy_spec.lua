local clientPath = assert(arg[1], "path to Client.lua is required")

local ns = {}
assert(loadfile(clientPath))("WorldPane", ns)

local policy = assert(ns.ClientMaps, "Retail client policy was not loaded")
assert(policy.cityMiniOf[2393] == 0, "Silvermoon must not receive the outdoor minimap overlay")
assert(policy.awayMaps[2405] == true, "Voidstorm must open as a native map")
assert(policy.awayMaps[2413] == true, "Harandar must open as a native map")
assert(policy.awayLinks[2537][1].mapID == 2405 and policy.awayLinks[2537][2].mapID == 2413,
	"Quel'Thalas must retain complete clickable bounds for both detached map links")
assert((policy.continentPriority[2537] or 0) > 0, "Quel'Thalas must paint above legacy Eastern Kingdoms zones")
assert(policy.detailFade[1] < 3 and policy.detailFade[2] > 6,
	"Retail zone detail must use a wide crossfade across mixed-era artwork")
assert(policy.labelOpacity < 0.8 and policy.labelFade[2] < policy.detailFade[2],
	"large cartographic names must become subordinate before detailed zone art takes over")

print("OK: Retail detached-map and visual-layer policy")
