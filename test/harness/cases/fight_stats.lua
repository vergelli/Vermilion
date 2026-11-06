return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G, M, FS, TB = Vermilion.Graph, Vermilion.Metrics, Vermilion.FightStats, Vermilion.TemporalBuffer

  M.reset()
  Vermilion.Visibility.set("graph", true)

  local function steady(hit, seconds)
    for _ = 1, seconds do
      H.damage_out({ hit = hit, ability_id = 31, target_unit_id = 900 })
      H.advance(1000)
    end
  end

  G.on_flush_click()
  G.on_record_click()
  steady(1000, 4)
  G.on_stop_click()
  ok(FS.compute(TB).n == 0, "a fight shorter than one window has no stretches to measure")

  G.on_flush_click()
  G.on_record_click()
  H.advance(20000)
  steady(1000, 30)
  H.damage_out({ hit = 1000, ability_id = 31, target_unit_id = 900 })
  H.advance(20000)
  G.on_stop_click()
  local s = FS.compute(TB)
  ok(s.n >= 20, "the windows of the fight count, got " .. s.n)
  ok(s.p10 > 0, "waiting before and after the fight is not part of it, got " .. s.p10)
  ok(s.p50 >= 800 and s.p50 <= 1000, "a steady thousand per second has that median, four or five hits in the window, got " .. s.p50)
  ok(s.p90 - s.p10 <= 200, "and no real spread, got " .. s.p10 .. " to " .. s.p90)

  G.on_flush_click()
  G.on_record_click()
  steady(1000, 30)
  steady(3000, 30)
  H.damage_out({ hit = 3000, ability_id = 31, target_unit_id = 900 })
  H.advance(1000)
  G.on_stop_click()
  s = FS.compute(TB)
  ok(s.p10 >= 800 and s.p10 <= 1000, "the low stretch is the slow half, got " .. s.p10)
  ok(s.p90 >= 2400 and s.p90 <= 3000, "the good stretch is the fast half, got " .. s.p90)
  ok(s.p50 > s.p10 and s.p50 < s.p90, "the median sits between them, got " .. s.p50)

  G.on_flush_click()
  G.on_record_click()
  steady(1000, 30)
  local alive_before = FS.compute(TB).n
  H.death(true)
  H.advance(30000)
  H.death(false)
  steady(1000, 30)
  H.damage_out({ hit = 1000, ability_id = 31, target_unit_id = 900 })
  H.advance(1000)
  G.on_stop_click()
  s = FS.compute(TB)
  local dead_windows = 0
  local lo, hi = M.fight_bounds()
  for i = 1, TB.count() do
    local t = TB.at(i).t
    if t >= lo + 5000 and t <= hi then dead_windows = dead_windows + 1 end
  end
  ok(s.n < dead_windows, "the time dead is left out, got " .. s.n .. " of " .. dead_windows)
  ok(s.n > alive_before, "the time alive on both sides counts, got " .. s.n)
  ok(s.p50 >= 800 and s.p50 <= 1000, "a death does not move the median of the time alive, got " .. s.p50)
  ok(s.p90 >= 800 and s.p90 <= 1000, "nor the good stretches, got " .. s.p90)

  local keep_n, keep_p50, keep_p90, keep_p10 = s.n, s.p50, s.p90, s.p10
  local sess = Vermilion.SessionStore.capture()
  G.on_flush_click()
  ok(FS.compute(TB).n == 0, "a flush forgets it")
  ok(G.load_session(sess), "the session reloads")
  s = FS.compute(TB)
  ok(s.n == keep_n, "a saved session has the same windows, got " .. s.n .. " and " .. keep_n)
  ok(math.abs(s.p50 - keep_p50) < 1 and math.abs(s.p90 - keep_p90) < 1 and math.abs(s.p10 - keep_p10) < 1, "and the same numbers")

  local report = Vermilion.ExportReport.SECTIONS[2]()
  ok(report:find(GetString(VERMILION_EXPORT_P90), 1, true), "the export has the good stretches")
  ok(report:find(GetString(VERMILION_EXPORT_MEDIAN), 1, true), "the median")
  ok(report:find(GetString(VERMILION_EXPORT_P10), 1, true), "and the low stretches")

  local function card_shows(key)
    VermilionGraphSummaryHit._onOnMouseEnter()
    local seen = false
    for _, c in ipairs(H.controls) do
      if c._text == GetString(key) and c._hidden == false then seen = true end
    end
    VermilionGraphSummaryHit._onOnMouseExit()
    return seen
  end
  ok(card_shows(VERMILION_REPORT_P90), "the card names the good stretches")
  ok(card_shows(VERMILION_REPORT_MEDIAN), "the median")
  ok(s.p10 > 0 and card_shows(VERMILION_REPORT_P10), "and the low stretches when there are any")

  G.on_flush_click()
  G.on_record_click()
  for _ = 1, 3 do
    steady(1000, 6)
    H.advance(12000)
  end
  H.damage_out({ hit = 1000, ability_id = 31, target_unit_id = 900 })
  H.advance(1000)
  G.on_stop_click()
  s = FS.compute(TB)
  ok(s.p10 == 0, "a phase with no damage reads zero in the low stretches, got " .. s.p10)
  ok(not card_shows(VERMILION_REPORT_P10), "and the card leaves out a zero that says nothing")

  G.on_flush_click()
  Vermilion.Visibility.set("graph", false)
  M.reset()
end
