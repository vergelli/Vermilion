Vermilion = Vermilion or {}
local Vermilion = Vermilion

Vermilion.Probe = {}

local d                          = d
local string_format              = string.format
local table_remove               = table.remove
local pairs                      = pairs
local type                       = type
local tostring                   = tostring
local api                        = Vermilion.zenimax.api
local GetGameTimeMilliseconds    = api.GetGameTimeMilliseconds
local GetAPIVersion              = api.GetAPIVersion
local IsUnitGrouped              = api.IsUnitGrouped
local GetGroupSize               = api.GetGroupSize
local GetUnitName                = api.GetUnitName
local GetUnitDisplayName         = api.GetUnitDisplayName
local GetUnitClass               = api.GetUnitClass
local GetUnitRace                = api.GetUnitRace
local GetUnitLevel               = api.GetUnitLevel
local GetUnitChampionPoints      = api.GetUnitChampionPoints
local GetUnitAlliance            = api.GetUnitAlliance
local GetCurrentMapZoneIndex     = api.GetCurrentMapZoneIndex
local GetZoneNameByIndex         = api.GetZoneNameByIndex
local GetSlotName                = api.GetSlotName
local GetSlotBoundId             = api.GetSlotBoundId
local GetAbilityName             = api.GetAbilityName

local C = Vermilion.zenimax.constants
local EVENT_COMBAT_EVENT          = C.EVENT_COMBAT_EVENT
local EVENT_PLAYER_ACTIVATED      = C.EVENT_PLAYER_ACTIVATED
local EVENT_PLAYER_DEACTIVATED    = C.EVENT_PLAYER_DEACTIVATED
local EVENT_PLAYER_COMBAT_STATE   = C.EVENT_PLAYER_COMBAT_STATE
local EVENT_ACTION_SLOT_ABILITY_USED = C.EVENT_ACTION_SLOT_ABILITY_USED
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

local M = Vermilion.Probe

local function new_state()
  return {
    enabled       = false,
    filter        = "all",
    last_chat_ms  = 0,
    last_save_ms  = 0,
    in_combat     = false,
    session_id    = (M.state and M.state.session_id or 0) + 1,
    buffers = {
      damage = {},  -- landed damage from player
      shield = {},  -- DAMAGE_SHIELDED from player
      casts  = {},  -- EVENT_ACTION_SLOT_ABILITY_USED
      combat = {},  -- combat state transitions
    },
    stats = {
      damage=0, shield=0, casts=0, combat=0, noise_dropped=0, autosaves=0,
    },
    universe = {
      abilities = {},  -- [abilityId] = name (first-seen)
      targets   = {},  -- [unitId]    = { name=, lastType= } (first-seen)
    },
    context = nil,
    player_unit_id  = nil,
    session_tag     = nil,
  }
end

local state = new_state()
M.state = state

--* --- Helpers -------------------------------------------------------------

local function now() return GetGameTimeMilliseconds() end

local function should_log(category)
  local f = state.filter
  return f == "all" or f == category
end

