SIMLAB_ROOT   = arg[1] or "."
HARNESS_ROOT  = SIMLAB_ROOT
HARNESS_DEBUG = true

local sv_path = arg[2]
local force_window, force_rate = nil, nil
for i = 3, #arg do
  local w = arg[i]:match("^%-%-window=(%d+)$")
  if w then force_window = tonumber(w) end
  local r = arg[i]:match("^%-%-rate=(%d+)$")
  if r then force_rate = tonumber(r) end
end
if not sv_path then
  print("usage: lua test/simlab/replay.lua <root> <path/to/SavedVariables/Vermilion.lua> [--window=S] [--rate=MS]")
  os.exit(2)
end

dofile(SIMLAB_ROOT .. "/test/harness/mock_eso.lua")
dofile(SIMLAB_ROOT .. "/test/harness/loader.lua")
HARNESS.fire(EVENT_ADD_ON_LOADED, "Vermilion")

local H     = HARNESS
local codec = dofile(SIMLAB_ROOT .. "/test/simlab/tracecodec.lua")

dofile(sv_path)
local sv_root = VermilionSavedVars
if not sv_root then
  print("VermilionSavedVars not found in " .. sv_path)
  os.exit(2)
end

local trace
local function find_trace(t, depth)
  if type(t) ~= "table" or depth > 8 or trace then return end
  if type(t.trace) == "table" and t.trace.chunks then
    trace = t.trace
    return
  end
  for _, v in pairs(t) do
    if type(v) == "table" then find_trace(v, depth + 1) end
  end
end
find_trace(sv_root, 0)
if not trace then
  print("no trace node with chunks found in " .. sv_path)
  os.exit(2)
end

