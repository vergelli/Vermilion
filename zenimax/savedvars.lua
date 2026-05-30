-- Wrapper around ZO_SavedVars. Per SPEC_01, exposes a thin façade so addon
-- code never references ZO_SavedVars directly. Migration hooks let callers
-- evolve the schema across SV_VERSION bumps without leaking ZOS APIs.

Vermilion = Vermilion or {}
Vermilion.zenimax = Vermilion.zenimax or {}
local Vermilion = Vermilion

Vermilion.zenimax.savedvars = {}
local M = Vermilion.zenimax.savedvars

local ZO_SavedVars = ZO_SavedVars

-- Open an account-wide saved-vars table.
--   table_name : the SavedVariables identifier from the manifest
--   version    : current schema version
--   profile    : usually GetWorldName() — namespacing per server
--   defaults   : default value table merged into missing keys
--   migrations : optional [from_version] = function(sv) end map. Each
--                migration is responsible for advancing sv to the next
--                version. Migrations run in ascending order until the
--                current version is reached.
function M.new_account_wide(table_name, version, profile, defaults, migrations)
  local sv = ZO_SavedVars:NewAccountWide(table_name, version, profile, defaults)
  if migrations then
    M.run_migrations(sv, version, migrations)
  end
  return sv
end

-- Apply migrations[from] sequentially until sv.version == target_version.
-- Each migration must update sv.version to the version it migrates to.
function M.run_migrations(sv, target_version, migrations)
  sv.version = sv.version or target_version
  while sv.version < target_version do
    local step = migrations[sv.version]
    if not step then break end
    step(sv)
  end
end
