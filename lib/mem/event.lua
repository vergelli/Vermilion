-- VermilionEvent: pooled record passed across pipeline stages. Fixed shape,
-- mutated, never allocated in the hot path. Mirror of Verdant's event schema
-- (SPEC_03 §3.1) with one addition per Vermilion SPEC §7.1: a `result` field
-- carrying the post-mitigation ZOS ACTION_RESULT code, so downstream stages
-- can separate the eDPS / ShDPS branches and support by-result breakdowns
-- later without re-reading the raw ZOS tuple.

Vermilion = Vermilion or {}
Vermilion.lib = Vermilion.lib or {}
Vermilion.lib.mem = Vermilion.lib.mem or {}

local Event = {}
Vermilion.lib.mem.Event = Event

-- Factory: produce a fresh, zero-initialized event. Called once per pool
-- slot at pool construction. After that, fields are overwritten on
-- acquire-and-populate; nothing nils them on release (microopt).
function Event.factory()
  return {
    t              = 0,
    kind           = 0,    -- ABILITY_KIND enum (see core/constants.lua)
    result         = 0,    -- ZOS ACTION_RESULT code (post-mitigation)
    amount         = 0,    -- ZOS `hit` value
    target_unit_id = 0,    -- for the future per-target view
    target_type    = 0,    -- COMBAT_UNIT_TYPE_* (captured; not used for filtering, see filter.lua)
    ability_id     = 0,    -- for skill_colors grouping
    -- _pool_idx written by BufferPool.new
  }
end
