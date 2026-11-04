SIMLAB_ROOT = arg[1] or "."
HARNESS_ROOT = SIMLAB_ROOT
HARNESS_DEBUG = false
local sv_path = arg[2]
if not sv_path then
  print("usage: lua test/simlab/casts_audit.lua <root> <SavedVariables/Vermilion.lua or trace.lua>")
  os.exit(2)
end

local codec = dofile(SIMLAB_ROOT .. "/test/simlab/tracecodec.lua")
local f = assert(io.open(sv_path, "rb"))
local src = f:read("*a")
f:close()
local env = {}
local chunk = setfenv and setfenv(assert(loadstring(src)), env) or assert(load(src, "sv", "t", env))
chunk()

local traces = {}
local function find(t, depth)
  if type(t) ~= "table" or depth > 8 then return end
  if type(t.traces) == "table" then
    for _, tr in ipairs(t.traces) do traces[#traces + 1] = tr end
    return
  end
  if type(t.trace) == "table" and t.trace.chunks then traces[#traces + 1] = t.trace return end
  for _, v in pairs(t) do find(v, depth + 1) end
end
find(env.VermilionSavedVars, 0)
if #traces == 0 then
  print("no trace found")
  os.exit(2)
end

dofile(SIMLAB_ROOT .. "/test/harness/mock_eso.lua")
dofile(SIMLAB_ROOT .. "/test/harness/loader.lua")
HARNESS.fire(EVENT_ADD_ON_LOADED, "Vermilion")
local Cst = Vermilion.Casts
local NAMES = { [1] = "magicka", [2] = "stamina" }
local CHANNEL = {}
for id, ms in (arg[3] or ""):gmatch("(%d+)=(%d+)") do CHANNEL[tonumber(id)] = tonumber(ms) end

for idx, tr in ipairs(traces) do
  local c = tr.constants or {}
  local POWER = { [c.COMBAT_MECHANIC_FLAGS_MAGICKA or -1] = 1, [c.COMBAT_MECHANIC_FLAGS_STAMINA or -2] = 2 }
  local ev = codec.decode_chunks(tr.chunks)
  local names, press, last = {}, {}, {}
  local spent, pressed_cost = { 0, 0 }, { 0, 0 }
  Cst.reset()
  Cst.start_session()
  for _, e in ipairs(ev) do
    local a = e.args
    if e.tag == "SU" then
      if (a[4] or 0) > 0 and (a[3] == 1 or a[3] == 2) then
        press[a[2]] = (press[a[2]] or 0) + 1
        pressed_cost[a[3]] = pressed_cost[a[3]] + a[4]
        Cst.stage(a[2], a[3], a[4], e.t, a[5] or CHANNEL[a[2]])
      end
    elseif e.tag == "PU" then
      local p = POWER[a[3]]
      if p then
        if last[p] and a[4] < last[p] then
          spent[p] = spent[p] + (last[p] - a[4])
          Cst.on_drop(p, last[p] - a[4], e.t)
        end
        last[p] = a[4]
      end
    elseif e.tag == "CE" and a[16] and a[3] ~= "" then
      names[a[16]] = a[3]
    end
  end
  local t, id, pool, cost, n, tick = Cst.records()
  local rows, order = {}, {}
  local table_spend = { 0, 0 }
  for i = 1, n do
    local r = rows[id[i]]
    if not r then
      r = { id = id[i], pool = pool[i], casts = 0, ticks = 0, spend = 0 }
      rows[id[i]] = r
      order[#order + 1] = r
    end
    if tick[i] == 1 then r.ticks = r.ticks + 1 else r.casts = r.casts + 1 end
    r.spend = r.spend + cost[i]
    if pool[i] == 1 or pool[i] == 2 then table_spend[pool[i]] = table_spend[pool[i]] + cost[i] end
  end
  table.sort(order, function(a, b) return a.spend > b.spend end)
  print(string.format("=== trace %d  zone=%s events=%d span=%.1fs", idx, tostring(tr.zone), #ev, #ev > 0 and (ev[#ev].t - ev[1].t) / 1000 or 0))
  print("skill | pool | presses | casts | drains | spend")
  for _, r in ipairs(order) do
    print(string.format("%-30s %-8s %5d %5d %5d %8d", names[r.id] or tostring(r.id), NAMES[r.pool] or "-", press[r.id] or 0, r.casts, r.ticks, r.spend))
  end
  for p = 1, 2 do
    print(string.format("%s: old table %d, new table %d, pool drops %d", NAMES[p], pressed_cost[p], table_spend[p], spent[p]))
  end
end
os.exit(0)
