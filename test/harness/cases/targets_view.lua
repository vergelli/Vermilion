return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G, TV = Vermilion.Graph, Vermilion.TargetsView
  local view_label = VermilionGraphWindowViewLabel

  Vermilion.Metrics.reset()
  Vermilion.TemporalBuffer.clear()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  while view_label._text ~= "PRESSURE" do G.next_view() end
  ok(VermilionGraphTab3Label._text == "PRESSURE", "the third tab reads PRESSURE")
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

  local canvas0 = VermilionGraphWindowViewportCanvas
  local right_x = canvas0:GetWidth() - 118
  local cells, orchid_cells, bars, tails, names = 0, 0, 0, 0, {}
  local bar_w = {}
  for _, c in ipairs(H.controls) do
    local name = c._name or ""
    if c._hidden == false and name:find("^VermilionTargetSeg") and c._h and c._h > 3 and (c._a or 0) > 0.5 then
      local ox = c._anchor_list and c._anchor_list[1].ox or 0
      local orchid = math.abs((c._r or 0) - 0.85) < 0.03 and math.abs((c._g or 0) - 0.40) < 0.03 and math.abs((c._b or 0) - 0.75) < 0.03
      if ox >= right_x then
        if orchid then tails = tails + 1
        elseif math.abs((c._r or 0) - 0.98) < 0.03 and math.abs((c._g or 0) - 0.55) < 0.03 then bars = bars + 1; bar_w[#bar_w + 1] = c._w end
      else
        cells = cells + 1
        if orchid then orchid_cells = orchid_cells + 1 end
      end
    end
    if c._hidden == false and name:find("^VermilionTargetLbl") and c._text then names[c._text] = true end
  end
  ok(cells >= 4, "the lanes carry heat cells, got " .. cells)
  ok(orchid_cells == 0, "cells encode pressure only, never the shield, got " .. orchid_cells)
  ok(bars == 2, "the subplot on the right draws one accumulated bar per lane, got " .. bars)
  table.sort(bar_w, function(a, b) return a > b end)
  ok(bar_w[1] > bar_w[2], "the accumulated bars follow the totals")
  ok(tails == 1, "the shielded enemy's accumulated bar wears an orchid tail, got " .. tails)
  ok(names["Sorc"] and names["Templar"], "each lane wears its enemy's name")

  local lut0, lut_hi = TV.lut(0), TV.lut(127)
  ok(lut0[3] > 0.45 and lut0[1] < 0.15 and lut_hi[1] > 0.9 and lut_hi[2] > 0.9, "the pressure ramp runs from deep blue to yellow")
  local faint, solid = 0, 0
  for _, c in ipairs(H.controls) do
    local name = c._name or ""
    if c._hidden == false and name:find("^VermilionTargetSeg") and c._h and c._h > 3 then
      if (c._a or 0) >= 0.99 then solid = solid + 1 elseif (c._a or 0) > 0.25 and (c._a or 0) < 0.99 then faint = faint + 1 end
    end
  end
  ok(solid >= 1 and faint >= 1, "low pressure fades in while high pressure is solid, faint=" .. faint .. " solid=" .. solid)

  local canvas = VermilionGraphWindowViewportCanvas
  local hit = VermilionGraphHit
  local chip_h = (VermilionGraphSummaryBg._hidden == false) and (VermilionGraphSummaryBg._h + 8) or 0
  H.state.mouse_x = canvas:GetLeft() + 168 + math.floor((canvas:GetWidth() - 168) * 0.45)
  H.state.mouse_y = canvas:GetTop() + chip_h + 12 + 6
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
  ok(TV.hovered() ~= nil and TV.hovered().id == 900, "the hovered lane is tracked")
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
  local focus_row, switch_row = nil, nil
  for i = 1, 13 do
    local rn = rawget(_G, "VermilionHoverCardRowName" .. i)
    if rn and rn._hidden == false and rn._text == "Time on main target" then focus_row = rawget(_G, "VermilionHoverCardRowVal" .. i)._text end
    if rn and rn._hidden == false and rn._text == "Target switches" then switch_row = rawget(_G, "VermilionHoverCardRowVal" .. i)._text end
  end
  ok(focus_row == "100%", "the Sorc took the most pressure in every sample, got " .. tostring(focus_row))
  ok(switch_row == "0", "no target switch happened, got " .. tostring(switch_row))
  sum_hit._onOnMouseExit(sum_hit)

  local sess = Vermilion.SessionStore.capture()
  ok(sess.streams.targets ~= nil and sess.desc.targets ~= nil, "the session persists the targets stream")
  G.on_flush_click()
  local gone, gn = TV.rows()
  ok(gn == 0 or Vermilion.TemporalBuffer.count() == 0, "flushing empties the lanes")
  ok(G.load_session(sess), "the session reloads")
  while view_label._text ~= "PRESSURE" do G.next_view() end
  local lrows, ln = TV.rows()
  ok(ln == 2 and lrows[1].name == "Sorc" and lrows[1].abs > 0, "a library session rebuilds the lanes with names and absorbed totals")
  ok(math.abs(lrows[1].total - rows[1].total) < 1, "the library lane equals the live lane, " .. tostring(lrows[1].total) .. " vs " .. tostring(rows[1].total))

  G.on_flush_click()
  H.advance(31000)
  G.on_record_click()
  for i = 1, 6 do
    H.damage_out({ hit = 800, ability_id = 31, target_name = "Skeleton^n", target_type = COMBAT_UNIT_TYPE_NONE, target_unit_id = 910 })
    H.damage_out({ hit = 800, ability_id = 31, target_name = "Skeleton^n", target_type = COMBAT_UNIT_TYPE_NONE, target_unit_id = 911 })
    H.damage_out({ hit = 100, ability_id = 31, target_name = "Skeleton^n", target_type = COMBAT_UNIT_TYPE_NONE, target_unit_id = 912 })
    if i > 3 then H.damage_out({ hit = 3000, ability_id = 31, target_name = "Warden^Fx", target_unit_id = 920 }) end
    H.advance(1000)
  end
  G.on_stop_click()
  local frows, fn = TV.rows()
  ok(fn == 2, "three skeletons fold into one lane while the player keeps its own, got " .. tostring(fn))
  local skel = (frows[1].raw == "Skeleton^n") and frows[1] or frows[2]
  ok(skel and skel.n == 3 and not skel.is_player and skel.name == "Skeleton", "the folded lane counts its three units and drops the NPC suffix")
  local folded_label = false
  for _, c in ipairs(H.controls) do
    if c._hidden == false and (c._name or ""):find("^VermilionTargetLbl") and c._text == "Skeleton  ×3" then folded_label = true end
  end
  ok(folded_label, "the folded lane says how many units it holds")
  local on_top, switches, lanes = TV.focus()
  ok(lanes == 2 and switches == 1, "the pressure moved once from the skeletons to the warden, got " .. tostring(switches))

  while view_label._text ~= "SKILL" do G.next_view() end
  G.on_flush_click()
  H.ability_names = nil
  Vermilion.Visibility.set("graph", false)
  Vermilion.Metrics.reset()
end
