return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G, M, SS = Vermilion.Graph, Vermilion.Metrics, Vermilion.SessionStore

  M.reset()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  G.on_record_click()
  for _ = 1, 10 do
    H.damage_out({ hit = 1000, ability_id = 31, target_unit_id = 900 })
    H.advance(1000)
  end
  H.shield_out({ hit = 300 })
  G.on_stop_click()

  local dmg, shd, _, hits = M.totals()
  local fight, size = M.fight_ms(), M.size_snapshot().damage
  ok(dmg == 10000 and hits == 10, "the recording holds its ten hits, got " .. tostring(dmg) .. " in " .. tostring(hits))
  ok(shd == 300, "a shield still waiting for its pair when Stop lands belongs to the session, got " .. tostring(shd))
  ok(fight > 0, "the fight has a length")

  for _ = 1, 8 do
    H.advance(2000)
    H.damage_out({ hit = 500, ability_id = 31, target_unit_id = 900 })
    H.shield_out({ hit = 200 })
  end
  H.advance(2000)

  local dmg2, shd2, _, hits2 = M.totals()
  ok(dmg2 == dmg and hits2 == hits, "a bleed ticking after Stop adds nothing, got " .. tostring(dmg2) .. " in " .. tostring(hits2))
  ok(shd2 == shd, "and neither does a shield, got " .. tostring(shd2))
  ok(M.fight_ms() == fight, "the fight stops growing, got " .. tostring(M.fight_ms()) .. " after " .. tostring(fight))
  ok(M.size_snapshot().damage <= size, "nothing piles up in the buffers after Stop")
  local counted = 0
  for key, v in pairs(M.exact().skills) do
    if math.floor(key / 64) == 31 then counted = counted + v end
  end
  ok(counted == 10000, "the exact skill table agrees with the chart, got " .. tostring(counted))

  local before = SS.count()
  ok(G.on_save_click ~= nil, "the manual save exists")
  G.on_save_click()
  H.advance(400)
  ok(SS.count() == before + 1, "saving late stores the session")
  local sum = SS.get(SS.count()).head.sum
  ok(sum.total_damage == 10000 and sum.hits == 10, "saving late stores what was recorded, got " .. tostring(sum.total_damage) .. " in " .. tostring(sum.hits))
  ok(sum.fight_ms == fight, "with the fight it recorded, got " .. tostring(sum.fight_ms))

  G.on_flush_click()
  local TB = Vermilion.TemporalBuffer
  H.damage_out({ hit = 50000, ability_id = 31, target_unit_id = 900 })
  H.advance(1000)
  G.on_record_click()
  H.advance(2500)
  ok(TB.count() >= 2, "the recording has samples, got " .. TB.count())
  for i = 1, TB.count() do
    ok(TB.at(i).eDPS == 0, "a hit from before Record is not in the chart, sample " .. i .. " reads " .. tostring(TB.at(i).eDPS))
  end
  H.damage_out({ hit = 1000, ability_id = 31, target_unit_id = 900 })
  H.advance(2000)
  G.on_stop_click()
  ok(Vermilion.Graph.export_summary().peak_t_off >= 0, "and the peak is not before the fight, got " .. tostring(Vermilion.Graph.export_summary().peak_t_off))
  G.on_flush_click()
  H.damage_out({ hit = 50000, ability_id = 31, target_unit_id = 900 })
  G.on_flush_click()
  H.shield_out({ hit = 400 })
  H.advance(60000)
  G.on_record_click()
  H.advance(1500)
  H.damage_out({ hit = 100, ability_id = 31, target_unit_id = 900 })
  H.advance(1000)
  H.damage_out({ hit = 100, ability_id = 31, target_unit_id = 900 })
  local _, shd_old = M.totals()
  ok(shd_old == 0, "a shield from before Record is not in the new session, got " .. tostring(shd_old))
  ok(M.fight_ms() == 1000, "and it does not stretch the start of the fight, got " .. tostring(M.fight_ms()))
  G.on_stop_click()
  H.shield_out({ hit = 500 })
  H.advance(30000)
  G.on_flush_click()
  G.on_record_click()
  H.damage_out({ hit = 700, ability_id = 31, target_unit_id = 900 })
  H.advance(2000)
  local _, shd_after = M.totals()
  ok(shd_after == 0, "nor is one from after the last Stop, got " .. tostring(shd_after))
  ok(M.fight_ms() == 0, "one hit is no fight yet, got " .. tostring(M.fight_ms()))
  local dmg3, _, _, hits3 = M.totals()
  ok(dmg3 == 700 and hits3 == 1, "the next recording counts from zero, got " .. tostring(dmg3))
  G.on_stop_click()
  G.on_flush_click()
  H.damage_out({ hit = 700, ability_id = 31, target_unit_id = 900 })
  G.on_record_click()
  H.damage_out({ hit = 900, ability_id = 31, target_unit_id = 900 })
  local dmg4 = M.totals()
  ok(dmg4 == 900, "a new recording after New counts only its own hits, got " .. tostring(dmg4))
  G.on_stop_click()
  G.on_flush_click()
  Vermilion.Visibility.set("graph", false)
  M.reset()
end
