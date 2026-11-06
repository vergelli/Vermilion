return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local fill, bg, fly = VermilionAssignPanelFlyoutFill, VermilionAssignPanelFlyoutBg, VermilionAssignPanelFlyout
  ok(fill._xml_tag == "Texture", "the flyout carries a solid fill texture behind the rows")
  ok(fill._draw_layer == DL_OVERLAY and bg._draw_layer == DL_OVERLAY, "fill and backdrop sit on the overlay layer")
  ok((fill._a or 0) >= 0.98, "the fill is opaque, got " .. tostring(fill._a))
  ok((bg._ca or 0) >= 0.98, "the backdrop centre is opaque, got " .. tostring(bg._ca))
  ok((fill._draw_level or 0) > (fly._draw_level or 0) and (bg._draw_level or 0) > (fill._draw_level or 0),
     "flyout below fill below backdrop in draw level")
  ok(math.abs((bg._er or 0) - 1.00) < 0.01 and math.abs((bg._eg or 0) - 0.45) < 0.01, "the edge keeps the crimson identity")

  local SC = Vermilion.SkillColors
  local real = SC.get_unknowns
  SC.get_unknowns = function() return { { id = 987654, name = "Test Skill", icon = "" } } end
  Vermilion.Assign.refresh()
  SC.get_unknowns = real
  local pick = rawget(_G, "VermilionAssignRow1Pick")
  ok(pick ~= nil, "a row was built with its button")
  ok(pick._normal == Vermilion.Skin.PLAIN.up, "the row button carries the skin, got " .. tostring(pick._normal))
  ok(pick._text == "Pick Category", "and the capitalised text, got " .. tostring(pick._text))
  Vermilion.Assign.refresh()
end
