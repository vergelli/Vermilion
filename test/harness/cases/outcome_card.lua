return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G = Vermilion.Graph
  local view_label = VermilionGraphWindowViewLabel

  Vermilion.Metrics.reset()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  while view_label._text ~= "OUTCOME" do G.next_view() end
  H.ability_names = { [31] = "Puncturing Sweep", [41] = "Hardened Ward", [42] = "Reviving Barrier" }

  G.on_record_click()
  for i = 1, 6 do
    H.damage_out({ hit = 1000, ability_id = 31, target_unit_id = 900 })
    H.shield_out({ hit = 200, ability_id = 41, target_type = COMBAT_UNIT_TYPE_OTHER, target_unit_id = 900 })
    H.damage_out({ hit = 0, ability_id = 31, target_unit_id = 900 })
    if i == 2 then
      H.shield_out({ hit = 100, ability_id = 42, target_type = COMBAT_UNIT_TYPE_OTHER, target_unit_id = 901 })
      H.damage_out({ hit = 0, ability_id = 31, target_unit_id = 901 })
    end
    H.advance(1000)
  end
  G.on_stop_click()

  local canvas = VermilionGraphWindowViewportCanvas
  local hit = VermilionGraphHit
  H.state.mouse_x = canvas:GetLeft() + canvas:GetWidth() - 3
  H.state.mouse_y = canvas:GetBottom() - 22
  hit._onOnMouseEnter(hit)
  H.advance(200)
  ok(VermilionHoverCardName._text == "Shields cracked", "hovering an OUTCOME column opens the shield card, got " .. tostring(VermilionHoverCardName._text))
  local names = {}
  for i = 1, 9 do
    local rn = rawget(_G, "VermilionHoverCardRowName" .. i)
    if rn and rn._hidden == false then names[rn._text] = rawget(_G, "VermilionHoverCardRowVal" .. i)._text end
  end
  ok(names["Hardened Ward"] ~= nil and names["Reviving Barrier"] ~= nil, "the card lists the enemy shields by name")
  ok(names["Hardened Ward"]:find("%%") ~= nil, "each shield row carries its share, got " .. tostring(names["Hardened Ward"]))
  ok((VermilionHoverCardStat._text or ""):find("Shld", 1, true) ~= nil, "the card stat keeps the outgoing split")
  hit._onOnMouseExit(hit)
  H.state.mouse_x, H.state.mouse_y = 400, 300

  local sum_hit = VermilionGraphSummaryHit
  sum_hit._onOnMouseEnter(sum_hit)
  local top = nil
  for i = 1, 9 do
    local rn = rawget(_G, "VermilionHoverCardRowName" .. i)
    if rn and rn._hidden == false and rn._text == "Cracked most" then top = rawget(_G, "VermilionHoverCardRowVal" .. i)._text end
  end
  ok(top ~= nil and top:find("Hardened Ward", 1, true) ~= nil, "the report names the shield that absorbed the most, got " .. tostring(top))
  sum_hit._onOnMouseUp(sum_hit, nil, true)
  local eb = rawget(_G, "VermilionCopyBoxEdit")
  ok(eb and (eb._text or ""):find("Cracked most: Hardened Ward", 1, true) ~= nil, "the copied report carries the row")
  Vermilion.CopyBox.hide()
  sum_hit._onOnMouseExit(sum_hit)

  local sess = Vermilion.SessionStore.capture()
  G.on_flush_click()
  ok(G.load_session(sess), "the session reloads")
  while view_label._text ~= "OUTCOME" do G.next_view() end
  H.state.mouse_x = canvas:GetLeft() + canvas:GetWidth() - 3
  H.state.mouse_y = canvas:GetBottom() - 22
  hit._onOnMouseEnter(hit)
  H.advance(200)
  local again = false
  for i = 1, 9 do
    local rn = rawget(_G, "VermilionHoverCardRowName" .. i)
    if rn and rn._hidden == false and rn._text == "Hardened Ward" then again = true end
  end
  ok(again, "a library session lists the enemy shields too")
  hit._onOnMouseExit(hit)
  H.state.mouse_x, H.state.mouse_y = 400, 300

  while view_label._text ~= "SKILL" do G.next_view() end
  G.on_flush_click()
  H.ability_names = nil
  Vermilion.Visibility.set("graph", false)
  Vermilion.Metrics.reset()
end
