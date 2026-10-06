return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G, RV, TB, SS = Vermilion.Graph, Vermilion.ResourcesView, Vermilion.TemporalBuffer, Vermilion.SessionStore
  local sv = Vermilion.SavedVars
  sv.settings = sv.settings or {}
  local before_auto = sv.settings.session_autosave

  Vermilion.Metrics.reset()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  local view_label = VermilionGraphWindowViewLabel
  while view_label._text ~= "SKILL" do G.next_view() end
  RV.set_pick(3)

  local tab = VermilionGraphTab7Label
  ok(tab and tab._text == "RESOURCES", "the seventh tab reads RESOURCES, got " .. tostring(tab and tab._text))

  H.slotted = { [HOTBAR_CATEGORY_PRIMARY] = { [3] = 501, [4] = 502, [8] = 41001 } }
  H.skill_costs = { [HOTBAR_CATEGORY_PRIMARY] = { [3] = { [COMBAT_MECHANIC_FLAGS_MAGICKA] = 2700 }, [4] = { [COMBAT_MECHANIC_FLAGS_STAMINA] = 2200 } } }
  H.state.active_bar = HOTBAR_CATEGORY_PRIMARY
  H.ability_names = H.ability_names or {}
  H.ability_names[501], H.ability_names[502] = "Crushing Shock", "Rending Slashes"
  H.state.power = { [POWERTYPE_MAGICKA] = { value = 30000, max = 30000 }, [POWERTYPE_STAMINA] = { value = 20000, max = 20000 } }
  sv.settings.session_autosave = true
  sv.library = { version = 1, sessions = {} }

  G.on_record_click()
  local mag, sta = 30000, 20000
  for i = 1, 15 do
    H.skill_used(3)
    mag = math.max(mag - 2700, 0); H.res_power(POWERTYPE_MAGICKA, mag, 30000)
    if i % 2 == 0 then
      H.skill_used(4)
      sta = sta - 2200; H.res_power(POWERTYPE_STAMINA, sta, 20000)
    end
    mag = mag + 500; H.res_power(POWERTYPE_MAGICKA, mag, 30000)
    sta = sta + 900; H.res_power(POWERTYPE_STAMINA, sta, 20000)
    H.damage_out({ hit = 1000, ability_id = 501 })
    H.advance(1000)
  end
  G.on_stop_click()
  H.advance(500)

  while view_label._text ~= "RESOURCES" do G.next_view() end
  ok(VermilionGraphWindowViewportNoDataLabel._hidden == true, "the view has data to draw")

  local function scan()
    local r = { mag = 0, sta = 0, low = 0, ticks = 0, out = 0, labels = {} }
    for _, c in ipairs(H.controls) do
      local name = c._name or ""
      if c._hidden == false then
        if name:find("^VermilionTargetSeg") and c._r then
          if math.abs(c._r - 0.36) < 0.01 and math.abs(c._b - 0.96) < 0.01 then r.mag = r.mag + 1 end
          if math.abs(c._r - 0.46) < 0.01 and math.abs(c._g - 0.80) < 0.01 then r.sta = r.sta + 1 end
          if math.abs(c._r - 0.95) < 0.01 and math.abs(c._g - 0.42) < 0.01 then
            r.low = r.low + 1
            if c._h == 3 then r.ticks = r.ticks + 1 end
          end
          if math.abs(c._r - 0.86) < 0.01 and math.abs(c._g - 0.50) < 0.01 then r.out = r.out + 1 end
        elseif name:find("^VermilionTargetLbl") and type(c._text) == "string" then
          r.labels[#r.labels + 1] = c._text
        end
      end
    end
    return r
  end
  local function has(list, text) for _, t in ipairs(list) do if t == text then return true end end return false end

  local r = scan()
  ok(r.mag > 0 and r.sta > 0, "both pools draw their level columns in BOTH, got " .. r.mag .. " and " .. r.sta)
  ok(r.ticks >= 1, "a starvation tick marks where magicka sat under 15% for two seconds or more, got " .. r.ticks)
  ok(r.out == 0, "the mirrored layout draws levels, not flow bars")
  ok(has(r.labels, "MAGICKA") and has(r.labels, "STAMINA") and has(r.labels, "BOTH"), "the picker offers magicka, stamina and both")
  ok(has(r.labels, "SPENT BY SKILL"), "the histogram has its header")
  ok(has(r.labels, "0s"), "the lane carries its own time axis")
  local order, n = RV.rows()
  ok(n == 2 and order[1].id == 501 and order[2].id == 502, "the histogram ranks the skills by what they spent, got " .. n)
  ok(order[1].total == 15 * 2700 and order[1].casts == 15, "a skill's total is its casts times its cost, got " .. tostring(order[1].total))
  ok(has(r.labels, "Crushing Shock") and has(r.labels, "Rending Slashes"), "rows name the skills")

  local canvas = VermilionGraphWindowViewportCanvas
  local sta_lbl
  for _, c in ipairs(H.controls) do
    if c._hidden == false and (c._name or ""):find("^VermilionTargetLbl") and c._text == "STAMINA" then sta_lbl = c end
  end
  ok(sta_lbl ~= nil, "the STAMINA pick is drawn")
  local L = H.layout(sta_lbl)
  ok(RV.click(L.x + 2, L.y + 2) == true, "clicking STAMINA picks it")
  ok(RV.pick() == 2 and sv.graph.res_pick == 2, "the pick persists in the saved variables")
  G.next_view(); G.prev_view()
  ok(view_label._text == "RESOURCES", "back on the view")
  r = scan()
  ok(r.mag == 0 and r.sta > 0 and r.out > 0, "a single pool draws its level area and its flow bars, got mag " .. r.mag .. " sta " .. r.sta .. " out " .. r.out)
  local order2, n2 = RV.rows()
  ok(n2 == 1 and order2[1].id == 502 and order2[1].casts == 7, "the histogram follows the pick, got " .. n2)
  ok(RV.click(L.x + 2, L.y + 2) == false, "clicking the active pick changes nothing")

  local lane = RV.lane()
  local hit = VermilionGraphHit
  H.state.mouse_x = canvas:GetLeft() + lane.x + math.floor(lane.w * 0.5)
  H.state.mouse_y = canvas:GetTop() + lane.y + math.floor(lane.h * 0.5)
  hit._onOnMouseEnter(hit)
  H.advance(200)
  ok((VermilionHoverCardName._text or ""):find("Stamina", 1, true) ~= nil, "hovering the lane names the pool and its level, got " .. tostring(VermilionHoverCardName._text))
  ok((VermilionHoverCardStat._text or ""):find("regained", 1, true) ~= nil, "the card reads the flows of that second, got " .. tostring(VermilionHoverCardStat._text))
  local top_row = false
  for _, c in ipairs(H.controls) do if c._hidden == false and c._text == "Top spender · 10 s" then top_row = true end end
  ok(top_row, "the card names the top spender of the last ten seconds")
  hit._onOnMouseExit(hit)

  local name_lbl
  for _, c in ipairs(H.controls) do
    if c._hidden == false and (c._name or ""):find("^VermilionTargetLbl") and c._text == "Rending Slashes" then name_lbl = c end
  end
  ok(name_lbl ~= nil, "the stamina skill has its row")
  local NL = H.layout(name_lbl)
  H.state.mouse_x, H.state.mouse_y = NL.x + 5, NL.y + 5
  hit._onOnMouseEnter(hit)
  H.advance(200)
  ok(VermilionHoverCardName._text == "Rending Slashes", "hovering a row names the skill, got " .. tostring(VermilionHoverCardName._text))
  ok((VermilionHoverCardStat._text or ""):find("casts", 1, true) ~= nil, "the card counts the casts, got " .. tostring(VermilionHoverCardStat._text))
  ok(RV.hovered() ~= nil and RV.hovered().id == 502, "the hovered row is tracked")
  hit._onOnMouseExit(hit)
  RV.clear_hover()
  H.state.mouse_x, H.state.mouse_y = 400, 300

  local sum = Vermilion.Resources.summary(TB)
  ok(sum.eff > 0, "the fight has a damage-per-resource figure, got " .. tostring(sum.eff))

  ok(SS.count() == 1, "the session saved")
  local sess = SS.get(1)
  G.on_flush_click()
  ok(G.load_session(sess), "the session loads back")
  while view_label._text ~= "RESOURCES" do G.next_view() end
  local order3, n3 = RV.rows()
  ok(n3 == 1 and order3[1].id == 502 and order3[1].casts == 7, "the histogram is rebuilt from the saved casts, got " .. n3)
  r = scan()
  ok(r.sta > 0, "a loaded session draws the pool")

  local old = {}
  for k, v in pairs(sess) do old[k] = v end
  old.desc = {}
  for k, v in pairs(sess.desc) do old.desc[k] = v end
  old.desc.casts = nil
  old.streams = {}
  for k, v in pairs(sess.streams) do old.streams[k] = v end
  old.streams.casts = nil
  G.on_flush_click()
  ok(G.load_session(old), "a session recorded before casts loads")
  while view_label._text ~= "RESOURCES" do G.next_view() end
  local _, n4 = RV.rows()
  ok(n4 == 0 and VermilionGraphWindowViewportNoDataLabel._hidden == true, "no casts means an empty histogram while the pools still draw")

  RV.set_pick(3)
  G.on_flush_click()
  while view_label._text ~= "SKILL" do G.next_view() end
  H.slotted, H.skill_costs, H.state.active_bar, H.state.power = nil, nil, nil, nil
  sv.settings.session_autosave = before_auto
end
