return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G, R, RV = Vermilion.Graph, Vermilion.Resources, Vermilion.ResourcesView
  local TB = Vermilion.TemporalBuffer
  local MAG = POWERTYPE_MAGICKA

  local function ids(list)
    local out = {}
    for i = 1, list.n do out[list[i].id] = list[i] end
    return out
  end

  local function check(label)
    local rs = R.summary(TB)
    ok(rs.mag_in == 250, label .. ": gained counts the first hit to the last, got " .. tostring(rs.mag_in))
    ok(rs.mag_out == 800, label .. ": spent counts the opener and stops at the last hit, got " .. tostring(rs.mag_out))
    RV.with_all(function(spent, recovered)
      local s, r = ids(spent), ids(recovered)
      ok(s[7003] and s[7003].mag == 500, label .. ": the cast pressed before the first hit stays in the table")
      ok(s[7001] and s[7001].mag == 300, label .. ": a cast during the fight is in the table")
      ok(not s[7002], label .. ": a cast after the last hit is not")
      ok(r[801] and r[802], label .. ": restores during the fight are in the table")
      ok(not r[9701], label .. ": a restore before the first hit is not")
      ok(not r[803], label .. ": a restore after the last hit is not")
    end)
  end

  Vermilion.Metrics.reset()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  G.on_record_click()
  H.res_power(MAG, 20000, 30000)

  H.energize({ ability_id = 9701, amount = 100 })
  Vermilion.Casts.stage(7003, 1, 500, H.now())
  H.res_power(MAG, 19500, 30000)
  H.res_power(MAG, 19600, 30000)
  H.advance(1000)

  H.damage_out({ hit = 1000, ability_id = 31 })
  H.advance(1000)
  H.energize({ ability_id = 801, amount = 200 })
  H.res_power(MAG, 19800, 30000)
  Vermilion.Casts.stage(7001, 1, 300, H.now())
  H.res_power(MAG, 19500, 30000)
  H.advance(1000)

  H.damage_out({ hit = 1000, ability_id = 31 })
  H.energize({ ability_id = 802, amount = 50 })
  H.res_power(MAG, 19550, 30000)
  H.advance(1000)

  H.energize({ ability_id = 803, amount = 450 })
  H.res_power(MAG, 20000, 30000)
  Vermilion.Casts.stage(7002, 1, 100, H.now())
  H.res_power(MAG, 19900, 30000)
  H.advance(6000)
  G.on_stop_click()

  check("live")

  local saved = Vermilion.SessionStore.capture()
  ok(saved.head.sum.exact.pool, "a saved session keeps the pool totals")
  G.on_flush_click()
  ok(G.load_session(saved), "the session reloads")
  check("saved")
  G.on_flush_click()

  saved.head.sum.exact.pool = nil
  ok(G.load_session(saved), "a session without pool totals loads")
  ok(R.exact_flow() == nil, "and has none")
  local rs = R.summary(TB)
  ok(rs.mag_out == 900, "and adds the whole recording as before, got " .. tostring(rs.mag_out))
  RV.with_all(function(spent)
    ok(ids(spent)[7002], "its cast table is not cut either")
  end)

  G.on_flush_click()
  Vermilion.Visibility.set("graph", false)
  Vermilion.Metrics.reset()
end
