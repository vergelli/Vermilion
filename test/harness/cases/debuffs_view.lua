return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local D = BUFF_EFFECT_TYPE_DEBUFF
  local G = Vermilion.Graph
  local DV = Vermilion.DebuffsView
  local sv = Vermilion.SavedVars
  sv.settings = sv.settings or {}
  local before_fold = sv.settings.debuffs_unfolded
  sv.settings.debuffs_unfolded = nil
  local view_label = VermilionGraphWindowViewLabel

  local function goto_debuffs()
    local guard = 0
    while view_label._text ~= "DEBUFFS" and guard < 8 do G.next_view(); guard = guard + 1 end
    ok(view_label._text == "DEBUFFS", "could not reach DEBUFFS")
  end
  local function visible_texts()
    local t = {}
    for _, c in ipairs(H.controls) do
      local name = c._name or ""
      if c._hidden == false and name:find("^VermilionDebuffLbl") and c._text then t[c._text] = (t[c._text] or 0) + 1 end
    end
    return t
  end
  local function visible_icons()
    local n = 0
    for _, c in ipairs(H.controls) do
      local name = c._name or ""
      if c._hidden == false and name:find("^VermilionDebuffIcon") then n = n + 1 end
    end
    return n
  end

  Vermilion.Metrics.reset()
  Vermilion.TemporalBuffer.clear()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  H.ability_descs = { [111] = "Reduces the target's resistances." }

  G.on_record_click()
  H.damage_out({ hit = 500 })
  H.effect(EFFECT_RESULT_GAINED, 111, 600, 0, nil, "reticleover", D)
  H.advance(3000)
  H.effect(EFFECT_RESULT_FADED, 111, 600, 0, nil, "reticleover", D)
  H.advance(1500)
  H.effect(EFFECT_RESULT_GAINED, 111, 600, 0, nil, "reticleover", D)
  H.effect(EFFECT_RESULT_GAINED, 111, 601, 0, nil, "boss1", D)
  H.advance(3000)
  H.effect(EFFECT_RESULT_FADED, 111, 600, 0, nil, "reticleover", D)
  H.effect(EFFECT_RESULT_FADED, 111, 601, 0, nil, "boss1", D)
  H.effect(EFFECT_RESULT_GAINED, 222, 602, 0, nil, "reticleover", D)
  H.advance(2000)
  H.effect(EFFECT_RESULT_FADED, 222, 602, 0, nil, "reticleover", D)
  G.on_stop_click()

  goto_debuffs()
  ok(VermilionGraphWindowViewportNoDataLabel._hidden == true, "no-data must hide when debuffs were tracked")
  do
    local chip_h = (VermilionGraphSummaryBg._hidden == false) and (VermilionGraphSummaryBg._h + 8) or 0
    local first_y = nil
    for _, c in ipairs(H.controls) do
      local name = c._name or ""
      if c._hidden == false and name:find("^VermilionDebuffSeg") and c._anchor_list then
        local oy = c._anchor_list[1].oy or 0
        if first_y == nil or oy < first_y then first_y = oy end
      end
    end
    ok(first_y ~= nil and first_y >= chip_h, "the first lane must start below the summary chip, got " .. tostring(first_y) .. " vs chip " .. chip_h)
  end
  local seg1 = rawget(_G, "VermilionDebuffSeg1")
  ok(seg1 and seg1._hidden == false, "no lane segment rendered")
  local icon1 = rawget(_G, "VermilionDebuffIcon1")
  ok(icon1 and icon1._hidden == false, "no row icon rendered")
  local texts = visible_texts()
  ok(texts["Ability111"] == 1 and texts["Ability222"] == 1, "every debuff has a lane label")
  ok(texts["100%"] == nil, "no debuff is up the whole time here")

  local alphas = {}
  for i = 1, 12 do
    local seg = rawget(_G, "VermilionDebuffSeg" .. i)
    if seg and seg._hidden == false and seg._a then alphas[string.format("%.2f", seg._a)] = true end
  end
  ok(alphas["0.92"] and alphas["0.50"], "concurrency across targets renders in two levels")
  local rim1 = rawget(_G, "VermilionDebuffRim1")
  ok(rim1 and rim1._hidden == false and (rim1._a or 1) < 0.6 and rim1._r == 0, "every segment wears a dark rim")
  local framed = false
  for i = 1, 20 do
    local s = rawget(_G, "VermilionDebuffSeg" .. i)
    if s and s._hidden == false and s._w == rim1._w - 2 and s._h == rim1._h - 2 then framed = true end
  end
  ok(framed, "the rim is one pixel larger than its segment on every side")
  local uptime_bars = 0
  for _, c in ipairs(H.controls) do
    local name = c._name or ""
    if c._hidden == false and name:find("^VermilionDebuffSeg") and c._h == 3 then uptime_bars = uptime_bars + 1 end
  end
  ok(uptime_bars >= 2, "each row draws an uptime track and fill, got " .. uptime_bars)

  local canvas = VermilionGraphWindowViewportCanvas
  local hit    = VermilionGraphHit
  ok(hit._hidden == false, "hit surface must be active on the frozen DEBUFFS view")
  local chip_h = (VermilionGraphSummaryBg._hidden == false) and (VermilionGraphSummaryBg._h + 8) or 0
  H.state.mouse_x = canvas:GetLeft() + 300
  H.state.mouse_y = canvas:GetTop() + chip_h + 5
  hit._onOnMouseEnter(hit)
  H.advance(200)
  ok(VermilionHoverCardName._text == "Ability111", "hover card name wrong: " .. tostring(VermilionHoverCardName._text))
  ok(VermilionHoverCard._hidden == false, "hover card must be visible")
  ok((VermilionHoverCardStat._text or ""):find("up", 1, true) and (VermilionHoverCardStat._text or ""):find("%%"), "the card shows the uptime")
  ok((VermilionHoverCardTime._text or ""):find("targets", 1, true), "the card counts the targets at the hovered moment")
  local found_targets, found_gap = false, false
  for i = 1, 7 do
    local rn = rawget(_G, "VermilionHoverCardRowName" .. i)
    if rn and rn._hidden == false and rn._text == "Targets reached" then
      found_targets = true
      ok(rawget(_G, "VermilionHoverCardRowVal" .. i)._text == "2", "targets reached wrong")
    end
    if rn and rn._hidden == false and rn._text == "Longest gap" then found_gap = true end
  end
  ok(found_targets and found_gap, "card rows missing")
  ok(VermilionHoverCardDesc._hidden == false and VermilionHoverCardDesc._text == "Reduces the target's resistances.",
     "the description shows when the API returns one, got " .. tostring(VermilionHoverCardDesc._text))
  ok(DV.hovered() == 111, "the hovered debuff is tracked")
  local dimmed = false
  for i = 1, 12 do
    local seg = rawget(_G, "VermilionDebuffSeg" .. i)
    if seg and seg._hidden == false and seg._a and seg._a > 0.10 and seg._a <= 0.30 then dimmed = true end
  end
  ok(dimmed, "non-hovered rows must dim while hovering")
  H.state.mouse_y = canvas:GetTop() + chip_h + 35
  H.advance(200)
  ok(VermilionHoverCardName._text == "Ability222", "row 2 hover expected: " .. tostring(VermilionHoverCardName._text))
  ok(VermilionHoverCardDesc._hidden == true, "desc must hide when no id has a description")
  H.state.mouse_y = canvas:GetTop() + canvas:GetHeight() + 50
  H.advance(200)
  ok(VermilionHoverCard._alpha == 0, "card must fade out when leaving the canvas")
  hit._onOnMouseExit(hit)
  H.ability_descs = nil
  G.next_view()
  ok(seg1._hidden == true and rim1._hidden == true, "segments and rims release when leaving DEBUFFS")

  G.on_flush_click()
  H.ability_names = { [301] = "Major Breach", [302] = "Minor Vulnerability", [303] = "Major Maim", [304] = "Short Snare" }
  G.on_record_click()
  H.damage_out({ hit = 500 })
  H.effect(EFFECT_RESULT_GAINED, 301, 600, 0, nil, "reticleover", D)
  H.effect(EFFECT_RESULT_GAINED, 302, 600, 0, nil, "reticleover", D)
  H.effect(EFFECT_RESULT_GAINED, 303, 600, 0, nil, "reticleover", D)
  H.advance(4000)
  H.effect(EFFECT_RESULT_GAINED, 304, 600, 0, nil, "reticleover", D)
  H.advance(2000)
  H.effect(EFFECT_RESULT_FADED, 304, 600, 0, nil, "reticleover", D)
  H.advance(4000)
  H.effect(EFFECT_RESULT_FADED, 301, 600, 0, nil, "reticleover", D)
  H.effect(EFFECT_RESULT_FADED, 302, 600, 0, nil, "reticleover", D)
  H.effect(EFFECT_RESULT_FADED, 303, 600, 0, nil, "reticleover", D)
  G.on_stop_click()
  goto_debuffs()
  local SC = Vermilion.SkillColors
  ok(SC.buff_family("Major Breach") == "offense" and SC.buff_family("Minor Vulnerability") == "offense"
     and SC.buff_family("Major Maim") == "defense" and SC.buff_family("Minor Defile") == "defense",
     "named debuffs map to their family")
  ok(SC.buff_family("Short Snare") == nil, "anything else has no family")
  texts = visible_texts()
  ok(texts["[+] 3 always on"] == 1, "three permanent debuffs fold into the strip")
  ok(texts["Short Snare"] == 1, "the situational debuff keeps its lane")
  ok(texts["Major Breach"] == nil, "a folded debuff has no lane label")
  ok(visible_icons() == 4, "three strip icons plus one lane icon, got " .. visible_icons())

  chip_h = (VermilionGraphSummaryBg._hidden == false) and (VermilionGraphSummaryBg._h + 8) or 0
  H.state.mouse_x = canvas:GetLeft() + 176 + 9
  H.state.mouse_y = canvas:GetTop() + chip_h + 12
  hit._onOnMouseEnter(hit)
  H.advance(200)
  ok(VermilionHoverCardName._text == "Major Breach", "hovering a strip icon names the debuff, got " .. tostring(VermilionHoverCardName._text))
  ok((VermilionHoverCardStat._text or ""):find("100%%"), "the card shows its uptime")
  ok(VermilionHoverCardName._r and VermilionHoverCardName._r > 0.9, "the card name wears the family colour")
  local fam_row = false
  for _, c in ipairs(H.controls) do
    if c._hidden == false and c._text == "Offense: damage done and taken" then fam_row = true end
  end
  ok(fam_row, "the card names the family")

  H.state.mouse_x = canvas:GetLeft() + 40
  H.sounds = {}
  hit._onOnMouseUp(hit, nil, true)
  ok(sv.settings.debuffs_unfolded == true, "clicking the strip unfolds and persists")
  ok(H.sounds[#H.sounds] == ("sound:" .. Vermilion.Sound.name("on")), "unfolding confirms with a sound")
  texts = visible_texts()
  ok(texts["[-] 3 always on"] == 1, "the strip reads unfolded")
  ok(texts["Major Breach"] == 1 and texts["Minor Vulnerability"] == 1 and texts["Major Maim"] == 1, "unfolded debuffs get their lanes back")
  hit._onOnMouseUp(hit, nil, true)
  ok(sv.settings.debuffs_unfolded == false and visible_texts()["[+] 3 always on"] == 1, "clicking again folds")
  hit._onOnMouseExit(hit)
  H.state.mouse_x, H.state.mouse_y = 400, 300

  G.on_flush_click()
  G.on_record_click()
  H.damage_out({ hit = 500 })
  H.effect(EFFECT_RESULT_GAINED, 301, 600, 0, nil, "reticleover", D)
  H.effect(EFFECT_RESULT_GAINED, 302, 600, 0, nil, "reticleover", D)
  H.advance(3000)
  goto_debuffs()
  ok(visible_texts()["[+] 2 always on"] == nil, "no strip while recording")
  ok(visible_texts()["Major Breach"] == 1, "lanes draw live while recording")
  G.on_stop_click()

  local SS = Vermilion.SessionStore
  local before_lib, before_auto = sv.library, sv.settings.session_autosave
  sv.library = { version = 1, sessions = {} }
  sv.settings.session_autosave = false
  SS.init()
  ok(G.on_save_click() == true, "manual save with debuffs")
  H.advance(400)
  ok(SS.count() == 1, "the session is stored")
  local s = SS.get(1)
  ok(s.debuffs and #s.debuffs == 2 and s.streams.steps and s.streams.steps.n >= 2, "the session carries the debuff meta and steps")
  G.on_flush_click()
  ok(Vermilion.DebuffTracker.count() == 0, "flush clears the tracker")
  ok(G.load_session(s) ~= false, "the session loads")
  goto_debuffs()
  ok(Vermilion.DebuffTracker.count() == 2, "the library rebuilds the debuffs")
  texts = visible_texts()
  ok(texts["Major Breach"] == 1 or texts["[+] 2 always on"] == 1, "the loaded session renders its lanes or its strip")
  sv.library, sv.settings.session_autosave = before_lib, before_auto
  SS.init()

  G.on_flush_click()
  G.on_record_click()
  H.damage_out({ hit = 500 })
  for k = 1, 14 do H.effect(EFFECT_RESULT_GAINED, 700 + k, 600, 0, nil, "reticleover", D) end
  for k = 1, 14 do
    H.advance(300)
    H.effect(EFFECT_RESULT_FADED, 700 + k, 600, 0, nil, "reticleover", D)
  end
  H.advance(4000)
  G.on_stop_click()
  local cw0, ch0 = canvas:GetDimensions()
  canvas:SetDimensions(392, 160)
  G.on_resize_stop()
  goto_debuffs()
  texts = visible_texts()
  ok(texts["Ability714"] == 1, "the longest debuff leads the lanes")
  ok(texts["Ability701"] == nil, "the shortest debuff does not fit")
  local found = false
  for k in pairs(texts) do if k:sub(1, 7) == "0 above" then found = true end end
  ok(found, "the overflow line reads 0 above at the top")
  hit._onOnMouseWheel(hit, -1)
  texts = visible_texts()
  ok(texts["Ability714"] == nil and texts["Ability713"] == 1, "the wheel scrolls the lanes")
  for _ = 1, 30 do hit._onOnMouseWheel(hit, -1) end
  ok(visible_texts()["Ability701"] == 1, "the shortest debuff is reachable at the end")
  for _ = 1, 30 do hit._onOnMouseWheel(hit, 1) end
  ok(visible_texts()["Ability714"] == 1, "and back to the top")
  G.next_view()
  G.prev_view()
  ok(DV.scroll_state() == 0, "leaving and returning resets the scroll")
  canvas:SetDimensions(cw0, ch0)
  G.on_resize_stop()

  ok(GetString(VERMILION_GRAPH_NO_DEBUFFS):find("Record", 1, true), "the empty state explains how to capture debuffs")

  sv.settings.debuffs_unfolded = before_fold
  H.ability_names = nil
  G.on_flush_click()
  while view_label._text ~= "SKILL" do G.next_view() end
  Vermilion.Visibility.set("graph", false)
  Vermilion.Metrics.reset()
end
