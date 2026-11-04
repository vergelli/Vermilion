return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G, M = Vermilion.Graph, Vermilion.Metrics

  M.reset()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  G.on_record_click()
  H.damage_out({ hit = 1000, ability_id = 31 })
  H.damage_out({ hit = 500, ability_id = 77, source_type = COMBAT_UNIT_TYPE_PLAYER_PET, source_unit_id = 501 })
  H.damage_out({ hit = 300, ability_id = 77, source_type = COMBAT_UNIT_TYPE_PLAYER_PET, source_unit_id = 501, target_type = COMBAT_UNIT_TYPE_PLAYER_PET })
  H.damage_out({ hit = 200, ability_id = 88, source_type = COMBAT_UNIT_TYPE_OTHER, source_unit_id = 700 })
  local dmg, _, _, hits = M.totals()
  ok(dmg == 1500, "a pet's hit counts as yours, nobody else's does, got " .. dmg)
  ok(hits == 2, "and so does its count, got " .. hits)
  H.advance(3000)
  G.on_stop_click()
  local order, n = Vermilion.ContribView.compute()
  local found
  for i = 1, n do
    if order[i].name == GetAbilityName(77) then found = order[i] end
  end
  ok(found and found.v > 0, "the pet's ability has its row")

  G.on_flush_click()
  Vermilion.Visibility.set("graph", false)
  M.reset()
end
