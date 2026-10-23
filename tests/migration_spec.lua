local migrationPath = assert(arg[1], "path to Migration.lua is required")

local loaded
C_AddOns = {
	LoadAddOn = function(name)
		loaded = name
	end,
}

AtlasContinuumDB = { worldmap = { alpha = 0.75 } }
AtlasContinuumCharDB = { worldmap = { reopen = "player" } }
AtlasContinuumLabDB = { lastAudit = { build = "legacy" } }

local ns = {}
assert(loadfile(migrationPath))("WorldPane", ns)

assert(loaded == "AtlasContinuum", "legacy helper was not requested")
assert(WorldPaneDB == AtlasContinuumDB, "account settings were not adopted")
assert(WorldPaneCharDB == AtlasContinuumCharDB, "character settings were not adopted")
assert(WorldPaneLabDB == AtlasContinuumLabDB, "audit history was not adopted")
assert(WorldPaneDB._worldPaneMigration.version == 1, "migration marker is missing")

local existing = { worldmap = { alpha = 1 } }
WorldPaneDB = existing
AtlasContinuumDB = { worldmap = { alpha = 0.1 } }
ns.LoadLegacySavedVariables()
assert(WorldPaneDB == existing, "existing WorldPane settings were overwritten")

print("OK: Migration.lua behavior")