local function push(category, entry)
  local buf = state.buffers[category]
  if not buf then return end
  buf[#buf + 1] = entry
  if #buf > Vermilion.Constants.PROBE.BUFFER_LIMIT then
    table_remove(buf, 1)
  end
end

local function chat_emit(line)
  if not state.enabled then return end
  local t = now()
  if t - state.last_chat_ms < Vermilion.Constants.PROBE.CHAT_INTERVAL_MS then return end
  state.last_chat_ms = t
  d("[Vm] " .. line)
end

local function remember_ability(abilityId, abilityName)
  if not abilityId or abilityId == 0 then return end
  if state.universe.abilities[abilityId] == nil then
    state.universe.abilities[abilityId] = abilityName or ""
  end
end

local function remember_target(unitId, name, unitType)
  if not unitId or unitId == 0 then return end
  local prior = state.universe.targets[unitId]
  if prior == nil then
    state.universe.targets[unitId] = { name = name or "", lastType = unitType or 0 }
  elseif unitType then
    prior.lastType = unitType
  end
end

-- --- Combat handlers -----------------------------------------------------

local function classify(result)
  if result == ACTION_RESULT_DAMAGE
    or result == ACTION_RESULT_DOT_TICK
    or result == ACTION_RESULT_CRITICAL_DAMAGE
    or result == ACTION_RESULT_DOT_TICK_CRITICAL
    or result == ACTION_RESULT_BLOCKED_DAMAGE then
    return "damage"
  elseif result == ACTION_RESULT_DAMAGE_SHIELDED then
    return "shield"
  end
  return nil
end

local function on_combat_out(result, isError, abilityName, _g, _slot,
                             sourceName, sourceType, targetName, targetType, hitValue,
                             _pt, _dt, _log, sourceUnitId, targetUnitId, abilityId)
  if isError then return end
  local category = classify(result)
  if not category then return end
  if (hitValue or 0) == 0 then
    state.stats.noise_dropped = state.stats.noise_dropped + 1
    return
  end

  if not state.player_unit_id and sourceType == COMBAT_UNIT_TYPE_PLAYER
     and sourceUnitId and sourceUnitId ~= 0 then
    state.player_unit_id = sourceUnitId
    if state.context and state.context.player then state.context.player.unitId = sourceUnitId end
  end

  remember_ability(abilityId, abilityName)
  remember_target(targetUnitId, targetName, targetType)

  push(category, {
    t          = now(),
    result     = result,
    ability    = abilityName,
    abilityId  = abilityId,
    target     = targetName,
    targetType = targetType,
    targetUnit = targetUnitId,
    hit        = hitValue,
  })
  state.stats[category] = state.stats[category] + 1

  if should_log(category) then
    chat_emit(string_format(
      "%s | r=%d | %s -> %s | hit=%d | tt=%d tuid=%d ab=%d",
      category, result or 0, abilityName or "?", targetName or "?",
      hitValue or 0, targetType or 0, targetUnitId or 0, abilityId or 0
    ))
  end
end

local function on_combat_state(inCombat)
  local entry = { t = now(), inCombat = inCombat and true or false }
  state.in_combat = entry.inCombat
  push("combat", entry)
  state.stats.combat = state.stats.combat + 1
  if should_log("combat") then
    chat_emit(string_format("combat | %s", entry.inCombat and "ENTER" or "EXIT"))
  end
  if not entry.inCombat then M.maybe_autosave() end
end

local function on_action_slot_used(actionSlotIndex)
  local abilityId   = GetSlotBoundId(actionSlotIndex)
  local abilityName = (abilityId and abilityId > 0) and GetAbilityName(abilityId, "player") or GetSlotName(actionSlotIndex)
  remember_ability(abilityId, abilityName)
  push("casts", { t = now(), slot = actionSlotIndex, abilityId = abilityId, abilityName = abilityName })
  state.stats.casts = state.stats.casts + 1
  if should_log("cast") then
    chat_emit(string_format("cast | slot=%d ab=%d %s", actionSlotIndex, abilityId or 0, abilityName or "?"))
  end
end

-- --- Context snapshot ----------------------------------------------------

local function snapshot_bars()
  local bars = {}
  for _, hotbar in ipairs({ HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP }) do
    local slots = {}
    for slot = 3, 8 do
      local abilityId = GetSlotBoundId(slot, hotbar)
      slots[#slots + 1] = {
        slot      = slot,
        abilityId = abilityId,
        name      = (abilityId and abilityId > 0) and GetAbilityName(abilityId, "player") or "",
      }
    end
    bars[#bars + 1] = { hotbar = hotbar, slots = slots }
  end
  return bars
end

function M.snapshot_context()
  local zoneIdx = GetCurrentMapZoneIndex()
  state.context = {
    t           = now(),
    api_version = GetAPIVersion(),
    player = {
      name      = GetUnitName("player"),
      display   = GetUnitDisplayName("player"),
      unitId    = state.player_unit_id or 0,
      level     = GetUnitLevel("player"),
      cp        = GetUnitChampionPoints("player"),
      class     = GetUnitClass("player"),
      race      = GetUnitRace("player"),
      alliance  = GetUnitAlliance("player"),
    },
    zone = { index = zoneIdx, name = zoneIdx and GetZoneNameByIndex(zoneIdx) or "" },
    bars = snapshot_bars(),
  }
end

-- --- Public API ----------------------------------------------------------

function M.set_enabled(v)        state.enabled = v and true or false end
function M.set_filter(category)  state.filter = category end
function M.set_tag(tag)          state.session_tag = tag and tag ~= "" and tag or nil end
function M.get_tag()             return state.session_tag end

function M.clear()
  for k in pairs(state.buffers) do state.buffers[k] = {} end
  for k in pairs(state.stats)   do state.stats[k]   = 0  end
  state.universe = { abilities = {}, targets = {} }
end

function M.format_entry(category, e)
  if category == "damage" or category == "shield" then
    return string_format("t=%d r=%d ab=%s tgt=%s tt=%d tuid=%d hit=%d",
      e.t or 0, e.result or 0, e.ability or "?", e.target or "?",
      e.targetType or 0, e.targetUnit or 0, e.hit or 0)
  elseif category == "casts" then
    return string_format("t=%d slot=%d ab=%d %s",
      e.t or 0, e.slot or 0, e.abilityId or 0, e.abilityName or "?")
  elseif category == "combat" then
    return string_format("t=%d %s", e.t or 0, e.inCombat and "ENTER" or "EXIT")
  end
  return "?"
end

function M.print_stats()
  local s = state.stats
  d(string_format(
    "[Vm] stats: dmg=%d shld=%d cast=%d combat=%d | noise=%d saves=%d",
    s.damage, s.shield, s.casts, s.combat, s.noise_dropped, s.autosaves
  ))
end

function M.dump()
  local total = 0
  for _, buf in pairs(state.buffers) do total = total + #buf end
  if total == 0 then d("[Vm] Probe buffers are empty.") return end
  d("[Vm] === Vermilion probe dump ===")
  M.print_stats()
  for category, buf in pairs(state.buffers) do
    if #buf > 0 then
      d(string_format("[Vm] -- %s (%d) --", category, #buf))
      for i = 1, #buf do
        d(string_format("[Vm]   %s", M.format_entry(category, buf[i])))
      end
    end
  end
end

local function deep_copy(t)
  if type(t) ~= "table" then return t end
  local out = {}
  for k, v in pairs(t) do out[k] = deep_copy(v) end
  return out
end

function M.persist_to_savedvars(sv)
  if not sv then return false end
  sv.probe = sv.probe or {}
  sv.probe.dumps = sv.probe.dumps or {}
  local snapshot = {
    taken_at_ms = now(),
    session_id  = state.session_id,
    session_tag = state.session_tag,
    in_combat   = state.in_combat,
    context     = deep_copy(state.context),
    stats       = deep_copy(state.stats),
    universe    = deep_copy(state.universe),
    buffers     = deep_copy(state.buffers),
    engine      = Vermilion.Diagnostics and deep_copy(Vermilion.Diagnostics.snapshot()) or nil,
  }
  table.insert(sv.probe.dumps, 1, snapshot)
  while #sv.probe.dumps > Vermilion.Constants.PROBE.DUMP_HISTORY_LIMIT do
    sv.probe.dumps[#sv.probe.dumps] = nil
  end
  sv.probe.last_dump = sv.probe.dumps[1]
  state.last_save_ms = now()
  state.stats.autosaves = state.stats.autosaves + 1
  return true
end

function M.maybe_autosave()
  local cooldown = Vermilion.Constants.PROBE.AUTOSAVE_COOLDOWN_MS
  if now() - state.last_save_ms < cooldown then return end
  if Vermilion.SavedVars then M.persist_to_savedvars(Vermilion.SavedVars) end
end

-- --- Wiring --------------------------------------------------------------

function M.init()
  local P = Vermilion.Constants.PROBE
  local E = Vermilion.zenimax.events

  -- 1) Landed damage where I am the source (R_land triaged in the wrapper).
  E.register(P.SRC_DAMAGE_OUT, EVENT_COMBAT_EVENT, function(...)
    local r = ...
    if r == ACTION_RESULT_DAMAGE
       or r == ACTION_RESULT_DOT_TICK
       or r == ACTION_RESULT_CRITICAL_DAMAGE
       or r == ACTION_RESULT_DOT_TICK_CRITICAL
       or r == ACTION_RESULT_BLOCKED_DAMAGE then
      on_combat_out(...)
    end
  end)
  E.add_filter(P.SRC_DAMAGE_OUT, EVENT_COMBAT_EVENT,
    REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
  E.add_filter(P.SRC_DAMAGE_OUT, EVENT_COMBAT_EVENT,
    REGISTER_FILTER_IS_ERROR, false)

  -- 2) Shielded damage where I am the source.
  E.register(P.SRC_SHIELD_OUT, EVENT_COMBAT_EVENT, on_combat_out)
  E.add_filter(P.SRC_SHIELD_OUT, EVENT_COMBAT_EVENT,
    REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_DAMAGE_SHIELDED)
  E.add_filter(P.SRC_SHIELD_OUT, EVENT_COMBAT_EVENT,
    REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
  E.add_filter(P.SRC_SHIELD_OUT, EVENT_COMBAT_EVENT,
    REGISTER_FILTER_IS_ERROR, false)

  -- 3) Combat-state transitions (autosave trigger + episode boundaries).
  E.register(P.SRC_COMBAT_STATE, EVENT_PLAYER_COMBAT_STATE, on_combat_state)

  -- 4) Cast tracking.
  E.register(P.SRC_CAST, EVENT_ACTION_SLOT_ABILITY_USED, on_action_slot_used)

  -- 5) Auto-persist on deactivation (logout / reloadui / zoning).
  E.register(P.SRC_AUTOSAVE, EVENT_PLAYER_DEACTIVATED, function()
    if Vermilion.SavedVars then M.persist_to_savedvars(Vermilion.SavedVars) end
  end)

  -- 6) Context capture on player activation.
  E.register(P.SRC_PLAYER, EVENT_PLAYER_ACTIVATED, function() M.snapshot_context() end)
end
