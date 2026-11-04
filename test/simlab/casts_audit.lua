SIMLAB_ROOT = arg[1] or "."
local sv_path = arg[2]
if not sv_path then
  print("usage: lua test/simlab/casts_audit.lua <root> <SavedVariables/Vermilion.lua or trace.lua>")
  os.exit(2)
end

local codec = dofile(SIMLAB_ROOT .. "/test/simlab/tracecodec.lua")
dofile(sv_path)

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
find(VermilionSavedVars, 0)
if #traces == 0 then
  print("no trace found")
  os.exit(2)
end

local WINDOW_BEFORE, WINDOW_AFTER = 100, 1000
local NAMES = { [1] = "magicka", [2] = "stamina" }

for idx, tr in ipairs(traces) do
  local c = tr.constants or {}
  local POWER = { [c.COMBAT_MECHANIC_FLAGS_MAGICKA or -1] = 1, [c.COMBAT_MECHANIC_FLAGS_STAMINA or -2] = 2 }
  local ev = codec.decode_chunks(tr.chunks)
  local presses, drops, last = {}, { {}, {} }, {}
  local names = {}
  local spent, gained = { 0, 0 }, { 0, 0 }
  for _, e in ipairs(ev) do
    if e.tag == "SU" then
      presses[#presses + 1] = { t = e.t, slot = e.args[1], id = e.args[2], pool = e.args[3], cost = e.args[4] }
    elseif e.tag == "PU" then
      local p = POWER[e.args[3]]
      if p then
        local v = e.args[4]
        if last[p] then
          local d = last[p] - v
          if d > 0 then
            spent[p] = spent[p] + d
            table.insert(drops[p], { t = e.t, d = d })
          else
            gained[p] = gained[p] - d
          end
        end
        last[p] = v
      end
    elseif e.tag == "CE" and e.args[16] and e.args[3] ~= "" then
      names[e.args[16]] = e.args[3]
    end
  end

  print(string.format("=== trace %d  zone=%s events=%d presses=%d", idx, tostring(tr.zone), #ev, #presses))
  local rows, order = {}, {}
  local table_total = { 0, 0 }
  local real_total = { 0, 0 }
  for _, pr in ipairs(presses) do
    if pr.pool == 1 or pr.pool == 2 then
      local r = rows[pr.id]
      if not r then
        r = { id = pr.id, pool = pr.pool, cost = pr.cost, presses = 0, real = 0, drop_sum = 0 }
        rows[pr.id] = r
        order[#order + 1] = r
      end
      r.presses = r.presses + 1
      table_total[pr.pool] = table_total[pr.pool] + pr.cost
      for _, dr in ipairs(drops[pr.pool]) do
        if not dr.used and dr.t >= pr.t - WINDOW_BEFORE and dr.t <= pr.t + WINDOW_AFTER and dr.d >= pr.cost * 0.4 then
          dr.used = true
          r.real = r.real + 1
          r.drop_sum = r.drop_sum + dr.d
          real_total[pr.pool] = real_total[pr.pool] + dr.d
          break
        end
      end
    end
  end
  table.sort(order, function(a, b) return a.presses * a.cost > b.presses * b.cost end)
  print("skill | pool | presses | real casts | reported cost | mean real drop")
  for _, r in ipairs(order) do
    print(string.format("%-30s %-8s %5d %5d %7d %7.0f", names[r.id] or tostring(r.id), NAMES[r.pool], r.presses, r.real, r.cost, r.real > 0 and r.drop_sum / r.real or 0))
  end
  for p = 1, 2 do
    print(string.format("%s: table says %d, drops matched %d, all drops %d, gained %d",
      NAMES[p], table_total[p], real_total[p], spent[p], gained[p]))
  end
end
