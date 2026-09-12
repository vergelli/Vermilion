return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G, K = Vermilion.Graph, Vermilion.Kills
  local view_label = VermilionGraphWindowViewLabel

  Vermilion.Metrics.reset()
  Vermilion.TemporalBuffer.clear()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  H.advance(31000)
  while view_label._text ~= "SKILL" do G.next_view() end
  H.ability_names = { [31] = "Puncturing Sweep" }

  H.kill({ target_name = "Sorc^Mx", target_unit_id = 900 })
  ok(K.count() == 0, "a kill outside a recording is not kept")

  G.on_record_click()
  for i = 1, 8 do
    H.damage_out({ hit = 1000, ability_id = 31, target_name = "Sorc^Mx", target_unit_id = 900 })
    H.damage_out({ hit = 400, ability_id = 31, target_name = "Skeleton^n", target_type = COMBAT_UNIT_TYPE_NONE, target_unit_id = 910 })
    if i == 5 then
      H.kill({ target_name = "Sorc^Mx", target_unit_id = 900, ability_id = 31, result = ACTION_RESULT_KILLING_BLOW })
      H.kill({ target_name = "Sorc^Mx", target_unit_id = 900, ability_id = 31, result = ACTION_RESULT_DIED_XP })
    end
    if i == 7 then H.kill({ target_name = "Skeleton^n", target_type = COMBAT_UNIT_TYPE_NONE, target_unit_id = 910, ability_id = 31 }) end
    H.advance(1000)
  end
  G.on_stop_click()
  ok(K.count() == 2, "both result codes count and the same death is never counted twice, got " .. K.count())

  local function skulls()
    local n, xs = 0, {}
    for _, c in ipairs(H.controls) do
      if c._hidden == false and (c._name or ""):find("^VermilionKillIcon") then
        n = n + 1
        xs[n] = c._anchor_list and c._anchor_list[1].ox or 0
      end
    end
    return n, xs
  end
  local n, xs = skulls()
  ok(n == 2 and xs[1] ~= xs[2], "SKILL marks both kills at different moments, got " .. n)
  for _, v in ipairs({ "TYPE", "CRIT", "PRESSURE" }) do
    while view_label._text ~= v do G.next_view() end
    local k = skulls()
    ok(k == 2, v .. " marks both kills, got " .. k)
  end
  for _, v in ipairs({ "CONTRIB", "DEBUFFS" }) do
    while view_label._text ~= v do G.next_view() end
    local k = skulls()
    ok(k == 0, v .. " carries no skulls, got " .. k)
  end

  while view_label._text ~= "PRESSURE" do G.next_view() end
  local ys = {}
  for _, c in ipairs(H.controls) do
    if c._hidden == false and (c._name or ""):find("^VermilionKillIcon") then ys[#ys + 1] = c._anchor_list[1].oy end
  end
  ok(#ys == 2 and ys[1] ~= ys[2], "in PRESSURE each skull sits on its victim's lane")

  while view_label._text ~= "SKILL" do G.next_view() end
  local canvas = VermilionGraphWindowViewportCanvas
  local hit = VermilionGraphHit
  local _, sx = skulls()
  local chip_h = (VermilionGraphSummaryBg._hidden == false) and (VermilionGraphSummaryBg._h + 8) or 0
  H.state.mouse_x = canvas:GetLeft() + sx[1] + 7
  H.state.mouse_y = canvas:GetTop() + chip_h + 2 + 7
  hit._onOnMouseEnter(hit)
  H.advance(200)
  ok(VermilionHoverCardName._text == "Sorc" or VermilionHoverCardName._text == "Skeleton", "hovering a skull names the victim, got " .. tostring(VermilionHoverCardName._text))
  ok((VermilionHoverCardStat._text or ""):find("Killing blow", 1, true) ~= nil and (VermilionHoverCardStat._text or ""):find("Puncturing Sweep", 1, true) ~= nil, "the skull card names the ability, got " .. tostring(VermilionHoverCardStat._text))
  hit._onOnMouseExit(hit)
  H.state.mouse_x, H.state.mouse_y = 400, 300

  local sum_hit = VermilionGraphSummaryHit
  sum_hit._onOnMouseEnter(sum_hit)
  local kills_row = nil
  for i = 1, 13 do
    local rn = rawget(_G, "VermilionHoverCardRowName" .. i)
    if rn and rn._hidden == false and rn._text == "Killing blows" then kills_row = rawget(_G, "VermilionHoverCardRowVal" .. i)._text end
  end
  ok(kills_row == "2", "the report counts the killing blows, got " .. tostring(kills_row))
  sum_hit._onOnMouseExit(sum_hit)

  local S = Vermilion.Settings
  ok(S.kill_markers() == true, "kill markers are on by default")
  ok(VermilionSettingsPanelKillsBtn._text == "Kill markers: On", "the settings button says so, got " .. tostring(VermilionSettingsPanelKillsBtn._text))
  S.on_kills_click()
  ok(S.kill_markers() == false and VermilionSettingsPanelKillsBtn._text == "Kill markers: Off", "one click turns the markers off")
  ok(skulls() == 0, "with markers off SKILL draws no skull")
  while view_label._text ~= "PRESSURE" do G.next_view() end
  ok(skulls() == 0, "with markers off PRESSURE draws no skull either")
  sum_hit._onOnMouseEnter(sum_hit)
  local still = nil
  for i = 1, 13 do
    local rn = rawget(_G, "VermilionHoverCardRowName" .. i)
    if rn and rn._hidden == false and rn._text == "Killing blows" then still = rawget(_G, "VermilionHoverCardRowVal" .. i)._text end
  end
  ok(still == "2", "the report keeps counting kills with markers off, got " .. tostring(still))
  sum_hit._onOnMouseExit(sum_hit)
  S.on_kills_click()
  ok(S.kill_markers() == true and skulls() == 2, "turning the markers back on brings the skulls back")
  while view_label._text ~= "SKILL" do G.next_view() end

  local sess = Vermilion.SessionStore.capture()
  ok(sess.streams.kills ~= nil, "the session persists the kills")
  G.on_flush_click()
  ok(K.count() == 0, "flushing forgets the kills")
  ok(G.load_session(sess), "the session reloads")
  ok(K.count() == 2, "a library session brings its kills back, got " .. K.count())
  local _, kuid, kname = K.get(1)
  ok(kuid == 900 and kname == "Sorc^Mx", "the kill keeps its victim")
  local k2 = skulls()
  ok(k2 == 2, "the loaded session draws its skulls, got " .. k2)
  S.on_reset_click()
  ok(S.kill_markers() == true, "reset to defaults keeps the markers on")

  G.on_flush_click()
  H.ability_names = nil
  Vermilion.Visibility.set("graph", false)
  Vermilion.Metrics.reset()
end
