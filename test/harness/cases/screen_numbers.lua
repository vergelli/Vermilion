return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G, TV, UV = Vermilion.Graph, Vermilion.TargetsView, Vermilion.UptimeView

  Vermilion.Metrics.reset()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  G.on_record_click()
  for _ = 1, 12 do
    H.damage_out({ hit = 1000, ability_id = 31, target_name = "Corrupted Infantry^M", target_type = COMBAT_UNIT_TYPE_NONE, target_unit_id = 801 })
    H.damage_out({ hit = 1000, ability_id = 31, target_name = "Corrupted Infantry^F", target_type = COMBAT_UNIT_TYPE_NONE, target_unit_id = 802 })
    H.damage_out({ hit = 1500, ability_id = 32, target_name = "Spider^n", target_type = COMBAT_UNIT_TYPE_NONE, target_unit_id = 803 })
    H.advance(1000)
  end
  H.advance(6000)
  G.on_stop_click()

  local rows = TV.compute()
  ok(rows[1].name == "Corrupted Infantry", "the targets view ranks the merged enemy first, got " .. tostring(rows[1].name))
  local hit = VermilionGraphSummaryHit
  hit._onOnMouseEnter(hit)
  local top
  for i = 1, 13 do
    local name = rawget(_G, "VermilionHoverCardRowName" .. i)
    if name and name._hidden == false and name._text == "Focused most" then top = rawget(_G, "VermilionHoverCardRowVal" .. i)._text end
  end
  hit._onOnMouseExit(hit)
  ok(top and top:find("Corrupted Infantry", 1, true), "the report names the same enemy the targets view ranks first, got " .. tostring(top))
  ok(not top:find("Spider", 1, true), "a single unit that dealt with less total does not win over a merged enemy")

  ok(GetString(VERMILION_CRIT_MOMENT):find("crit damage", 1, true), "the moment card in the CRIT view says it is damage, the header counts hits")
  ok(UV.priced({ cost = 100, slot = true, ult = false, dur = 8000 }) == true, "a slotted effect of six seconds or more is priced")
  ok(not UV.priced({ cost = 100, slot = true, ult = false, dur = 3000 }), "a short effect is not")
  ok(not UV.priced({ cost = 100, slot = false, ult = false, dur = 8000 }), "a proc is not")
  ok(not UV.priced({ cost = 100, slot = true, ult = true, dur = 8000 }), "an ultimate is not")

  G.on_flush_click()
  Vermilion.Visibility.set("graph", false)
  Vermilion.Metrics.reset()
end
