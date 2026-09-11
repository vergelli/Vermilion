return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G, MT = Vermilion.Graph, Vermilion.Metrics
  local view_label = VermilionGraphWindowViewLabel

  Vermilion.Metrics.reset()
  Vermilion.TemporalBuffer.clear()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  H.advance(31000)
  while view_label._text ~= "PRESSURE" do G.next_view() end
  H.ability_names = { [31] = "Puncturing Sweep", [224947] = "Frigid Waters" }

  G.on_record_click()
  for _ = 1, 4 do
    H.damage_out({ hit = 1000, ability_id = 31, target_name = "Sorc^Mx", target_unit_id = 900 })
    H.damage_out({ hit = 474, ability_id = 224947, target_name = "Me^Mx", target_type = COMBAT_UNIT_TYPE_PLAYER, target_unit_id = 500, damage_type = DAMAGE_TYPE_COLD })
    H.shield_out({ hit = 300, ability_id = 41, target_name = "Me^Mx", target_type = COMBAT_UNIT_TYPE_PLAYER, target_unit_id = 500 })
    H.damage_out({ hit = 0, ability_id = 224947, target_name = "Me^Mx", target_type = COMBAT_UNIT_TYPE_PLAYER, target_unit_id = 500 })
    H.advance(1000)
  end
  G.on_stop_click()

  local total_damage, total_shield, _, hits = MT.totals()
  ok(total_damage == 4000, "only the damage to the enemy counts, got " .. tostring(total_damage))
  ok(total_shield == 0, "your own shield eating your own damage is not a cracked shield, got " .. tostring(total_shield))
  ok(hits == 4, "self hits are not hits, got " .. tostring(hits))

  local rows, n = Vermilion.TargetsView.rows()
  ok(n == 1 and rows[1].name == "Sorc", "PRESSURE never shows a lane with your own name, got " .. tostring(n) .. " / " .. tostring(rows[1] and rows[1].name))

  while view_label._text ~= "CONTRIB" do G.next_view() end
  local crows, cn = Vermilion.ContribView.rows()
  local frigid = false
  for i = 1, cn do if crows[i].name == "Frigid Waters" then frigid = true end end
  ok(not frigid, "self damage is not a contribution")

  while view_label._text ~= "SKILL" do G.next_view() end
  G.on_flush_click()
  H.ability_names = nil
  Vermilion.Visibility.set("graph", false)
  Vermilion.Metrics.reset()
end
