SIMLAB_ROOT   = arg[1] or "."
HARNESS_ROOT  = SIMLAB_ROOT
HARNESS_DEBUG = true

local sv_path = arg[2]
if not sv_path then
  print("usage: lua test/simlab/audit.lua <root> <trace.lua>")
  os.exit(2)
end

dofile(SIMLAB_ROOT .. "/test/harness/mock_eso.lua")
local codec = dofile(SIMLAB_ROOT .. "/test/simlab/tracecodec.lua")

dofile(sv_path)
local trace
local function find_trace(t, depth)
  if type(t) ~= "table" or depth > 8 or trace then return end
  if type(t.trace) == "table" and t.trace.chunks then trace = t.trace return end
  for _, v in pairs(t) do find_trace(v, depth + 1) end
end
find_trace(VermilionSavedVars, 0)
VermilionSavedVars = nil
local events = codec.decode_chunks(trace.chunks)

local friend = {}
for _, e in ipairs(events) do
  if e.tag == "EF" then
    local tag = e.args[4] or ""
    if tag == "player" or tag:sub(1, 5) == "group" or tag:sub(1, 9) == "playerpet" or tag:sub(1, 9) == "companion" then
      friend[e.args[14]] = true
    end
  end
end

local real_name = {}
for _, e in ipairs(events) do
  if e.tag == "CE" and e.args[16] and e.args[3] ~= "" then real_name[e.args[16]] = e.args[3] end
  if e.tag == "EF" and e.args[15] and e.args[3] ~= "" then real_name[e.args[15]] = e.args[3] end
end
local mock_name = GetAbilityName
GetAbilityName = function(id) return real_name[id] or mock_name(id) end

dofile(SIMLAB_ROOT .. "/test/harness/loader.lua")
HARNESS.fire(EVENT_ADD_ON_LOADED, "Vermilion")
local H = HARNESS

local DMG = {
  [ACTION_RESULT_DAMAGE] = true, [ACTION_RESULT_DOT_TICK] = true,
  [ACTION_RESULT_CRITICAL_DAMAGE] = true, [ACTION_RESULT_DOT_TICK_CRITICAL] = true,
  [ACTION_RESULT_BLOCKED_DAMAGE] = true,
}
local CRIT = { [ACTION_RESULT_CRITICAL_DAMAGE] = true, [ACTION_RESULT_DOT_TICK_CRITICAL] = true }

local T = { dmg = 0, shield = 0, hits = 0, crit_hits = 0, crit_dmg = 0, by_id = {}, by_type = {} }
local spans = {}
local spans_debuff = {}
local open = {}

local function truth_combat(a, now)
  local result, is_err, stype, ttype, hit, dtype, suid, aid = a[1], a[2], a[7], a[9], a[10] or 0, a[12], a[14], a[16]
  if is_err or stype ~= COMBAT_UNIT_TYPE_PLAYER or ttype == COMBAT_UNIT_TYPE_PLAYER or hit <= 0 then return end
  if DMG[result] and (suid or 0) > 0 then
    T.dmg = T.dmg + hit
    T.hits = T.hits + 1
    T.first = T.first or now
    T.last = now
    if CRIT[result] then T.crit_hits = T.crit_hits + 1; T.crit_dmg = T.crit_dmg + hit end
    local nm = real_name[aid] or tostring(aid)
    T.by_id[nm] = (T.by_id[nm] or 0) + hit
    T.by_type[dtype] = (T.by_type[dtype] or 0) + hit
  elseif result == ACTION_RESULT_DAMAGE_SHIELDED then
    T.shield = T.shield + hit
    T.first = T.first or now
    T.last = now
    T.shield_rows = (T.shield_rows or 0) + 1
  end
end

local function enemy_tag(tag)
  if tag == nil or tag == "" then return true end
  if tag == "player" or tag:sub(1, 5) == "group" then return false end
  if tag:sub(1, 9) == "playerpet" or tag:sub(1, 9) == "companion" then return false end
  return true
end

