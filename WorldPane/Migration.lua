--------------------------------------------------------------------------------
-- One-time settings bridge from the pre-WorldPane package identity.
-- The legacy saved-variable names are kept only here so existing users retain
-- their preferences after installing the renamed addon.
--------------------------------------------------------------------------------

local _, ns = ...

local function LoadLegacySavedVariables()
	local loadAddOn = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
	if type(loadAddOn) == "function" then
		pcall(loadAddOn, "AtlasContinuum")
	end

	if _G.WorldPaneDB == nil and type(_G.AtlasContinuumDB) == "table" then
		_G.WorldPaneDB = _G.AtlasContinuumDB
	end
	if _G.WorldPaneCharDB == nil and type(_G.AtlasContinuumCharDB) == "table" then
		_G.WorldPaneCharDB = _G.AtlasContinuumCharDB
	end
	if _G.WorldPaneLabDB == nil and type(_G.AtlasContinuumLabDB) == "table" then
		_G.WorldPaneLabDB = _G.AtlasContinuumLabDB
	end

	if type(_G.WorldPaneDB) == "table" then
		_G.WorldPaneDB._worldPaneMigration = _G.WorldPaneDB._worldPaneMigration or {
			from = "AtlasContinuum",
			version = 1,
		}
	end
end

ns.LoadLegacySavedVariables = LoadLegacySavedVariables
LoadLegacySavedVariables()
