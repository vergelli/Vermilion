--* pipeline/filter.lua

Vermilion = Vermilion or {}
local Vermilion = Vermilion

Vermilion.Pipeline = Vermilion.Pipeline or {}
Vermilion.Pipeline.Filter = {}
local M = Vermilion.Pipeline.Filter

local bump = Vermilion.Diagnostics.bump   -- no-op in release (DEBUG=false)
local KIND_DAMAGE_OUT = Vermilion.Constants.ABILITY_KIND.DAMAGE_OUT

-- Source-attribution guard. amount > 0 and result code are enforced upstream;
-- here we reject engine mis-attribution: env/world damage carries no real
-- source unit (sourceUnitId == 0) yet leaks through the PLAYER source filter.
--
-- SCOPED TO DAMAGE_OUT ONLY. For ACTION_RESULT_DAMAGE_SHIELDED the engine
-- reports unreliable source fields (LibCombat reassigns sourceUnitId =
-- targetUnitId for it, LibCombat.lua:3687), so a `suid <= 0` test on the shield
-- path could drop legit ShDPS. The confirmed env leak (anglerfish) is plain
-- damage. Broaden to shields only after verifying their source semantics.
function M.allow(ev)
  if ev.kind == KIND_DAMAGE_OUT and (ev.source_unit_id or 0) <= 0 then
    bump("filter.dropped_env")   -- e.g. Battleground anglerfish
    return false
  end
  return true
end