local function truth_effect(a, now)
  local change, name, tag, end_s, uid, src, aid, etype = a[1], a[3], a[4], a[6], a[14], a[16], a[15], a[10]
  if src ~= COMBAT_UNIT_TYPE_PLAYER then return end
  if not uid or uid == 0 or not name or name == "" or not enemy_tag(tag) or friend[uid] then return end
  local key = name .. "#" .. uid .. "#" .. tostring(aid)
  if change == EFFECT_RESULT_GAINED or change == EFFECT_RESULT_UPDATED then
    local o = open[key]
    if not o and (end_s or 0) * 1000 <= now then return end
    if o and o.last_end > o.t0 and o.last_end + 1500 < now and (end_s or 0) * 1000 > now then
      spans[name] = spans[name] or {}
      table.insert(spans[name], { o.t0, o.last_end })
      if o.debuff then
        spans_debuff[name] = spans_debuff[name] or {}
        table.insert(spans_debuff[name], { o.t0, o.last_end })
      end
      open[key] = nil
      o = nil
    end
    if not o then
      open[key] = { name = name, t0 = now, last_end = (end_s or 0) * 1000, debuff = etype == BUFF_EFFECT_TYPE_DEBUFF }
    else
      o.last_end = (end_s or 0) * 1000
    end
  elseif change == EFFECT_RESULT_FADED then
    local o = open[key]
    if o then
      local close = now
      if o.last_end > o.t0 and o.last_end < close then close = o.last_end end
      spans[name] = spans[name] or {}
      table.insert(spans[name], { o.t0, close })
      if o.debuff then
        spans_debuff[name] = spans_debuff[name] or {}
        table.insert(spans_debuff[name], { o.t0, close })
      end
      open[key] = nil
    end
  end
end

local function close_all(now)
  for _, o in pairs(open) do
    spans[o.name] = spans[o.name] or {}
    local e = o.last_end
    if e <= o.t0 or e > now then e = now end
    table.insert(spans[o.name], { o.t0, e })
    if o.debuff then
      spans_debuff[o.name] = spans_debuff[o.name] or {}
      table.insert(spans_debuff[o.name], { o.t0, e })
    end
  end
end

Vermilion.Visibility.set("graph", true)
if events[1].t > H.now() then H.advance(events[1].t - H.now()) end
Vermilion.Graph.on_record_click()
local offset = events[1].t - H.now()
print("clock offset", offset)
for _, e in ipairs(events) do
  local target = e.t - offset
  if target > H.now() then H.advance(target - H.now()) end
  if e.tag == "CE" then truth_combat(e.args, H.now()) end
  if e.tag == "EF" then truth_effect(e.args, H.now()) end
  codec.fire(H, e)
end
H.advance(6000)
close_all(H.now())
Vermilion.Graph.on_stop_click()

local function pct(a, b) return (b and b > 0) and a / b * 100 or 0 end
local function rel(a, b) return (b and b ~= 0) and (a - b) / b * 100 or 0 end
print("=== " .. sv_path:match("[^/\\]+$"))

local sm = Vermilion.Graph.export_summary()
local orderC, nC, totC = Vermilion.ContribView.compute()
local orderT, nT, totT = Vermilion.TargetsView.compute()
local dn, dnt = Vermilion.DamageNames.by_name(Vermilion.TemporalBuffer)
local all = T.dmg + T.shield
print(string.format("TOTAL truth dmg=%.0f shield=%.0f | Metrics dmg=%.0f (%+.2f%%) shield=%.0f hits truth=%d addon=%d",
  T.dmg, T.shield, sm.total_damage, rel(sm.total_damage, T.dmg), sm.total_shield, T.hits, sm.hits))
print(string.format("INTEGRAL contrib=%.0f (%+.2f%%) targets=%.0f (%+.2f%%) names=%.0f (%+.2f%%)",
  totC.damage + totC.shield, rel(totC.damage + totC.shield, all), totT.damage, rel(totT.damage, all), dnt, rel(dnt, all)))
print(string.format("CRIT truth by hits=%.1f by damage=%.1f | addon rate=%.1f damage=%.1f", pct(T.crit_hits, T.hits), pct(T.crit_dmg, T.dmg), sm.crit_rate * 100, sm.crit_pct * 100))

local est = {}
for i = 1, nC do
  local r = orderC[i]
  est[r.name] = (est[r.name] or 0) + r.v