local events = codec.decode_chunks(trace.chunks)
print(string.format("replay: %d events  trace_build=%s  world=%s  zone=%s",
  #events, tostring(trace.build), tostring(trace.world), tostring(trace.zone)))

if trace.constants then
  local drift = 0
  for k, v in pairs(trace.constants) do
    if k ~= "API_VERSION" then
      local mv = rawget(_G, k)
      if mv ~= v then
        drift = drift + 1
        print(string.format("  const mismatch: %-34s live=%s  mock=%s", k, tostring(v), tostring(mv)))
      end
    end
  end
  print(string.format("constants: api=%s  mismatches=%d", tostring(trace.constants.API_VERSION), drift))
end
if #events == 0 then os.exit(2) end

do
  local ts = trace.settings or {}
  local window = force_window or ts.time_window_s
  local rate   = force_rate or ts.sample_rate_ms
  if window or rate then
    local sv = Vermilion.SavedVars
    sv.temporal = sv.temporal or {}
    sv.temporal.time_window_s  = window or sv.temporal.time_window_s or 60
    sv.temporal.sample_rate_ms = rate or sv.temporal.sample_rate_ms or 1000
    local hz = math.floor(1000 / sv.temporal.sample_rate_ms)
    Vermilion.TemporalBuffer.init(sv.temporal.time_window_s * hz)
    print(string.format("settings: window=%ds  rate=%dms  (%s)",
      sv.temporal.time_window_s, sv.temporal.sample_rate_ms,
      (force_window or force_rate) and "from arguments" or "recorded with the trace"))
  else
    print("settings: window=60s  rate=1000ms  (trace carries none, harness defaults)")
  end
end

local DMG = {}
DMG[ACTION_RESULT_DAMAGE] = true
DMG[ACTION_RESULT_DOT_TICK] = true
DMG[ACTION_RESULT_CRITICAL_DAMAGE] = true
DMG[ACTION_RESULT_DOT_TICK_CRITICAL] = true
DMG[ACTION_RESULT_BLOCKED_DAMAGE] = true

local O = { damage = {}, shields = {}, checks = 0, fails = 0, max_rel = 0, fail_lines = {} }
local orig_fire = H.fire
H.fire = function(code, ...)
  if code == EVENT_COMBAT_EVENT then
    local result, isError, _, _, _, _, sourceType, _, targetType, hit, _, _, _, suid = ...
    if not isError and sourceType == COMBAT_UNIT_TYPE_PLAYER and targetType ~= COMBAT_UNIT_TYPE_PLAYER and (hit or 0) > 0 then
      if DMG[result] and (suid or 0) > 0 then
        O.damage[#O.damage + 1] = { t = H.now(), amount = hit }
      elseif result == ACTION_RESULT_DAMAGE_SHIELDED then
        O.shields[#O.shields + 1] = { t = H.now(), amount = hit }
      end
    end
  end
  return orig_fire(code, ...)
end

local function wsum(list, W_ms, now)
  local cutoff = now - W_ms
  local s = 0
  for i = #list, 1, -1 do
    local e = list[i]
    if e.t <= cutoff then break end
    s = s + e.amount
  end
  return s
end

local function check(now)
  local W  = Vermilion.Metrics.window_seconds() * 1000
  local WS = Vermilion.Metrics.shield_window_seconds() * 1000
  local want_dps = wsum(O.damage, W, now) / (W / 1000)
  local want_sh  = wsum(O.shields, WS, now) / (WS / 1000)
  local got_dps = Vermilion.Metrics.eDPS(now)
  local got_sh  = Vermilion.Metrics.ShDPS(now)
  for _, pair in ipairs({ { "eDPS", got_dps, want_dps }, { "ShDPS", got_sh, want_sh } }) do
    local label, got, want = pair[1], pair[2], pair[3]
    local denom = (math.abs(want) > 1) and math.abs(want) or 1
    local rel = math.abs(got - want) / denom
    O.checks = O.checks + 1
    if rel > O.max_rel then O.max_rel = rel end
    if rel > 1e-6 then
      O.fails = O.fails + 1
      if #O.fail_lines < 20 then
        O.fail_lines[#O.fail_lines + 1] = string.format("t=%d  %-6s got=%.4f  want=%.4f  rel=%.2e", now, label, got, want, rel)
      end
    end
  end
end

Vermilion.Graph.on_record_click()
local offset = events[1].t - H.now()
local next_check = H.now() + 250
local t0_wall = os.clock()
for _, e in ipairs(events) do
  local target = e.t - offset
  while next_check <= target do
    if next_check > H.now() then H.advance(next_check - H.now()) end
    check(H.now())
    next_check = next_check + 250
  end
  if target > H.now() then H.advance(target - H.now()) end
  codec.fire(H, e)
end
check(H.now())
local wall = os.clock() - t0_wall
Vermilion.Graph.on_stop_click()
H.fire = orig_fire

local D = Vermilion.Diagnostics
print(string.format("engine: damage_in=%d damage_acc=%d shield_acc=%d dropped_env=%d pool_exhausted=%d",
  D.get("engine.damage.in"), D.get("engine.damage.accepted"), D.get("engine.shield.accepted"),
  D.get("filter.dropped_env"), D.get("engine.pool.exhausted")))

local TB = Vermilion.TemporalBuffer
local n = TB.count()
local peak, sum_dps, t_first, t_last = 0, 0, 0, 0
for i = 1, n do
  local s = TB.at(i)
  if i == 1 then t_first = s.t end
  t_last = s.t
  sum_dps = sum_dps + s.eDPS
  if s.eDPS > peak then peak = s.eDPS end
end
print(string.format("session: samples=%d dur=%.0fs avg_dps=%.0f peak_dps=%.0f", n, (t_last - t_first) / 1000, n > 0 and sum_dps / n or 0, peak))
print(string.format("oracle: checks=%d divergences=%d max_rel_err=%.2e  wall=%.2fs", O.checks, O.fails, O.max_rel, wall))
for _, line in ipairs(O.fail_lines) do print("  " .. line) end

local numeric_fail = {}
do
  local times = {}
  for i = 1, n do times[i] = TB.at(i).t end
  local function integral_expected(list, W_ms)
    local raw, expected = 0, 0
    for _, e in ipairs(list) do
      raw = raw + e.amount
      local w = 0
      for i = 2, n do
        local ti = times[i]
        if ti - W_ms < e.t and e.t < ti then w = w + (ti - times[i - 1]) / W_ms end
      end
      expected = expected + e.amount * w
    end
    return raw, expected
  end
  local W  = Vermilion.Metrics.window_seconds() * 1000
  local WS = Vermilion.Metrics.shield_window_seconds() * 1000
  local d_raw, d_exp = integral_expected(O.damage, W)
  local s_raw, s_exp = integral_expected(O.shields, WS)
  local d_int, s_int = 0, 0
  for i = 2, n do
    local s = TB.at(i)
    local dt = (s.t - times[i - 1]) / 1000
    d_int = d_int + s.eDPS * dt
    s_int = s_int + s.ShDPS * dt
  end
  local function rel(got, want)
    local denom = (math.abs(want) > 1) and math.abs(want) or 1
    return math.abs(got - want) / denom
  end
  local d_rel, s_rel = rel(d_int, d_exp), rel(s_int, s_exp)
  if d_rel > 1e-6 then numeric_fail[#numeric_fail + 1] = string.format("damage integral off by %.2e", d_rel) end
  if s_rel > 1e-6 then numeric_fail[#numeric_fail + 1] = string.format("shield integral off by %.2e", s_rel) end
  local shares_bad, ticks_bad, id0 = 0, 0, 0
  local function check_shares(list)
    local sum = 0
    for k = 1, (list.count or 0) do
      local ab = list[k]
      sum = sum + (ab.share or 0)
      if ab.id == 0 then id0 = id0 + 1 end
    end
    return math.abs(sum - 1) < 1e-6
  end
  local rate = Vermilion.SavedVars.temporal and Vermilion.SavedVars.temporal.sample_rate_ms or 1000
  for i = 1, n do
    local smp = TB.at(i)
    if smp.eDPS > 0 then
      if not check_shares(smp.eos_abilities) or not check_shares(smp.eos_groups) then shares_bad = shares_bad + 1 end
      if not check_shares(smp.dtype_groups) or not check_shares(smp.dtype_abilities) then shares_bad = shares_bad + 1 end
    end
    if i > 1 then
      local dt = smp.t - times[i - 1]
      if dt <= 0 or dt < rate * 0.5 or dt > rate * 1.5 then ticks_bad = ticks_bad + 1 end
    end
  end
  if shares_bad > 0 then numeric_fail[#numeric_fail + 1] = shares_bad .. " ticks whose shares do not sum to one" end
  if ticks_bad > 0 then numeric_fail[#numeric_fail + 1] = ticks_bad .. " ticks off the sample rate" end
  print(string.format(
    "numeric: damage events=%.0f expected=%.0f integral=%.0f rel=%.1e | shield events=%.0f expected=%.0f integral=%.0f rel=%.1e | shares_bad=%d ticks_bad=%d id0=%d",
    d_raw, d_exp, d_int, d_rel, s_raw, s_exp, s_int, s_rel, shares_bad, ticks_bad, id0))
  if #numeric_fail == 0 then print("NUMERIC: ok") else print("NUMERIC: FAIL " .. table.concat(numeric_fail, "; ")) end
end

os.exit((O.fails == 0 and #numeric_fail == 0) and 0 or 1)
