return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G, CV, TV, TB = Vermilion.Graph, Vermilion.ContribView, Vermilion.TargetsView, Vermilion.TemporalBuffer

  local function play()
    local hits = {
      { 1234, 31, 301 }, { 777, 32, 301 }, { 4321, 31, 302 }, { 95, 33, 303 }, { 1500, 32, 302 },
    }
    for i = 1, 70 do
      local h = hits[i % #hits + 1]
      H.damage_out({ hit = h[1] + i, ability_id = h[2], target_unit_id = h[3], target_type = COMBAT_UNIT_TYPE_NONE,
        target_name = (h[3] == 303) and "Spider^n" or "Corrupted Infantry^M", damage_type = (h[2] == 33) and 4 or 2 })
      H.advance(137 * (i % 9) + 40)
    end
    H.advance(6000)
  end

  local function table_sum(order, n, field)
    local s = 0
    for i = 1, n do s = s + order[i][field] end
    return s
  end

  Vermilion.Metrics.reset()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  G.on_record_click()
  play()
  G.on_stop_click()

  local dmg = Vermilion.Metrics.totals()
  ok(dmg > 0, "the fight recorded damage")
  local order, n, totals = CV.compute()
  ok(totals.damage == dmg, "the skill table adds every hit, got " .. totals.damage .. " against " .. dmg)
  ok(table_sum(order, n, "v") == dmg, "its rows sum the total exactly")
  local rows, rn, tt = TV.compute()
  ok(tt.damage == dmg, "the target table adds every hit")
  ok(table_sum(rows, rn, "total") == dmg, "its rows sum the total exactly")
  local sm = G.export_summary()
  ok(math.abs(sm.crit_pct - sm.total_crit / sm.total_damage) < 1e-9, "the crit share comes from the counters")

  local saved = Vermilion.SessionStore.capture()
  ok(saved.head.sum.exact and saved.head.sum.exact.skills, "a saved session keeps the counters")
  G.on_flush_click()
  ok(Vermilion.Metrics.output_total() == 0, "a flush clears the counters")
  ok(G.load_session(saved), "the session reloads")
  order, n, totals = CV.compute()
  ok(totals.damage == dmg, "a saved session reads the same table")
  ok(table_sum(order, n, "v") == dmg, "and the same rows")
  ok(Vermilion.Metrics.output_total() == dmg, "and the same total")
  G.on_flush_click()

  G.on_flush_click()
  G.on_record_click()
  play()
  G.on_stop_click()
  local previous = Vermilion.SessionStore.capture()
  previous.head.sum.exact = nil
  G.on_flush_click()
  ok(G.load_session(previous), "a session from before the counters loads")
  ok(Vermilion.Metrics.exact() == nil, "and has none")
  order, n, totals = CV.compute()
  ok(n > 0 and totals.damage > 0, "and still fills the table from its samples")
  rows, rn = TV.compute()
  ok(rn > 0, "and the target table too")
  G.on_flush_click()

  local cap = Vermilion.Constants.TEMPORAL.CAPACITY
  TB.init(12)
  G.on_flush_click()
  G.on_record_click()
  play()
  G.on_stop_click()
  dmg = Vermilion.Metrics.totals()
  order, n, totals = CV.compute()
  ok(TB.count() <= 12, "the sample buffer overflowed, holds " .. TB.count())
  ok(totals.damage == dmg, "a fight longer than the buffer keeps the whole skill table")
  rows, rn, tt = TV.compute()
  ok(tt.damage == dmg, "and the whole target table")
  local parts = {}
  for _, section in ipairs(Vermilion.ExportReport.SECTIONS) do parts[#parts + 1] = section() end
  local text = table.concat(parts, "\n")
  ok(text:find("Skills", 1, true), "the export built")
  ok(not text:find("outlasted the sample buffer", 1, true), "and no longer needs the partial note")

  TB.init(cap)
  G.on_flush_click()
  Vermilion.Visibility.set("graph", false)
  Vermilion.Metrics.reset()
end
