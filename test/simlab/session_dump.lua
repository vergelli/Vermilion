SIMLAB_ROOT = arg[1] or "."
HARNESS_ROOT = SIMLAB_ROOT
HARNESS_DEBUG = false
local path, out = arg[2], arg[3]
if not path or not out then
  print("usage: lua test/simlab/session_dump.lua <root> <SavedVariables/Vermilion.lua> <out.csv> [ts]")
  os.exit(2)
end
dofile(SIMLAB_ROOT .. "/test/harness/mock_eso.lua")
dofile(SIMLAB_ROOT .. "/test/harness/loader.lua")
HARNESS.fire(EVENT_ADD_ON_LOADED, "Vermilion")

local f = assert(io.open(path, "rb"))
local src = f:read("*a")
f:close()
local env = {}
local chunk = setfenv and setfenv(assert(loadstring(src)), env) or assert(load(src, "sv", "t", env))
chunk()
local lib
local function walk(t, depth)
  if lib or depth > 7 then return end
  for k, v in pairs(t) do
    if type(v) == "table" then
      if k == "library" and v.sessions then lib = v return end
      walk(v, depth + 1)
    end
  end
end
walk(env.VermilionSavedVars, 0)

local want_ts = tonumber(arg[4] or "")
local best
for _, s in ipairs(lib.sessions) do
  if want_ts then
    if s.head.ts == want_ts then best = s end
  elseif not best or (s.head.ts or 0) > (best.head.ts or 0) then
    best = s
  end
end
assert(best, "session not found")
Vermilion.Visibility.set("graph", true)
assert(Vermilion.Graph.load_session(best))

local w = assert(io.open(out, "wb"))
local sum = best.head.sum
w:write(string.format("HEAD,%d,%d,%d,%d,%d,%s\n", best.head.ts or 0, best.head.dur_ms or 0, sum.total_damage or 0, sum.hits or 0, sum.crit_hits or -1, (best.head.zone or ""):gsub(",", " ")))
local t, id, pool, cost, n, tick = Vermilion.Casts.records()
for i = 1, n do w:write(string.format("CAST,%d,%d,%d,%d,%d\n", t[i], id[i], pool[i], cost[i], tick[i] or 0)) end
local rt, rid, rp, ra, rn = Vermilion.Restores.records()
for i = 1, rn do w:write(string.format("REST,%d,%d,%d,%d\n", rt[i], rid[i], rp[i], ra[i])) end
local rs = Vermilion.Resources.summary(Vermilion.TemporalBuffer)
w:write(string.format("POOL,1,%.0f,%.0f\nPOOL,2,%.0f,%.0f\n", rs.mag_in, rs.mag_out, rs.sta_in, rs.sta_out))
local TB = Vermilion.TemporalBuffer
local ab = {}
for i = 2, TB.count() do
  local s = TB.at(i)
  local eos = ((s.eDPS or 0) + (s.ShDPS or 0)) * (s.t - TB.at(i - 1).t) / 1000
  local list = s.eos_abilities
  for k = 1, (list and list.count or 0) do
    local e = list[k]
    ab[e.id] = (ab[e.id] or 0) + (e.share or 0) * eos
  end
end
for aid, v in pairs(ab) do w:write(string.format("ABIL,%d,%.1f\n", aid, v)) end
local DT = Vermilion.DebuffTracker
for i = 1, DT.count() do
  local d = DT.get(i)
  w:write(string.format("DEBUFF,%d,%.0f,%d\n", d.id or 0, d.uptime_ms or 0, d.applications or 0))
end
local _, _, _, ids = Vermilion.Uptime.keys()
local sk, _, st0, st1, sn = Vermilion.Uptime.spans()
for i = 1, sn do w:write(string.format("SPAN,%d,%d,%d\n", ids[sk[i]] or 0, st0[i], st1[i])) end
local _, _, cn = Vermilion.Ultimate.casts()
w:write(string.format("ULT,%d\n", cn))
w:close()
os.exit(0)
