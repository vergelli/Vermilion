Vermilion = Vermilion or {}
local Vermilion = Vermilion

Vermilion.Resources = {}
local M = Vermilion.Resources

local log = Vermilion.Log.for_module("resources")

local MAG, STA = 1, 2
local FLOW_CAP = 65535
local LOW = 0.15

local recording = false
local cur    = { 0, 0 }
local max    = { 1, 1 }
local gained = { 0, 0 }
local spent  = { 0, 0 }
local seen   = { false, false }
local saw_any = false

local function bump(key) Vermilion.Diagnostics.bump(key) end

local function clamp01(v)
  if v < 0 then return 0 end
  if v > 1 then return 1 end
  return v
end

function M.on_power(p, value, powerMax, effectiveMax)
  bump("res.power_updates")
  value = value or 0
  local mx = max[p]
  if effectiveMax and effectiveMax > 0 then mx = effectiveMax
  elseif powerMax and powerMax > 0 then mx = powerMax end
  if seen[p] then
    local d = value - cur[p]
    if d > 0 then gained[p] = gained[p] + d
    elseif d < 0 then spent[p] = spent[p] - d end
  end
  cur[p] = value
  max[p] = mx
  seen[p] = true
  saw_any = true
end

local function flow(v)
  if v > FLOW_CAP then return FLOW_CAP end
  return v
end

function M.sample_into(slot)
  if not slot then return end
  slot.mag     = seen[MAG] and clamp01(cur[MAG] / max[MAG]) or 0
  slot.sta     = seen[STA] and clamp01(cur[STA] / max[STA]) or 0
  slot.mag_in  = flow(gained[MAG])
  slot.mag_out = flow(spent[MAG])
  slot.sta_in  = flow(gained[STA])
  slot.sta_out = flow(spent[STA])
  gained[MAG], gained[STA], spent[MAG], spent[STA] = 0, 0, 0, 0
end

local function seed(p, ptype)
  local api = Vermilion.zenimax.api
  if not (api.GetUnitPower and ptype) then return end
  local v, mx, emx = api.GetUnitPower("player", ptype)
  if v and v > 0 then
    cur[p] = v
    if emx and emx > 0 then max[p] = emx elseif mx and mx > 0 then max[p] = mx end
    seen[p] = true
    saw_any = true
  end
end

function M.start_session()
  recording = true
  saw_any = false
  seen[MAG], seen[STA] = false, false
  gained[MAG], gained[STA], spent[MAG], spent[STA] = 0, 0, 0, 0
  local zc = Vermilion.zenimax.constants
  seed(MAG, zc.POWERTYPE_MAGICKA)
  seed(STA, zc.POWERTYPE_STAMINA)
end

function M.finalize()
  if not recording then return end
  recording = false
  log:info("session finalize: magicka", seen[MAG] and cur[MAG] or "-", "stamina", seen[STA] and cur[STA] or "-")
end

function M.reset()
  recording = false
  saw_any = false
  seen[MAG], seen[STA] = false, false
  gained[MAG], gained[STA], spent[MAG], spent[STA] = 0, 0, 0, 0
end

function M.saw() return saw_any end
function M.is_recording() return recording end
function M.level(p) return seen[p] and clamp01(cur[p] / max[p]) or 0 end
function M.low() return LOW end

local sum_scratch = {
  has = false, n = 0,
  mag_in = 0, mag_out = 0, mag_sigma = 0, mag_low = 0, mag_low_pct = 0,
  sta_in = 0, sta_out = 0, sta_sigma = 0, sta_low = 0, sta_low_pct = 0,
  damage = 0, eff = 0,
}

function M.summary(TB)
  local r = sum_scratch
  r.has, r.n = false, 0
  r.mag_in, r.mag_out, r.mag_sigma, r.mag_low, r.mag_low_pct = 0, 0, 0, 0, 0
  r.sta_in, r.sta_out, r.sta_sigma, r.sta_low, r.sta_low_pct = 0, 0, 0, 0, 0
  r.damage, r.eff = 0, 0
  local n = TB.count()
  local prev_t = nil
  for i = 1, n do
    local s = TB.at(i)
    if prev_t then r.damage = r.damage + ((s.eDPS or 0) + (s.ShDPS or 0)) * (s.t - prev_t) / 1000 end
    prev_t = s.t
    local m, st = s.mag or 0, s.sta or 0
    if m > 0 or st > 0 then r.has = true end
    r.mag_in  = r.mag_in  + (s.mag_in  or 0)
    r.mag_out = r.mag_out + (s.mag_out or 0)
    r.sta_in  = r.sta_in  + (s.sta_in  or 0)
    r.sta_out = r.sta_out + (s.sta_out or 0)
    if m > 0 and m < LOW then r.mag_low = r.mag_low + 1 end
    if st > 0 and st < LOW then r.sta_low = r.sta_low + 1 end
  end
  r.n = n
  if n > 0 then
    r.mag_low_pct = r.mag_low / n
    r.sta_low_pct = r.sta_low / n
  end
  if r.mag_out > 0 then r.mag_sigma = r.mag_in / r.mag_out end
  if r.sta_out > 0 then r.sta_sigma = r.sta_in / r.sta_out end
  local out = r.mag_out + r.sta_out
  if out > 0 then r.eff = r.damage / out * 1000 end
  return r
end

function M.window_sigma(TB, idx, back, p)
  local lo = idx - back + 1
  if lo < 1 then lo = 1 end
  local gin, gout = 0, 0
  for i = lo, idx do
    local s = TB.at(i)
    if p == MAG then gin = gin + (s.mag_in or 0); gout = gout + (s.mag_out or 0)
    else gin = gin + (s.sta_in or 0); gout = gout + (s.sta_out or 0) end
  end
  if gout <= 0 then return nil, gin, gout end
  return gin / gout, gin, gout
end

function M.report_lines()
  return {
    string.format("magicka %d/%d (%s)  stamina %d/%d (%s)  updates=%d",
      cur[MAG], max[MAG], seen[MAG] and "seen" or "unseen",
      cur[STA], max[STA], seen[STA] and "seen" or "unseen",
      Vermilion.Diagnostics.get("res.power_updates")),
  }
end

local function register(name, p, ptype)
  local zev = Vermilion.zenimax.events
  local zc  = Vermilion.zenimax.constants
  zev.register(name, zc.EVENT_POWER_UPDATE,
    function(_unitTag, _idx, _ptype, value, powerMax, effectiveMax)
      M.on_power(p, value, powerMax, effectiveMax)
    end)
  zev.add_filter(name, zc.EVENT_POWER_UPDATE, zc.REGISTER_FILTER_POWER_TYPE, ptype)
  zev.add_filter(name, zc.EVENT_POWER_UPDATE, zc.REGISTER_FILTER_UNIT_TAG, "player")
end

function M.init()
  local zc = Vermilion.zenimax.constants
  if zc.POWERTYPE_MAGICKA == nil or zc.POWERTYPE_STAMINA == nil then
    log:warn("no magicka or stamina power type on this client; tracker disabled")
    return
  end
  register("Vermilion_E_ResMag", MAG, zc.POWERTYPE_MAGICKA)
  register("Vermilion_E_ResSta", STA, zc.POWERTYPE_STAMINA)
  seed(MAG, zc.POWERTYPE_MAGICKA)
  seed(STA, zc.POWERTYPE_STAMINA)
  log:info("init: magicka", cur[MAG], "/", max[MAG], "stamina", cur[STA], "/", max[STA])
end
