return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G, TV = Vermilion.Graph, Vermilion.TargetsView
  local view_label = VermilionGraphWindowViewLabel

  Vermilion.Metrics.reset()
  Vermilion.TemporalBuffer.clear()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  while view_label._text ~= "TARGETS" do G.next_view() end
  ok(VermilionGraphTab3Label._text == "TARGETS", "the third tab reads TARGETS")
  H.ability_names = { [31] = "Puncturing Sweep", [41] = "Hardened Ward" }

  G.on_record_click()
  for i = 1, 8 do
    H.damage_out({ hit = 1000, ability_id = 31, target_name = "Sorc^Mx", target_unit_id = 900 })
    if i <= 4 then
      H.damage_out({ hit = 300, ability_id = 31, target_name = "Templar", target_unit_id = 901 })
    end
    if i >= 3 and i <= 5 then
      H.shield_out({ hit = 500, ability_id = 41, target_name = "Sorc", target_type = COMBAT_UNIT_TYPE_OTHER, target_unit_id = 900 })
      H.damage_out({ hit = 0, ability_id = 31, target_name = "Sorc", target_unit_id = 900 })
    end
    H.advance(1000)
  end
  local live_rows, live_n = TV.rows()
  ok(live_n == 2, "two enemies make two lanes while recording, got " .. tostring(live_n))
  G.on_stop_click()

  local rows, n = TV.rows()
  ok(n == 2, "two lanes after stop, got " .. tostring(n))
  ok(rows[1].name == "Sorc" and rows[2].name == "Templar", "lanes are ordered by damage taken and names lose the gender suffix, got " .. tostring(rows[1].name) .. " / " .. tostring(rows[2].name))
  ok(rows[1].abs > 0 and rows[2].abs == 0, "only the shielded enemy carries an absorbed total")
  local t = TV.totals()
  ok(math.abs((rows[1].total + rows[2].total) - t.damage) < 1e-6, "lane totals add up to the output total")

  local cells, orchid_cells, tails, names = 0, 0, 0, {}
  for _, c in ipairs(H.controls) do
    local name = c._name or ""
    if c._hidden == false and name:find("^VermilionTargetSeg") then
      if c._h and c._h > 3 and (c._a or 0) > 0.5 then
        cells = cells + 1
        if (c._b or 0) > 0.7 * (c._r or 1) and (c._g or 1) < 0.6 then orchid_cells = orchid_cells + 1 end
      elseif c._h == 3 and (c._b or 0) > 0.7 and (c._r or 0) > 0.8 and (c._g or 1) < 0.6 then
        tails = tails + 1
      end
    end
    if c._hidden == false and name:find("^VermilionTargetLbl") and c._text then names[c._text] = true end
  end
  ok(cells >= 4, "the lanes carry heat cells, got " .. cells)
  ok(orchid_cells == 0, "cells encode pressure only, never the shield, got " .. orchid_cells)
  ok(tails == 1, "the shielded enemy's gutter bar wears an orchid tail, got " .. tails)
  ok(names["Sorc"] and names["Templar"], "each lane wears its enemy's name")

  local lut0, lut_hi = TV.lut(0), TV.lut(127)
  ok(lut0[1] >= 0.25 and lut0[1] < 0.4 and lut_hi[1] > 0.95 and lut_hi[2] > 0.8, "the heat ramp runs from a visible dark crimson to pale yellow")

  local canvas = VermilionGraphWindowViewportCanvas
  local hit = VermilionGraphHit
  local chip_h = (VermilionGraphSummaryBg._hidden == false) and (VermilionGraphSummaryBg._h + 8) or 0
  H.state.mouse_x = canvas:GetLeft() + 168 + math.floor((canvas:GetWidth() - 168) * 0.45)
  H.state.mouse_y = canvas:GetTop() + chip_h + 6
  hit._onOnMouseEnter(hit)
  H.advance(200)
  ok(VermilionHoverCardName._text == "Sorc", "hovering the first lane names the enemy, got " .. tostring(VermilionHoverCardName._text))
  ok((VermilionHoverCardStat._text or ""):find("DPS", 1, true) ~= nil, "the card reads the rate at that moment, got " .. tostring(VermilionHoverCardStat._text))
  local labels = {}
  for i = 1, 11 do
    local rn = rawget(_G, "VermilionHoverCardRowName" .. i)
    if rn and rn._hidden == false then labels[rn._text] = rawget(_G, "VermilionHoverCardRowVal" .. i)._text end
  end
  ok(labels["Damage"] ~= nil and labels["Share of your output"] ~= nil, "the card carries the enemy's totals and share")
  ok(labels["Absorbed by shields"] ~= nil, "the shielded enemy shows its absorbed total")
  ok(TV.hovered() == 900, "the hovered lane is tracked")
  hit._onOnMouseExit(hit)
  H.state.mouse_x, H.state.mouse_y = 400, 300

  local sum_hit = VermilionGraphSummaryHit
  sum_hit._onOnMouseEnter(sum_hit)
  local focused = nil
  for i = 1, 11 do
    local rn = rawget(_G, "VermilionHoverCardRowName" .. i)
    if rn and rn._hidden == false and rn._text == "Focused most" then focused = rawget(_G, "VermilionHoverCardRowVal" .. i)._text end
  end
  ok(focused ~= nil and focused:find("Sorc", 1, true) ~= nil, "the report names the enemy you focused most, got " .. tostring(focused))
  sum_hit._onOnMouseExit(sum_hit)

  local sess = Vermilion.SessionStore.capture()
  ok(sess.streams.targets ~= nil and sess.desc.targets ~= nil, "the session persists the targets stream")
  G.on_flush_click()
  local gone, gn = TV.rows()
  ok(gn == 0 or Vermilion.TemporalBuffer.count() == 0, "flushing empties the lanes")
  ok(G.load_session(sess), "the session reloads")
  while view_label._text ~= "TARGETS" do G.next_view() end
  local lrows, ln = TV.rows()
  ok(ln == 2 and lrows[1].name == "Sorc" and lrows[1].abs > 0, "a library session rebuilds the lanes with names and absorbed totals")
  ok(math.abs(lrows[1].total - rows[1].total) < 1, "the library lane equals the live lane, " .. tostring(lrows[1].total) .. " vs " .. tostring(rows[1].total))

  while view_label._text ~= "SKILL" do G.next_view() end
  G.on_flush_click()
  H.ability_names = nil
  Vermilion.Visibility.set("graph", false)
  Vermilion.Metrics.reset()
end
