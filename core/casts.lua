Vermilion = Vermilion or {}
local Vermilion = Vermilion

Vermilion.Casts = {}
local M = Vermilion.Casts

local log = Vermilion.Log.for_module("casts")

local CAP = 4000
local COST_CAP = 65535
local MAG, STA = 1, 2

local recording = false
local n = 0
local cast_t, cast_id, cast_pool, cast_cost = {}, {}, {}, {}
local acc = {}

local function bump(key) Vermilion.Diagnostics.bump(key) end

local function now_ms() return Vermilion.zenimax.api.GetGameTimeMilliseconds() end

local function slot_cost(api, zc, slot, cat)
  local cm = zc.COMBAT_MECHANIC_FLAGS_MAGICKA and api.GetSlotAbilityCost(slot, zc.COMBAT_MECHANIC_FLAGS_MAGICKA, cat) or 0
  local cs = zc.COMBAT_MECHANIC_FLAGS_STAMINA and api.GetSlotAbilityCost(slot, zc.COMBAT_MECHANIC_FLAGS_STAMINA, cat) or 0
  cm, cs = cm or 0, cs or 0
  if cm <= 0 and cs <= 0 then return 0, 0 end
  if cm >= cs then return MAG, cm end
  return STA, cs
end

function M.on_used(slot)
  bump("casts.used")
  if not recording or n >= CAP then return end
  local api, zc = Vermilion.zenimax.api, Vermilion.zenimax.constants
  if not (api.GetSlotBoundId and api.GetSlotAbilityCost) then return end
  local cat = api.GetActiveHotbarCategory and api.GetActiveHotbarCategory() or zc.HOTBAR_CATEGORY_PRIMARY
  local id = api.GetSlotBoundId(slot, cat) or 0
  if id <= 0 then return end
  local pool, cost = slot_cost(api, zc, slot, cat)
  if cost > COST_CAP then cost = COST_CAP end
  n = n + 1
  cast_t[n], cast_id[n], cast_pool[n], cast_cost[n] = now_ms(), id, pool, cost
end

function M.start_session()
  recording = true
  n = 0
end

function M.finalize()
  if not recording then return end
  recording = false
  log:info("session finalize: casts=", n)
end

function M.reset()
  recording = false
  n = 0
end

function M.records() return cast_t, cast_id, cast_pool, cast_cost, n end
function M.count() return n end
function M.is_recording() return recording end

function M.load_session(recs)
  M.reset()
  recs = recs or {}
  for i = 1, #recs do
    local r = recs[i]
    cast_t[i]    = r.t or 0
    cast_id[i]   = r.id or 0
    cast_pool[i] = r.pool or 0
    cast_cost[i] = r.cost or 0
  end
  n = #recs
  log:info("session loaded: casts=", n)
end

function M.spend_top(t_lo, t_hi, pool)
  for k in pairs(acc) do acc[k] = nil end
  local best_id, best = 0, 0
  for i = 1, n do
    local t = cast_t[i]
    if t >= t_lo and t <= t_hi and cast_cost[i] > 0 and (pool == nil or cast_pool[i] == pool) then
      local id = cast_id[i]
      local v = (acc[id] or 0) + cast_cost[i]
      acc[id] = v
      if v > best then best, best_id = v, id end
    end
  end
  return best_id, best
end

function M.report_lines()
  return {
    string.format("casts=%d recording=%s used_events=%d", n, tostring(recording), Vermilion.Diagnostics.get("casts.used")),
  }
end

function M.init()
  local zev, zc = Vermilion.zenimax.events, Vermilion.zenimax.constants
  if not zc.EVENT_ACTION_SLOT_ABILITY_USED then
    log:warn("no ability-used event on this client; cast tracker disabled")
    return
  end
  local first = (zc.ACTION_BAR_FIRST_NORMAL_SLOT_INDEX or 2) + 1
  local last  = zc.ACTION_BAR_ULTIMATE_SLOT_INDEX or 7
  zev.register("Vermilion_E_CastUsed", zc.EVENT_ACTION_SLOT_ABILITY_USED, function(slot)
    if slot and slot >= first and slot <= last then M.on_used(slot) end
  end)
  log:info("init: skill slots", first, "to", last)
end
