local clientPath = assert(arg[1], "path to Client.lua is required")

local ns = {}
assert(loadfile(clientPath))("WorldPane", ns)

local policy = assert(ns.ClientMaps, "Retail client policy was not loaded")
assert(policy.cityMiniOf[2393] == 0, "Silvermoon must not receive the outdoor minimap overlay")
assert(policy.awayMaps[2405] == true, "Voidstorm must open as a native map")
assert(policy.awayMaps[2413] == true, "Harandar must open as a native map")
assert((policy.continentPriority[2537] or 0) > 0, "Quel'Thalas must paint above legacy Eastern Kingdoms zones")

print("OK: Retail detached-map and visual-layer policy")
