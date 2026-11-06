local function line(w, ...)
  local parts = { ... }
  for i = 1, select("#", ...) do parts[i] = tostring(parts[i]) end
  w:write(table.concat(parts, "\t"), "\n")
end

return function(out_path, sess, hits)
  local w = assert(io.open(out_path, "wb"))
  local sum = sess.head.sum
  line(w, "HEAD", sess.head.ts or 0, sess.head.dur_ms or 0, sum.total_damage or 0, sum.hits or 0, sum.crit_hits or -1, sum.fight_ms or 0, sess.head.zone or "", sess.head.build or "", sum.fight_t0 or -1, sum.exact and 1 or 0, sum.exact and sum.exact.pool and 1 or 0)
  for _, h in ipairs(hits or {}) do line(w, "HIT", h[1], h[2], h[3], h[4]) end
  if hits and hits.start then line(w, "REC", hits.start) end

  local first_t, last_t
  if Vermilion.Resources.exact_flow() then first_t, last_t = Vermilion.Metrics.fight_bounds() end
  local t, id, pool, cost, n, tick = Vermilion.Casts.records()
  for i = 1, n do
    if not last_t or t[i] <= last_t then
      line(w, "CAST", t[i], id[i], pool[i], cost[i], tick[i] or 0, GetAbilityName(id[i]) or "")
    end
  end

  local rt, rid, rp, ra, rn = Vermilion.Restores.records()
  for i = 1, rn do
    if not last_t or (rt[i] >= first_t and rt[i] <= last_t) then line(w, "REST", rid[i], rp[i], ra[i]) end
  end

  local rs = Vermilion.Resources.summary(Vermilion.TemporalBuffer)
  line(w, "POOL", 1, rs.mag_in, rs.mag_out)
  line(w, "POOL", 2, rs.sta_in, rs.sta_out)

  local TB = Vermilion.TemporalBuffer
  local ab = {}
  if sum.exact then
    for key, v in pairs(sum.exact.skills) do
      local aid = math.floor(key / 64)
      ab[aid] = (ab[aid] or 0) + v
    end
  else
    for i = 2, TB.count() do
      local s = TB.at(i)
      local eos = ((s.eDPS or 0) + (s.ShDPS or 0)) * (s.t - TB.at(i - 1).t) / 1000
      local list = s.eos_abilities
      for k = 1, (list and list.count or 0) do
        local e = list[k]
        ab[e.id] = (ab[e.id] or 0) + (e.share or 0) * eos
      end
    end
  end
  for aid, v in pairs(ab) do line(w, "ABIL", aid, string.format("%.1f", v), GetAbilityName(aid) or "") end

  local DT = Vermilion.DebuffTracker
  for i = 1, DT.count() do
    local d = DT.get(i)
    line(w, "DEBUFF", d.name or "", d.uptime_ms or 0, d.applications or 0, d.longest_gap_ms or 0)
  end

  local names = Vermilion.Uptime.keys()
  local sk, _, st0, st1, sn = Vermilion.Uptime.spans()
  for i = 1, sn do line(w, "SPAN", names[sk[i]] or "", st0[i], st1[i]) end
  local uorder, un, urows = Vermilion.UptimeView.compute()
  for i = 1, un do
    local r = urows[uorder[i]]
    line(w, "COVER", r.name or "", r.covered or 0, r.apps or 0)
  end

  local _, _, cn = Vermilion.Ultimate.casts()
  line(w, "ULT", cn)
  local _, _, _, ac, an = Vermilion.Ultimate.abilities()
  local low = nil
  for i = 1, an do
    if (ac[i] or 0) > 0 and (not low or ac[i] < low) then low = ac[i] end
  end
  line(w, "ULTCOST", low or 0)

  local K = Vermilion.Kills
  line(w, "KILLS", K.count())
  for i = 1, K.count() do
    local kt, kuid = K.get(i)
    line(w, "KILL", kt, kuid)
  end

  local parts = {}
  for _, section in ipairs(Vermilion.ExportReport.SECTIONS) do
    local text = section()
    if text ~= "" then parts[#parts + 1] = text end
  end
  w:write("EXPORT\n", table.concat(parts, "\n"), "\n")
  w:close()
end
