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
end
