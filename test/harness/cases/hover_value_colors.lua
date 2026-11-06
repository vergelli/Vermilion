return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G, HC = Vermilion.Graph, Vermilion.HoverCard

  Vermilion.Metrics.reset()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  G.on_record_click()
  for _ = 1, 20 do
    H.damage_out({ hit = 1000, ability_id = 31, target_unit_id = 900 })
    H.damage_out({ hit = 500, ability_id = 32, target_unit_id = 900 })
    H.advance(1000)
  end
  G.on_stop_click()
  while VermilionGraphWindowViewLabel._text ~= "SKILL" do G.next_view() end

  local BLUE, GREEN = { r = 0.2, g = 0.3, b = 0.9 }, { r = 0.2, g = 0.9, b = 0.3 }
  HC.show_rows(BLUE, "Magicka", "", "", { { "a", "1", BLUE }, { "b", "2", GREEN } }, 2, nil, 10, 10)
  local val1, val2 = VermilionHoverCardRowVal1, VermilionHoverCardRowVal2
  ok(val1._b == BLUE.b and val2._g == GREEN.g, "a resource card paints its own values")

  local canvas, hit = VermilionGraphWindowViewportCanvas, VermilionGraphHit
  H.state.mouse_x = canvas:GetLeft() + canvas:GetWidth() / 2
  H.state.mouse_y = canvas:GetTop() + canvas:GetHeight() - 24
  hit._onOnMouseEnter(hit)
  H.advance(200)
  ok(VermilionHoverCardRowName1._hidden == false and val1._hidden == false, "hovering a bar lists its skills")
  ok((val1._text or ""):find("%%") ~= nil, "with a value and a share, got " .. tostring(val1._text))
  local rows = 0
  for i = 1, 2 do
    local v = rawget(_G, "VermilionHoverCardRowVal" .. i)
    if v._hidden == false then
      rows = rows + 1
      ok(v._b ~= BLUE.b and v._g ~= GREEN.g, "row " .. i .. " does not inherit the colours of the last card")
      ok(v._r == 1.00 and v._g == 0.42 and v._b == 0.32, "row " .. i .. " is damage, in the damage colour, got " .. tostring(v._r) .. "," .. tostring(v._g) .. "," .. tostring(v._b))
    end
  end
  ok(rows >= 1, "at least one row was checked")
  hit._onOnMouseExit(hit)

  HC.show_rows(BLUE, "Magicka", "", "", { { "a", "1", BLUE }, { "b", "2", GREEN } }, 2, nil, 10, 10)
  local chip = VermilionGraphSummaryHit
  chip._onOnMouseEnter(chip)
  ok(VermilionHoverCardName._text == "Damage report", "the header card opens")
  ok(val1._b ~= BLUE.b and val2._g ~= GREEN.g, "and its values do not inherit them either, got " .. tostring(val1._b) .. " and " .. tostring(val2._g))
  chip._onOnMouseExit(chip)

  H.state.mouse_x, H.state.mouse_y = 400, 300
  G.on_flush_click()
  Vermilion.Visibility.set("graph", false)
  Vermilion.Metrics.reset()
end