end
local worst, worst_id, n_big, total_abs = 0, nil, 0, 0
local ids = {}
for id in pairs(T.by_id) do ids[#ids + 1] = id end
table.sort(ids, function(a, b) return T.by_id[a] > T.by_id[b] end)
local tot_est = totC.damage + totC.shield
for _, id in ipairs(ids) do
  local p_true, p_est = pct(T.by_id[id], T.dmg), pct(est[id] or 0, tot_est)
  local d = math.abs(p_true - p_est)
  total_abs = total_abs + d
  if d > worst then worst, worst_id = d, id end
  if p_true >= 1 then n_big = n_big + 1 end
end
print(string.format("SKILLS rows=%d worst share gap=%.2f points (id %s, truth %.2f est %.2f) sum gaps=%.2f",
  #ids, worst, tostring(worst_id), worst_id and pct(T.by_id[worst_id], T.dmg) or 0, worst_id and pct(est[worst_id] or 0, tot_est) or 0, total_abs))
for i = 1, math.min(5, #ids) do
  local id = ids[i]
  print(string.format("  top%d %s truth=%.0f (%.2f%%) est=%.0f (%.2f%%)", i, id, T.by_id[id], pct(T.by_id[id], T.dmg), est[id] or 0, pct(est[id] or 0, tot_est)))
end

local tb_last = Vermilion.TemporalBuffer.at(Vermilion.TemporalBuffer.count()).t
local function union(list)
  table.sort(list, function(a, b) return a[1] < b[1] end)
  local cov, a, b = 0, nil, nil
  for _, raw in ipairs(list) do
    local s = { raw[1], raw[2] > tb_last and tb_last or raw[2] }
    if a and s[1] <= b then
      if s[2] > b then b = s[2] end
    else
      if a then cov = cov + (b - a) end
      a, b = s[1], s[2]
    end
  end
  if a then cov = cov + (b - a) end
  return cov
end

local DT = Vermilion.DebuffTracker
local ord, nU, rows = Vermilion.UptimeView.compute()
local upt = {}
for i = 1, nU do local r = rows[ord[i]]; upt[r.name] = r end
print("EFFECTS name | truth s | uptime s | debuff s")
local t0 = Vermilion.TemporalBuffer.at(1).t
local names = {}
for name in pairs(spans) do names[#names + 1] = name end
table.sort(names, function(x, y) return union(spans[x]) > union(spans[y]) end)
local deb = {}
for i = 1, DT.count() do local d = DT.get(i); deb[d.name] = d end
local dmax, umax = 0, 0
for _, name in ipairs(names) do
  local tr = union(spans[name]) / 1000
  local u, d = upt[name], deb[name]
  local us, ds = u and u.covered / 1000, d and d.uptime_ms / 1000
  local trd = spans_debuff[name] and union(spans_debuff[name]) / 1000 or 0
  if ds and math.abs(ds - trd) > dmax then dmax = math.abs(ds - trd) end
  if us and math.abs(us - tr) > umax then umax = math.abs(us - tr) end
  if u or d then
    print(string.format("  %-30s %8.1f %8s %8s", name, tr, us and string.format("%.1f", us) or "-", ds and string.format("%.1f", ds) or "-"))
  end
end
print(string.format("EFFECT_GAP worst uptime %.1f s, worst debuff %.1f s", umax, dmax))
local bad = {}
if math.abs(rel(sm.total_damage, T.dmg)) > 0.001 then bad[#bad + 1] = "damage total" end
if sm.hits ~= T.hits then bad[#bad + 1] = "hit count" end
local true_avg = all / (math.max(1, T.last - T.first) / 1000)
print(string.format("DPS truth %.0f over %.1f s | addon %.0f over %.1f s", true_avg, (T.last - T.first) / 1000, sm.avg, sm.fight_ms / 1000))
if math.abs(rel(sm.avg, true_avg)) > 0.5 then bad[#bad + 1] = "average per second of fight" end
if sm.crit_hits ~= T.crit_hits then bad[#bad + 1] = "crit hit count" end
if math.abs(sm.crit_pct * 100 - pct(T.crit_dmg, T.dmg)) > 0.5 then bad[#bad + 1] = "damage from crits" end
if math.abs(rel(totC.damage + totC.shield, all)) > 0.5 then bad[#bad + 1] = "skills total" end
if math.abs(rel(totT.damage, all)) > 0.5 then bad[#bad + 1] = "targets total" end
if math.abs(rel(dnt, all)) > 0.5 then bad[#bad + 1] = "names total" end
if T.shield == 0 and worst > 0.5 then bad[#bad + 1] = "skill share" end
if umax > 1.5 then bad[#bad + 1] = string.format("uptime off by %.1f s", umax) end
if dmax > 1.5 then bad[#bad + 1] = string.format("debuffs off by %.1f s", dmax) end
print(#bad == 0 and "AUDIT: ok" or ("AUDIT: FAIL " .. table.concat(bad, "; ")))
os.exit(#bad == 0 and 0 or 1)
