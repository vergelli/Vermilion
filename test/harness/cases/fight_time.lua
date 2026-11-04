return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G, M, DT = Vermilion.Graph, Vermilion.Metrics, Vermilion.DebuffTracker

  M.reset()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  G.on_record_click()
  H.advance(20000)
  ok(M.fight_ms() == 0, "no hit, no fight")
  H.damage_out({ hit = 1000, ability_id = 31 })
  H.advance(10000)
  H.damage_out({ hit = 1000, ability_id = 31 })
  ok(M.fight_ms() == 10000, "the fight runs from the first hit to the last, got " .. M.fight_ms())
  H.advance(30000)
  G.on_stop_click()
  ok(M.fight_ms() == 10000, "waiting before and after the fight changes nothing")
  local sm = G.export_summary()
  ok(sm.avg == 200, "two thousand over ten seconds, got " .. tostring(sm.avg))

  local sess = Vermilion.SessionStore.capture()
  ok(sess.head.sum.fight_ms == 10000, "the session keeps its fight time")
  G.on_flush_click()
  ok(M.fight_ms() == 0, "flush forgets it")
  ok(G.load_session(sess), "the session reloads")
  ok(M.fight_ms() == 10000, "and loading brings it back")
  ok(M.session_avg(sess.head.sum) == 200, "the library reads the same average")
  ok(G.export_summary().avg == 200, "so does the header")
  sess.head.sum.fight_ms = nil
  ok(M.session_avg(sess.head.sum) == sess.head.sum.avg, "an older session keeps the average it saved")

  local rec = { uptime_ms = 5000 }
  ok(DT.uptime_of(rec) == 0.5, "debuff uptime divides by the fight, got " .. DT.uptime_of(rec))
  rec.uptime_ms = 15000
  ok(DT.uptime_of(rec) == 1, "and never passes one hundred percent")

  G.on_flush_click()
  Vermilion.Visibility.set("graph", false)
  M.reset()
end
