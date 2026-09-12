return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G = Vermilion.Graph
  local view_label = VermilionGraphWindowViewLabel
  local SHIELD_ICON = "EsoUI/Art/Inventory/inventory_tabIcon_shield_up.dds"

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

  local function shown(prefix)
    local list = {}
    for _, c in ipairs(H.controls) do
      if c._hidden == false and (c._name or ""):find(prefix) then list[#list + 1] = c end
    end
    return list
  end
  local function shield_icon()
    for _, c in ipairs(shown("^VermilionGraphUltIcon")) do
      if c._tex == SHIELD_ICON then return c end
    end
    return nil
  end

  ok(#shown("^VermilionHangFill") == 0, "nothing hangs from the top of the plot any more")
  local cells = shown("^VermilionShieldHeat")
  ok(#cells >= 1, "the shield strip shows heat cells in SKILL, got " .. #cells)
  local chip_h = (VermilionGraphSummaryBg._hidden == false) and (VermilionGraphSummaryBg._h + 8) or 0
  for _, c in ipairs(cells) do
    local a = c._anchor_list and c._anchor_list[1]
    ok(a and a.oy == chip_h + 3, "a strip cell sits right under the chip at the strip pad, got " .. tostring(a and a.oy))
    ok(c._h == 6, "a strip cell is one row tall, got " .. tostring(c._h))
    ok((c._a or 0) >= 0.3, "a strip cell carries heat alpha")
  end
  local icon = shield_icon()
  ok(icon ~= nil, "the strip wears the shield icon at its left")
  ok(icon and (icon._anchor_list[1].ox == 0), "the shield icon sits at the left edge like the ultimate icon")

  local canvas = VermilionGraphWindowViewportCanvas
  local hit = VermilionGraphHit
  local c1 = cells[1]
  H.state.mouse_x = canvas:GetLeft() + c1._anchor_list[1].ox + 1
  H.state.mouse_y = canvas:GetTop() + chip_h + 5
  hit._onOnMouseEnter(hit)
  H.advance(200)
  ok(VermilionHoverCardName._text == "Shields cracked", "hovering the strip opens the shield card, got " .. tostring(VermilionHoverCardName._text))
  ok((VermilionHoverCardStat._text or ""):find("DPS", 1, true) ~= nil and (VermilionHoverCardStat._text or ""):find("%%") ~= nil, "the shield card reads the absorbed rate and share, got " .. tostring(VermilionHoverCardStat._text))
  ok(VermilionHoverCardSwatch._tex == SHIELD_ICON, "the shield card wears the shield icon")
  hit._onOnMouseExit(hit)
  H.state.mouse_x, H.state.mouse_y = 400, 300

  local ward_bars = 0
  for _, c in ipairs(shown("^VermilionEosSeg")) do
    if c._r and math.abs(c._r - 0.85) < 1e-6 and math.abs(c._b - 0.75) < 1e-6 then ward_bars = ward_bars + 1 end
  end
  ok(ward_bars == 0, "no orchid segment sits inside the skill stack, the absorbed part is credited to the attack")

  while view_label._text ~= "TYPE" do G.next_view() end
  ok(#shown("^VermilionShieldHeat") >= 1, "the strip shows in TYPE")
  while view_label._text ~= "CRIT" do G.next_view() end
  ok(#shown("^VermilionShieldHeat") >= 1, "the strip shows in CRIT")
  while view_label._text ~= "PRESSURE" do G.next_view() end
  ok(#shown("^VermilionShieldHeat") >= 1, "the strip shows in PRESSURE")
  local subs = shown("^VermilionTargetSub")
  ok(#subs >= 1, "PRESSURE lanes carry an absorption sub-lane, got " .. #subs)
  local lanes = 0
  for _, c in ipairs(shown("^VermilionTargetSeg")) do if c._h and c._h > 3 and (c._a or 0) > 0.5 then lanes = lanes + 1 end end
  ok(lanes >= 1, "the pressure cells still draw above the sub-lane")
  for _, c in ipairs(subs) do
    ok(c._h and c._h >= 2 and c._h < 12, "a sub-lane cell is thin, got " .. tostring(c._h))
    ok(math.abs((c._r or 0) - 0.85) > 0.02 or math.abs((c._b or 0) - 0.75) > 0.02, "the sub-lane uses its own ramp, not orchid")
  end
  while view_label._text ~= "CONTRIB" do G.next_view() end
  ok(#shown("^VermilionShieldHeat") == 0, "CONTRIB is a list, no strip there")

  while view_label._text ~= "SKILL" do G.next_view() end
  G.on_flush_click()
  ok(#shown("^VermilionShieldHeat") == 0, "flushing clears the strip")
  ok(shield_icon() == nil, "flushing clears the shield icon")
  H.ability_names = nil
  Vermilion.Visibility.set("graph", false)
  Vermilion.Metrics.reset()
end
