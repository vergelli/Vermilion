-- pipeline/pipeline.lua
--
-- Orchestrator for the event pipeline (acquisition → filter → processing).
-- Owns ZOS event subscriptions and per-ZOS-event bookkeeping (counters, mode
-- pre-check, profiler spans) that doesn't fit the per-event stage contract.
--
-- Entry points:
--   M.dispatch_damage_out(...)  — combat handler, player landed damage
--   M.dispatch_shield_out(...)  — combat handler, DAMAGE_SHIELDED from player
--   M.init()                    — registers ZOS subscriptions

Vermilion = Vermilion or {}
local Vermilion = Vermilion

Vermilion.Pipeline = Vermilion.Pipeline or {}
local M = Vermilion.Pipeline

local Acquisition = Vermilion.Pipeline.Acquisition
local Filter      = Vermilion.Pipeline.Filter
local Processing  = Vermilion.Pipeline.Processing

local C = Vermilion.zenimax.constants
local EVENT_COMBAT_EVENT          = C.EVENT_COMBAT_EVENT
local REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE = C.REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE
local REGISTER_FILTER_COMBAT_RESULT           = C.REGISTER_FILTER_COMBAT_RESULT
local REGISTER_FILTER_IS_ERROR                = C.REGISTER_FILTER_IS_ERROR
local COMBAT_UNIT_TYPE_PLAYER     = C.COMBAT_UNIT_TYPE_PLAYER
local ACTION_RESULT_DAMAGE            = C.ACTION_RESULT_DAMAGE
local ACTION_RESULT_DOT_TICK          = C.ACTION_RESULT_DOT_TICK
local ACTION_RESULT_CRITICAL_DAMAGE   = C.ACTION_RESULT_CRITICAL_DAMAGE
local ACTION_RESULT_DOT_TICK_CRITICAL = C.ACTION_RESULT_DOT_TICK_CRITICAL
local ACTION_RESULT_BLOCKED_DAMAGE    = C.ACTION_RESULT_BLOCKED_DAMAGE
local ACTION_RESULT_DAMAGE_SHIELDED   = C.ACTION_RESULT_DAMAGE_SHIELDED

local Log = Vermilion.Log.for_module("pipeline")

local prof_enter = Vermilion.Profiler.enter
local prof_exit  = Vermilion.Profiler.exit

local function bump(key) Vermilion.Diagnostics.bump(key) end

local function release(ev)
  if ev then Vermilion.Metrics.release_event(ev) end
end

local now = Acquisition.now

-- Shared body for both kinds: acquire → filter → process, with profiler spans
-- and pool-exhaustion accounting. `acquire_fn` returns a populated event or nil.
local function run_stages(ev, accepted_key)
  if not ev then
    bump("engine.pool.exhausted")
    Log:warn("event pool exhausted")
    return
  end
  prof_enter("pipeline.combat_event.filter")
  local allowed = Filter.allow(ev)
  prof_exit("pipeline.combat_event.filter")
  if allowed then
    bump(accepted_key)
    prof_enter("pipeline.combat_event.processing")
    Processing.process(ev)
    prof_exit("pipeline.combat_event.processing")
  else
    release(ev)
  end
end

-- ── combat: landed damage (eDPS) ───────────────────────────────────────────
-- Signature (16 args): result, isError, abilityName, abilityGraphic,
-- abilityActionSlotType, sourceName, sourceType, targetName, targetType,
-- hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId.
function M.dispatch_damage_out(result, isError, _name, _g, _slot,
                               _src, _sourceType, _tgt, targetType, hit,
                               _pt, _dt, _log, _suid, targetUnitId, abilityId)
  prof_enter("pipeline.combat_event")
  bump("engine.damage.in")
  if isError then bump("engine.damage.dropped_error") prof_exit("pipeline.combat_event") return end
  if (hit or 0) <= 0 then bump("engine.damage.dropped_noise") prof_exit("pipeline.combat_event") return end
  if not Vermilion.Mode.uses("damage") then
    bump("engine.damage.dropped_mode") prof_exit("pipeline.combat_event") return
  end

  local t = now()
  prof_enter("pipeline.combat_event.acquisition")
  local ev = Acquisition.acquire_damage_out(t, hit, targetUnitId, targetType, abilityId, result)
  prof_exit("pipeline.combat_event.acquisition")
  run_stages(ev, "engine.damage.accepted")
  prof_exit("pipeline.combat_event")
end

-- ── combat: shielded damage (ShDPS) ────────────────────────────────────────
function M.dispatch_shield_out(result, isError, _name, _g, _slot,
                               _src, _sourceType, _tgt, targetType, hit,
                               _pt, _dt, _log, _suid, targetUnitId, abilityId)
  prof_enter("pipeline.combat_event")
  bump("engine.shield.in")
  if isError then bump("engine.shield.dropped_error") prof_exit("pipeline.combat_event") return end
  if (hit or 0) <= 0 then bump("engine.shield.dropped_noise") prof_exit("pipeline.combat_event") return end
  if not Vermilion.Mode.uses("shield") then
    bump("engine.shield.dropped_mode") prof_exit("pipeline.combat_event") return
  end

  local t = now()
  prof_enter("pipeline.combat_event.acquisition")
  local ev = Acquisition.acquire_shield_out(t, hit, targetUnitId, targetType, abilityId, result)
  prof_exit("pipeline.combat_event.acquisition")
  run_stages(ev, "engine.shield.accepted")
  prof_exit("pipeline.combat_event")
end

-- ── init: subscribe ZOS events ─────────────────────────────────────────────
function M.init()
  local E = Vermilion.zenimax.events

  Vermilion.Diagnostics.init()
  Vermilion.Metrics.init()

  -- Subscription A: outgoing landed damage. Result triage in the wrapper keeps
  -- the R_land set out of EVENT_MANAGER's single-value COMBAT_RESULT filter.
  E.register("Vermilion_E_DamageOut", EVENT_COMBAT_EVENT, function(...)
    local r = ...
    if r == ACTION_RESULT_DAMAGE
       or r == ACTION_RESULT_DOT_TICK
       or r == ACTION_RESULT_CRITICAL_DAMAGE
       or r == ACTION_RESULT_DOT_TICK_CRITICAL
       or r == ACTION_RESULT_BLOCKED_DAMAGE then
      M.dispatch_damage_out(...)
    end
  end)
  E.add_filter("Vermilion_E_DamageOut", EVENT_COMBAT_EVENT,
    REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
  E.add_filter("Vermilion_E_DamageOut", EVENT_COMBAT_EVENT,
    REGISTER_FILTER_IS_ERROR, false)

  -- Subscription B: outgoing shielded damage. Single result code → use the
  -- native COMBAT_RESULT filter for it.
  E.register("Vermilion_E_ShieldOut", EVENT_COMBAT_EVENT, M.dispatch_shield_out)
  E.add_filter("Vermilion_E_ShieldOut", EVENT_COMBAT_EVENT,
    REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_DAMAGE_SHIELDED)
  E.add_filter("Vermilion_E_ShieldOut", EVENT_COMBAT_EVENT,
    REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
  E.add_filter("Vermilion_E_ShieldOut", EVENT_COMBAT_EVENT,
    REGISTER_FILTER_IS_ERROR, false)

  Log:info("init complete; 2 combat-event handlers registered")
end
