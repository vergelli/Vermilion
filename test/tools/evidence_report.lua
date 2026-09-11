local sv_path = arg[1]
if not sv_path then
  print("usage: lua test/tools/evidence_report.lua <SavedVariables/Vermilion.lua> [--flags-only]")
  os.exit(1)
end
local flags_only = arg[2] == "--flags-only"

local here = (arg[0] or ""):match("^(.*)[/\\]") or "."
local codec = dofile(here .. "/../simlab/tracecodec.lua")

dofile(sv_path)
local root = VermilionSavedVars
if not root then print("no VermilionSavedVars in " .. sv_path) os.exit(1) end

local CE = { result = 1, err = 2, ability = 3, src = 6, stype = 7, tgt = 8, ttype = 9, hit = 10, dtype = 12, suid = 14, tuid = 15, aid = 16, overflow = 17 }
local PAIR_MS = 100

local function fmt_ce(e)
  local a = e.args
  return string.format("%8d  r=%-10s %-28s %s(%s,%s) -> %s(%s,%s) hit=%s dt=%s aid=%s of=%s",
    e.t, tostring(a[CE.result]), tostring(a[CE.ability]):sub(1, 28),
    tostring(a[CE.src]), tostring(a[CE.stype]), tostring(a[CE.suid]),
    tostring(a[CE.tgt]), tostring(a[CE.ttype]), tostring(a[CE.tuid]),
    tostring(a[CE.hit]), tostring(a[CE.dtype]), tostring(a[CE.aid]), tostring(a[CE.overflow]))
end

