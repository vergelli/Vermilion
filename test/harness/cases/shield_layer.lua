return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G = Vermilion.Graph
  local view_label = VermilionGraphWindowViewLabel

  Vermilion.Metrics.reset()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  while view_label._text ~= "SKILL" do G.next_view() end
  H.ability_names = { [31] = "Puncturing Sweep" }

  G.on_record_click()
  for i = 1, 8 do
    H.damage_out({ hit = 1000, ability_id = 31, target_unit_id = 900, damage_type = DAMAGE_TYPE_MAGIC })
    if i >= 3 and i <= 6 then
      H.shield_out({ hit = 500, ability_id = 41, target_type = COMBAT_UNIT_TYPE_OTHER, target_unit_id = 900 })
      H.damage_out({ hit = 0, ability_id = 31, target_unit_id = 900, damage_type = DAMAGE_TYPE_MAGIC })
    end
    H.advance(1000)
  end
  G.on_stop_click()

  local function hang_fills()
    local fills, edges = {}, 0
    for _, c in ipairs(H.controls) do
      local name = c._name or ""
      if c._hidden == false and name:find("^VermilionHangFill") then
        if c._h == 1 then edges = edges + 1 else fills[#fills + 1] = c end
      end
    end
    return fills, edges
  end
  local fills, edges = hang_fills()
  ok(#fills >= 1, "the absorbed damage hangs from the top of the viewport in SKILL, got " .. #fills)
  ok(edges == #fills, "every hanging column wears its dotted lower edge")
  local canvas = VermilionGraphWindowViewportCanvas
  local chip_h = (VermilionGraphSummaryBg._hidden == false) and (VermilionGraphSummaryBg._h + 8) or 0
  for _, f in ipairs(fills) do
    local a = f._anchor_list and f._anchor_list[1]
    ok(a and a.point == TOPLEFT and a.oy == chip_h, "a hanging column starts right under the chip, got " .. tostring(a and a.oy))
    ok(math.abs((f._r or 0) - 0.85) < 1e-6 and math.abs((f._b or 0) - 0.75) < 1e-6 and (f._a or 1) < 0.3, "the hanging fill is faint orchid")
  end

  local ward_bars = 0
  for _, c in ipairs(H.controls) do
    local name = c._name or ""
    if c._hidden == false and name:find("^VermilionEosSeg") and c._r and math.abs(c._r - 0.85) < 1e-6 and math.abs(c._b - 0.75) < 1e-6 then ward_bars = ward_bars + 1 end
  end
  ok(ward_bars == 0, "no orchid segment sits inside the skill stack, the absorbed part is credited to the attack")

  local ch = canvas:GetHeight()
  local hit = VermilionGraphHit
  local f = fills[1]
  local fx = f._anchor_list[1].ox
  H.state.mouse_x = canvas:GetLeft() + fx + 1
  H.state.mouse_y = canvas:GetTop() + chip_h + 2
  hit._onOnMouseEnter(hit)
  H.advance(200)
  ok(VermilionHoverCardName._text == "Shields cracked", "hovering the hanging layer opens the shield card, got " .. tostring(VermilionHoverCardName._text))
  ok((VermilionHoverCardStat._text or ""):find("DPS", 1, true) ~= nil and (VermilionHoverCardStat._text or ""):find("%%") ~= nil, "the shield card reads the absorbed rate and share, got " .. tostring(VermilionHoverCardStat._text))
  ok(VermilionHoverCardSwatch._tex == "EsoUI/Art/Inventory/inventory_tabIcon_shield_up.dds", "the shield card wears the shield icon")
  hit._onOnMouseExit(hit)
  H.state.mouse_x, H.state.mouse_y = 400, 300

  while view_label._text ~= "TYPE" do G.next_view() end
  local tfills = hang_fills()
  ok(#tfills >= 1, "the layer hangs in TYPE too")
  while view_label._text ~= "OUTCOME" do G.next_view() end
  local ofills = hang_fills()
  ok(#ofills == 0, "OUTCOME already stacks the absorbed part, no layer there")
  while view_label._text ~= "CRIT" do G.next_view() end
  local cfills = hang_fills()
  ok(#cfills == 0, "CRIT stays about landed damage, no layer there")

  while view_label._text ~= "SKILL" do G.next_view() end
  G.on_flush_click()
  local gone = hang_fills()
  ok(#gone == 0, "flushing clears the layer")
  H.ability_names = nil
  Vermilion.Visibility.set("graph", false)
  Vermilion.Metrics.reset()
end
