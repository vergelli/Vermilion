return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G, M, R = Vermilion.Graph, Vermilion.Metrics, Vermilion.Resources

  M.reset()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  G.on_record_click()
  H.damage_out({ hit = 40000, ability_id = 31, target_unit_id = 900 })
  H.advance(10000)
  H.damage_out({ hit = 40000, ability_id = 31, target_unit_id = 900 })
  G.on_stop_click()
  local sm = G.export_summary()
  ok(sm.alive_avg == nil and sm.dead_ms == 0 and sm.deaths == 0, "no death, no second average")
  ok(sm.avg == 8000, "eighty thousand over ten seconds, got " .. tostring(sm.avg))

  G.on_flush_click()
  G.on_record_click()
  H.death(true)
  H.advance(2000)
  H.death(false)
  H.advance(1000)
  H.damage_out({ hit = 40000, ability_id = 31, target_unit_id = 900 })
  H.advance(10000)
  H.death(true)
  H.advance(5000)
  H.death(false)
  H.advance(5000)
  H.damage_out({ hit = 40000, ability_id = 31, target_unit_id = 900 })
  H.advance(1000)
  H.death(true)
  H.advance(3000)
  H.death(false)
  G.on_stop_click()

  local function check(label)
    local s = G.export_summary()
    ok(s.fight_ms == 20000, label .. ": the fight is twenty seconds, got " .. s.fight_ms)
    ok(s.dead_ms == 5000, label .. ": only the time dead inside the fight counts, got " .. s.dead_ms)
    ok(s.deaths == 1, label .. ": and only that death, got " .. s.deaths)
    ok(s.avg == 4000, label .. ": the plain average still divides by the whole fight, got " .. s.avg)
    ok(math.abs(s.alive_avg - 80000 / 15) < 0.01, label .. ": the alive average takes the time dead out, got " .. s.alive_avg)
    local report = Vermilion.ExportReport.SECTIONS[2]()
    ok(report:find(GetString(VERMILION_EXPORT_DEAD) .. ";5.0", 1, true), label .. ": the export says how long")
    ok(report:find(GetString(VERMILION_EXPORT_DEATHS) .. ";1", 1, true), label .. ": and how many times")
    ok(report:find(GetString(VERMILION_EXPORT_AVG_ALIVE) .. ";5333", 1, true), label .. ": and the alive average")
  end
  check("live")

  local dead, count = R.dead_ms(0, H.now() + 100000)
  ok(count == 3, "the three deaths are recorded, got " .. count)

  local sess = Vermilion.SessionStore.capture()
  G.on_flush_click()
  ok(G.export_summary().alive_avg == nil, "a flush forgets it")
  ok(G.load_session(sess), "the session reloads")
  check("loaded")
  dead, count = R.dead_ms(0, sess.head.dur_ms + 100000)
  ok(count == 3 and dead == 10000, "the deaths come back with the session, got " .. count .. " for " .. dead)

  local enter = VermilionGraphSummaryHit._onOnMouseEnter
  ok(enter, "the header has its hover")
  enter()
  local seen = {}
  for _, c in ipairs(H.controls) do
    if type(c._text) == "string" then seen[c._text] = true end
  end
  ok(seen[GetString(VERMILION_REPORT_AVG_ALIVE)], "the card names the alive average")
  ok(seen[GetString(VERMILION_REPORT_AVG_ALL)], "the card names the average with deaths")
  ok(seen[GetString(VERMILION_REPORT_DEAD)], "the card names the time dead")
  VermilionGraphSummaryHit._onOnMouseExit()

  G.on_flush_click()
  Vermilion.Visibility.set("graph", false)
  M.reset()
end
