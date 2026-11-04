return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G, Cst = Vermilion.Graph, Vermilion.Casts
  local MAG, STA = 1, 2
  local sv = Vermilion.SavedVars

  Vermilion.Metrics.reset()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  G.on_record_click()

  local function count_real()
    local _, _, _, _, n, tick = Cst.records()
    local real, ticks = 0, 0
    for i = 1, n do
      if tick[i] == 1 then ticks = ticks + 1 else real = real + 1 end
    end
    return real, ticks, n
  end

  Cst.stage(40382, STA, 2722, 1000)
  Cst.stage(40382, STA, 2722, 1190)
  Cst.on_drop(STA, 2722, 1460)
  local real = count_real()
  ok(real == 1, "two presses and one drop are one cast, got " .. real)

  Cst.stage(40382, STA, 2722, 22000)
  Cst.on_drop(STA, 1123, 22014)
  real = count_real()
  ok(real == 1, "a press on cooldown is not a cast, and a drop of another size does not confirm it, got " .. real)
  Cst.on_drop(STA, 2722, 24000)
  real = count_real()
  ok(real == 1, "a press expires, a drop much later does not confirm it, got " .. real)

  Cst.stage(61919, MAG, 2157, 30000)
  Cst.stage(38931, MAG, 2792, 30020)
  Cst.on_drop(MAG, 2792, 30250)
  Cst.on_drop(MAG, 2157, 30900)
  local t, id, _, cost, n = Cst.records()
  ok(id[n - 1] == 38931 and id[n] == 61919, "each drop goes to the press with its cost")
  ok(cost[n - 1] == 2792 and cost[n] == 2157, "the recorded spend is what the pool lost")

  local before_real, before_ticks = count_real()
  Cst.stage(63046, MAG, 1015, 40000)
  Cst.on_drop(MAG, 1015, 40700)
  Cst.on_drop(MAG, 1015, 41075)
  Cst.on_drop(MAG, 1015, 41742)
  Cst.on_drop(MAG, 1015, 42410)
  local r1, t1 = count_real()
  ok(r1 == before_real + 1, "a channel is one cast, got " .. (r1 - before_real))
  ok(t1 == before_ticks + 3, "its later drains count as spend, got " .. (t1 - before_ticks))
  Cst.on_drop(MAG, 1015, 45000)
  local r2, t2 = count_real()
  ok(r2 == r1 and t2 == t1, "a drain long after the channel is credited to nobody")

  Cst.stage(503, 0, 0, 50000)
  local r3 = count_real()
  ok(r3 == r2 + 1, "a skill with no cost has no drop to wait for")

  H.damage_out({ hit = 1000, ability_id = 63046 })
  H.advance(1000)
  G.on_stop_click()
  Vermilion.ResourcesView.with_all(function(spent)
    local found
    for i = 1, spent.n do
      if spent[i].id == 63046 then found = spent[i] end
    end
    ok(found, "the channel is in the spend table")
    ok(found.n == 1, "the table counts one cast, got " .. found.n)
    ok(found.total == 4060, "and all its drains, got " .. found.total)
  end)

  local sess = Vermilion.SessionStore.capture()
  G.on_flush_click()
  ok(G.load_session(sess), "the session reloads")
  local _, _, _, _, _ = Cst.records()
  local r4, t4 = count_real()
  ok(r4 == r3 and t4 == t2, "casts and drains survive the round trip")

  G.on_flush_click()
  Vermilion.Visibility.set("graph", false)
  Vermilion.Metrics.reset()
end