local function analyse(entry, label)
  local K = entry.constants or {}
  local R_SHIELD = K.ACTION_RESULT_DAMAGE_SHIELDED
  local DMG = {}
  for _, k in ipairs({ "ACTION_RESULT_DAMAGE", "ACTION_RESULT_CRITICAL_DAMAGE", "ACTION_RESULT_DOT_TICK", "ACTION_RESULT_DOT_TICK_CRITICAL", "ACTION_RESULT_BLOCKED_DAMAGE" }) do
    if K[k] then DMG[K[k]] = k end
  end
  local PLAYER = K.COMBAT_UNIT_TYPE_PLAYER
  local events = codec.decode_chunks(entry.chunks)
  local p = entry.player or {}
  print(("=" ):rep(100))
  print(string.format("%s  zone=%s  ts=%s  build=%s  count=%d decoded=%d  flags=%s  research=%s",
    label, tostring(entry.zone), tostring(entry.ts), tostring(entry.build), entry.count or 0, #events, tostring(entry.flags), tostring(entry.research)))
  print(string.format("player: raw=%s name=%s display=%s uid=%s", tostring(p.raw), tostring(p.name), tostring(p.display), tostring(p.uid)))
  if #events == 0 then return end

  local tags = {}
  for _, e in ipairs(events) do tags[e.tag] = (tags[e.tag] or 0) + 1 end
  local tl = {}
  for k, v in pairs(tags) do tl[#tl + 1] = k .. "=" .. v end
  table.sort(tl)
  print("tags: " .. table.concat(tl, " ") .. string.format("  span=%.1fs", (events[#events].t - events[1].t) / 1000))

  for _, e in ipairs(events) do
    if e.tag == "ID" then print(string.format("  ID @%d raw=%s name=%s display=%s uid=%s", e.t, e.args[1], e.args[2], e.args[3], tostring(e.args[4]))) end
    if e.tag == "ZN" then print(string.format("  ZN @%d %s", e.t, e.args[1])) end
    if e.tag == "GR" then print(string.format("  GR @%d grouped=%s size=%s names=%s slot=%s", e.t, tostring(e.args[1]), tostring(e.args[2]), tostring(e.args[3]), tostring(e.args[4]))) end
  end

  if not flags_only then
    print("\n-- source audit (CE with sourceType = PLAYER, by source name / uid) --")
    local src = {}
    local order = {}
    for _, e in ipairs(events) do
      if e.tag == "CE" and e.args[CE.stype] == PLAYER then
        local key = tostring(e.args[CE.src]) .. "#" .. tostring(e.args[CE.suid])
        local rec = src[key]
        if not rec then rec = { n = 0, hit = 0, abilities = {}, results = {} }; src[key] = rec; order[#order + 1] = key end
        rec.n = rec.n + 1
        rec.hit = rec.hit + (e.args[CE.hit] or 0)
        rec.abilities[tostring(e.args[CE.aid]) .. " " .. tostring(e.args[CE.ability])] = true
        rec.results[tostring(e.args[CE.result])] = (rec.results[tostring(e.args[CE.result])] or 0) + 1
      end
    end
    for _, key in ipairs(order) do
      local rec = src[key]
      local name, uid = key:match("^(.*)#(.*)$")
      local mine = (p.raw ~= nil and p.raw ~= "" and name == p.raw) or (p.uid and tostring(p.uid) == uid)
      local abl = {}
      for a in pairs(rec.abilities) do abl[#abl + 1] = a end
      table.sort(abl)
      local res = {}
      for r, c in pairs(rec.results) do res[#res + 1] = r .. "x" .. c end
      table.sort(res)
      print(string.format("  %s uid=%-7s n=%-5d hit=%-9d %s  results{%s}", mine and "SELF " or "OTHER", uid, rec.n, rec.hit, name, table.concat(res, ",")))
      if not mine then
        for _, a in ipairs(abl) do print("        " .. a) end
      end
    end

    print("\n-- shield pairing (2460 with sourceType = PLAYER vs the nearest damage event, same src/tgt) --")
    local matched, unmatched, multi, reversed = 0, 0, 0, 0
    local shields = {}
    for i, e in ipairs(events) do
      if e.tag == "CE" and e.args[CE.result] == R_SHIELD and e.args[CE.stype] == PLAYER then
        local suid, tuid = e.args[CE.suid], e.args[CE.tuid]
        local cands = {}
        for j = i + 1, #events do
          local f = events[j]
          if f.t - e.t >= PAIR_MS then break end
          if f.tag == "CE" and DMG[f.args[CE.result]] and f.args[CE.suid] == suid and f.args[CE.tuid] == tuid then cands[#cands + 1] = f end
        end
        local before = 0
        for j = i - 1, 1, -1 do
          local f = events[j]
          if e.t - f.t >= PAIR_MS then break end
          if f.tag == "CE" and DMG[f.args[CE.result]] and f.args[CE.suid] == suid and f.args[CE.tuid] == tuid then before = before + 1 end
        end
        local sk = tostring(e.args[CE.aid]) .. " " .. tostring(e.args[CE.ability])
        local rec = shields[sk]
        if not rec then rec = { n = 0, hit = 0, attacks = {}, targets = {} }; shields[sk] = rec end
        rec.n = rec.n + 1
        rec.hit = rec.hit + (e.args[CE.hit] or 0)
        rec.targets[tostring(e.args[CE.tgt]) .. "(" .. tostring(e.args[CE.ttype]) .. ")"] = true
        if #cands == 0 then
          unmatched = unmatched + 1
          if before > 0 then reversed = reversed + 1 end
        else
          matched = matched + 1
          if #cands > 1 then multi = multi + 1 end
          local a = cands[1].args
          local ak = tostring(a[CE.aid]) .. " " .. tostring(a[CE.ability]) .. " hit=" .. tostring(a[CE.hit]) .. " dt=" .. tostring(a[CE.dtype])
          rec.attacks[ak] = (rec.attacks[ak] or 0) + 1
        end
      end
    end
    print(string.format("  2460 events: matched=%d unmatched=%d (of which a damage event precedes within %dms: %d) multi-candidate=%d",
      matched, unmatched, PAIR_MS, reversed, multi))
    local sk = {}
    for k in pairs(shields) do sk[#sk + 1] = k end
    table.sort(sk)
    for _, k in ipairs(sk) do
      local rec = shields[k]
      local tg = {}
      for t in pairs(rec.targets) do tg[#tg + 1] = t end
      table.sort(tg)
      print(string.format("  shield %-40s n=%-4d absorbed=%-8d targets=%s", k, rec.n, rec.hit, table.concat(tg, ",")))
      local at = {}
      for a, c in pairs(rec.attacks) do at[#at + 1] = string.format("%dx %s", c, a) end
      table.sort(at)
      for _, a in ipairs(at) do print("        paired with " .. a) end
    end
  end

  print("\n-- flags --")
  local any = false
  for i, e in ipairs(events) do
    if e.tag == "FL" then
      any = true
      print(string.format("  FLAG @%d", e.t))
      for part in (e.args[1] .. " | "):gmatch("(.-) | ") do print("      " .. part) end
      print("      context (CE within 1500 ms):")
      for j = 1, #events do
        local f = events[j]
        if f.tag == "CE" and math.abs(f.t - e.t) <= 1500 then print("      " .. fmt_ce(f)) end
      end
    end
  end
  if not any then print("  none") end
end

for server, sv in pairs(root["Default"] and root["Default"]["@vergelli"] and root["Default"]["@vergelli"]["$AccountWide"] or {}) do
  print("\n#### " .. tostring(server))
  local ring = sv.traces or {}
  if #ring == 0 then print("no staged traces") end
  for i, entry in ipairs(ring) do analyse(entry, "trace " .. i .. "/" .. #ring) end
  local fl = sv.evidence and sv.evidence.flags or {}
  print("\n-- staged flags outside recordings: " .. #fl .. " --")
  for i, f in ipairs(fl) do
    print(string.format("  [%d] ts=%s t=%s zone=%s", i, tostring(f.ts), tostring(f.t), tostring(f.zone)))
    for part in (tostring(f.text) .. " | "):gmatch("(.-) | ") do print("      " .. part) end
  end
end
