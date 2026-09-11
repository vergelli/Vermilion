Vermilion = Vermilion or {}
local Vermilion = Vermilion

Vermilion.Trace = {}
local M = Vermilion.Trace

local NOOP = function() end
M.start       = NOOP
M.stop        = NOOP
M.save        = NOOP
M.clear       = NOOP
M.init        = NOOP
M.on_record   = NOOP
M.on_stop     = NOOP
M.set_auto    = NOOP
M.auto_enabled = function() return false end
M.flag        = function() return nil end
M.status_line = function() return "trace disabled (DEBUG=false)" end

if not (Vermilion.Constants.DEBUG or Vermilion.Constants.RESEARCH) then return end

local d       = d
local select  = select
local type    = type
local api     = Vermilion.zenimax.api
local zev     = Vermilion.zenimax.events
local C       = Vermilion.zenimax.constants
local GetGameTimeMilliseconds = api.GetGameTimeMilliseconds

local CAP       = 40000
local CHUNK_MAX = 1800
local RING      = Vermilion.Constants.RESEARCH and 6 or 3
local FLAG_MAX  = 1500
local FLAGS_CAP = 40
local RESEARCH  = Vermilion.Constants.RESEARCH == true

local CONST_NAMES = {
  "ACTION_RESULT_DAMAGE", "ACTION_RESULT_CRITICAL_DAMAGE", "ACTION_RESULT_DOT_TICK",
  "ACTION_RESULT_DOT_TICK_CRITICAL", "ACTION_RESULT_BLOCKED_DAMAGE",
  "ACTION_RESULT_FALL_DAMAGE", "ACTION_RESULT_DAMAGE_SHIELDED",
  "ACTION_RESULT_HEAL", "ACTION_RESULT_CRITICAL_HEAL", "ACTION_RESULT_HOT_TICK",
  "ACTION_RESULT_HOT_TICK_CRITICAL", "ACTION_RESULT_HEAL_ABSORBED",
  "EFFECT_RESULT_GAINED", "EFFECT_RESULT_FADED", "EFFECT_RESULT_UPDATED",
  "EFFECT_RESULT_FULL_REFRESH", "EFFECT_RESULT_TRANSFER",
  "POWERTYPE_HEALTH", "BUFF_EFFECT_TYPE_BUFF", "BUFF_EFFECT_TYPE_DEBUFF",
  "COMBAT_UNIT_TYPE_PLAYER", "COMBAT_UNIT_TYPE_PLAYER_PET",
  "COMBAT_UNIT_TYPE_GROUP", "COMBAT_UNIT_TYPE_OTHER",
  "DAMAGE_TYPE_NONE", "DAMAGE_TYPE_GENERIC", "DAMAGE_TYPE_PHYSICAL", "DAMAGE_TYPE_FIRE",
  "DAMAGE_TYPE_SHOCK", "DAMAGE_TYPE_OBLIVION", "DAMAGE_TYPE_COLD", "DAMAGE_TYPE_EARTH",
  "DAMAGE_TYPE_MAGIC", "DAMAGE_TYPE_DROWN", "DAMAGE_TYPE_DISEASE", "DAMAGE_TYPE_POISON",
  "DAMAGE_TYPE_BLEED",
}

local lines   = {}
local n       = 0
local active  = false
local own_uid = 0
local nflags  = 0

local function player_identity()
  local G = _G
  local raw  = (G.GetRawUnitName and G.GetRawUnitName("player")) or ""
  local name = api.GetUnitName("player") or ""
  local disp = (G.GetDisplayName and G.GetDisplayName()) or ""
  return raw, name, disp
end

local function fld(v)
  local tv = type(v)
  if v == nil then return "" end
  if tv == "boolean" then return v and "T" or "F" end
  if tv == "number" then return tostring(v) end
  return (tostring(v):gsub("[\t\n]", " "))
end

