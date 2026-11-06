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

  local r_before, t_before = count_real()
  Cst.stage(70000, MAG, 1015, 46000, 3800)
  Cst.on_drop(MAG, 1015, 46300)
  for i = 1, 5 do
    Cst.stage(70000, MAG, 1015, 46300 + i * 300, 3800)
    Cst.on_drop(MAG, 1015, 46300 + i * 690)
  end
  local r_a, t_a = count_real()
  ok(r_a == r_before + 1, "pressing a channeled skill while it channels is not another cast, got " .. (r_a - r_before))
  ok(t_a == t_before + 5, "and every drain counts as spend, got " .. (t_a - t_before))
  Cst.stage(70000, MAG, 1015, 50300, 3800)
  Cst.on_drop(MAG, 1015, 50400)
  local r_b = count_real()
  ok(r_b == r_a + 1, "after the channel ends a press is a new cast")
  r2, t2 = count_real()

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
  G.on_record_click()
  H.res_power(POWERTYPE_MAGICKA, 13460, 26940)
  H.fire(EVENT_POWER_UPDATE, "player", 0, POWERTYPE_MAGICKA, 0, 26940, 26940)
  local rs = Vermilion.Resources.summary(Vermilion.TemporalBuffer)
  H.advance(1000)
  rs = Vermilion.Resources.summary(Vermilion.TemporalBuffer)
  ok(rs.mag_out == 0, "the pool emptied by dying is not spend, even under half its maximum, got " .. rs.mag_out)

  H.res_power(POWERTYPE_MAGICKA, 20000, 26940)
  H.advance(4000)
  Vermilion.Resources.on_death(true)
  local real_dead = Vermilion.zenimax.api.IsUnitDead
  Vermilion.zenimax.api.IsUnitDead = function() return false end
  H.res_power(POWERTYPE_MAGICKA, 15000, 26940)
  ok(Vermilion.Resources.is_dead() == false, "a power update from a living player ends the death, with no revive event")
  H.res_power(POWERTYPE_MAGICKA, 14000, 26940)
  H.advance(1000)
  rs = Vermilion.Resources.summary(Vermilion.TemporalBuffer)
  ok(rs.mag_out == 6000, "and the pool counts again, got " .. rs.mag_out)
  Vermilion.zenimax.api.IsUnitDead = real_dead

  Cst.stage(38788, STA, 3305, 940000)
  Cst.on_drop(STA, 2594, 940100)
  t, id, _, cost, n = Cst.records()
  ok(id[n] == 38788 and cost[n] == 2594, "a cast that shares its update with a regen tick still counts, got " .. tostring(id[n]) .. " for " .. tostring(cost[n]))
  Cst.stage(38788, STA, 3305, 942000)
  Cst.on_drop(STA, 4021, 942100)
  local before = n
  t, id, _, cost, n = Cst.records()
  ok(n == before + 1 and cost[n] == 4021, "so does one that shares it with a drain, got " .. tostring(cost[n]))
  before = n
  Cst.stage(99001, STA, 700, 944000)
  Cst.on_drop(STA, 13, 944010)
  t, id, _, cost, n = Cst.records()
  ok(n == before, "a sprint tick does not confirm the press of a cheap skill, got " .. n - before)
  G.on_stop_click()

  G.on_flush_click()
  Vermilion.Visibility.set("graph", false)
  Vermilion.Metrics.reset()
end