local function rec(tag, ...)
  if not active then return end
  if n >= CAP then
    active = false
    d("[trace] capacity reached (" .. CAP .. "), capture stopped")
    return
  end
  local parts = { tag, tostring(GetGameTimeMilliseconds()) }
  local argc = select("#", ...)
  for i = 1, argc do
    parts[#parts + 1] = fld((select(i, ...)))
  end
  n = n + 1
  lines[n] = table.concat(parts, "\t")
end

local function rec_group()
  local names = {}
  local size = api.GetGroupSize() or 0
  local player_slot = 0
  for i = 1, size do
    names[i] = (api.GetUnitName("group" .. i) or ""):gsub("[|\t\n]", " ")
    if api.AreUnitsEqual and api.AreUnitsEqual("group" .. i, "player") then player_slot = i end
  end
  rec("GR", api.IsUnitGrouped("player"), size, table.concat(names, "|"), player_slot)
end

local function rec_bosses()
  local names = {}
  if C.BOSS_RANK_ITERATION_BEGIN and api.DoesUnitExist then
    for i = C.BOSS_RANK_ITERATION_BEGIN, C.BOSS_RANK_ITERATION_END do
      local tag = "boss" .. i
      if api.DoesUnitExist(tag) then
        names[#names + 1] = (api.GetUnitName(tag) or ""):gsub("[|\t\n]", " ")
      end
    end
  end
  rec("BO", table.concat(names, "|"))
end

local function rec_identity()
  local raw, name, disp = player_identity()
  rec("ID", raw, name, disp, own_uid)
  rec("ZN", (api.GetUnitZone and api.GetUnitZone("player")) or "")
end

function M.start()
  active = true
  nflags = 0
  rec_identity()
  rec_group()
  rec_bosses()
  d("[trace] capturing (" .. n .. "/" .. CAP .. " events)")
end

function M.stop()
  active = false
  d("[trace] stopped at " .. n .. " events")
end

function M.clear(sv)
  lines  = {}
  n      = 0
  active = false
  if sv then
    sv.trace  = nil
    sv.traces = nil
  end
end

local function reset()
  lines  = {}
  n      = 0
  active = false
  nflags = 0
end

function M.flag(snapshot, sv)
  snapshot = tostring(snapshot or "")
  if #snapshot > FLAG_MAX then snapshot = snapshot:sub(1, FLAG_MAX) end
  if active then
    nflags = nflags + 1
    rec("FL", snapshot)
    return "trace", nflags
  end
  if not sv then return nil end
  sv.evidence = sv.evidence or { flags = {} }
  sv.evidence.flags = sv.evidence.flags or {}
  local fl = sv.evidence.flags
  fl[#fl + 1] = {
    ts   = (api.GetTimeStamp and api.GetTimeStamp()) or 0,
    t    = GetGameTimeMilliseconds(),
    zone = (api.GetUnitZone and api.GetUnitZone("player")) or "",
    text = snapshot,
  }
  while #fl > FLAGS_CAP do table.remove(fl, 1) end
  return "staged", #fl
end

function M.flags_staged(sv)
  local fl = sv and sv.evidence and sv.evidence.flags
  return fl and #fl or 0
end

function M.own_uid() return own_uid end

function M.save(sv)
  local chunks = {}
  local buf, blen = {}, 0
  for i = 1, n do
    local llen = #lines[i] + 1
    if blen + llen > CHUNK_MAX and #buf > 0 then
      chunks[#chunks + 1] = table.concat(buf, "\n")
      buf, blen = {}, 0
    end
    buf[#buf + 1] = lines[i]
    blen = blen + llen
  end
  if #buf > 0 then chunks[#chunks + 1] = table.concat(buf, "\n") end
  local consts = { API_VERSION = api.GetAPIVersion() }
  for _, k in ipairs(CONST_NAMES) do
    consts[k] = rawget(_G, k)
  end
  local temporal = sv.temporal or {}
  local raw, name, disp = player_identity()
  local entry = {
    version   = 2,
    build     = Vermilion.Constants.VERSION,
    research  = RESEARCH,
    player    = { raw = raw, name = name, display = disp, uid = own_uid },
    flags     = nflags,
    settings  = {
      sample_rate_ms = temporal.sample_rate_ms or Vermilion.Constants.TEMPORAL.SAMPLE_RATE_DEFAULT,
      time_window_s  = temporal.time_window_s or Vermilion.Constants.TEMPORAL.TIME_WINDOW_DEFAULT,
    },
    world     = api.GetWorldName(),
    zone      = (api.GetUnitZone and api.GetUnitZone("player")) or "",
    ts        = (api.GetTimeStamp and api.GetTimeStamp()) or 0,
    count     = n,
    chunks    = chunks,
    constants = consts,
  }
  sv.trace = entry
  sv.traces = sv.traces or {}
  local ring = sv.traces
  ring[#ring + 1] = entry
  while #ring > RING do table.remove(ring, 1) end
  d("[trace] " .. n .. " events staged, slot " .. #ring .. "/" .. RING .. "; /vermilion flush writes them to disk")
  return entry
end

function M.auto_enabled(sv)
  local dbg = sv and sv.debug
  if dbg and dbg.auto_trace ~= nil then return dbg.auto_trace == true end
  return RESEARCH
end

function M.set_auto(sv, on)
  if not sv then return end
  sv.debug = sv.debug or {}
  sv.debug.auto_trace = on and true or false
end

function M.on_record(sv)
  if not M.auto_enabled(sv) then return end
  reset()
  M.start()
end

function M.on_stop(sv)
  if not (active and M.auto_enabled(sv)) then return end
  M.stop()
  if n > 0 then M.save(sv) end
end

function M.status_line()
  return "trace " .. (active and "ACTIVE" or "idle") .. "  events=" .. n .. "/" .. CAP
    .. "  flags=" .. nflags .. "  uid=" .. own_uid
end

function M.init()
  zev.register("Vermilion_Trace_CE", C.EVENT_COMBAT_EVENT, function(...) rec("CE", ...) end)
  zev.register("Vermilion_Trace_EF", C.EVENT_EFFECT_CHANGED, function(...)
    local unitTag, unitId = select(4, ...), select(14, ...)
    if unitTag == "player" and type(unitId) == "number" and unitId > 0 and unitId ~= own_uid then
      own_uid = unitId
      if active then rec_identity() end
    end
    rec("EF", ...)
  end)
  zev.register("Vermilion_Trace_CS", C.EVENT_PLAYER_COMBAT_STATE, function(in_combat) rec("CS", in_combat) end)
  if C.EVENT_UNIT_DEATH_STATE_CHANGED then
    zev.register("Vermilion_Trace_DE", C.EVENT_UNIT_DEATH_STATE_CHANGED, function(tag, dead) rec("DE", tag, dead) end)
  end
  if C.EVENT_ACTIVE_WEAPON_PAIR_CHANGED then
    zev.register("Vermilion_Trace_WP", C.EVENT_ACTIVE_WEAPON_PAIR_CHANGED, function() rec("WP") end)
  end
  if C.EVENT_BOSSES_CHANGED then
    zev.register("Vermilion_Trace_BO", C.EVENT_BOSSES_CHANGED, rec_bosses)
  end
  zev.register("Vermilion_Trace_GJ", C.EVENT_GROUP_MEMBER_JOINED, rec_group)
  zev.register("Vermilion_Trace_GL", C.EVENT_GROUP_MEMBER_LEFT, rec_group)
  zev.register("Vermilion_Trace_GU", C.EVENT_GROUP_UPDATE, rec_group)
end
