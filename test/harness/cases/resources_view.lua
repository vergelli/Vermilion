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

  local MAGF, STAF = COMBAT_MECHANIC_FLAGS_MAGICKA, COMBAT_MECHANIC_FLAGS_STAMINA
  H.slotted = { [HOTBAR_CATEGORY_PRIMARY] = { [3] = 501, [4] = 502, [8] = 41001 } }
  H.ability_costs = {
    [501] = { base = 2700, flags = MAGF, cost = { [MAGF] = 2500 } },
    [502] = { base = 2200, flags = STAF, cost = { [STAF] = 2200 } },
  }
  H.state.active_bar = HOTBAR_CATEGORY_PRIMARY
  H.ability_names = H.ability_names or {}
  H.ability_names[501], H.ability_names[502], H.ability_names[701] = "Crushing Shock", "Rending Slashes", "Heavy Attack"
  H.ability_icons = H.ability_icons or {}
  H.ability_icons[701] = "/esoui/art/icons/icon_missing.dds"
  H.state.power = { [POWERTYPE_MAGICKA] = { value = 30000, max = 30000 }, [POWERTYPE_STAMINA] = { value = 20000, max = 20000 } }
  H.state.stats = { [STAT_MAGICKA_REGEN_COMBAT] = 953, [STAT_STAMINA_REGEN_COMBAT] = 1210 }
  sv.settings.session_autosave = true
  sv.library = { version = 1, sessions = {} }

  G.on_record_click()
  local mag, sta = 30000, 20000
  for i = 1, 20 do
    H.skill_used(3)
    mag = math.max(mag - 2500, 0); H.res_power(POWERTYPE_MAGICKA, mag, 30000)
    if i % 2 == 0 then
      H.skill_used(4)
      sta = sta - 2200; H.res_power(POWERTYPE_STAMINA, sta, 20000)
    end
    if i % 3 == 0 then
      H.energize({ ability_id = 701, amount = 3240, pool = MAGF })
      mag = mag + 3240; H.res_power(POWERTYPE_MAGICKA, mag, 30000)
      H.skill_used(3)
      mag = math.max(mag - 2500, 0); H.res_power(POWERTYPE_MAGICKA, mag, 30000)
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
    local r = { mag = 0, sta = 0, low = 0, ticks = 0, out = 0, band = 0, warn = 0, gold = 0, faded = 0, mag_bar = 0, icons = 0, pool_icons = 0, labels = {} }
    for _, c in ipairs(H.controls) do
      local name = c._name or ""
      if c._hidden == false then
        if name:find("^VermilionTargetSeg") and c._r then
          if math.abs(c._r - 0.36) < 0.01 and math.abs(c._b - 0.96) < 0.01 then
            r.mag = r.mag + 1
            if c._vpts then r.faded = r.faded + 1 end
            if c._h == 5 then r.mag_bar = r.mag_bar + 1 end
          end
          if math.abs(c._r - 0.95) < 0.01 and math.abs(c._g - 0.80) < 0.01 then r.warn = r.warn + 1 end
          if math.abs(c._r - 0.80) < 0.01 and math.abs(c._g - 0.68) < 0.01 then r.gold = r.gold + 1 end
          if math.abs(c._r - 0.46) < 0.01 and math.abs(c._g - 0.80) < 0.01 then
            r.sta = r.sta + 1
            if c._vpts then r.faded = r.faded + 1 end
          end
          if math.abs(c._r - 0.95) < 0.01 and math.abs(c._g - 0.42) < 0.01 then
            r.low = r.low + 1
            if c._h == 3 and c._a == 1 then r.ticks = r.ticks + 1 end
            if c._a and c._a < 0.1 then r.band = r.band + 1 end
          end
          if math.abs(c._r - 0.86) < 0.01 and math.abs(c._g - 0.50) < 0.01 then r.out = r.out + 1 end
        elseif name:find("^VermilionTargetLbl") and type(c._text) == "string" then
          r.labels[#r.labels + 1] = c._text
        elseif name:find("^VermilionContribIcon") then
          r.icons = r.icons + 1
          if type(c._tex) == "string" and c._tex:find("champion_points_", 1, true) then r.pool_icons = r.pool_icons + 1 end
        end
      end
    end
    return r
  end
  local function has(list, text) for _, t in ipairs(list) do if t == text then return true end end return false end

  local r = scan()
  ok(r.mag > 0 and r.sta > 0, "both pools draw their level columns in BOTH, got " .. r.mag .. " and " .. r.sta)
  ok(r.ticks >= 1, "a starvation tick marks where magicka sat under 15% for two seconds or more, got " .. r.ticks)
  ok(r.band >= 2, "the 15% band is painted on both sides of the midline, got " .. r.band)
  ok(r.warn >= 2, "the 15 to 30% band and its line are yellow, got " .. r.warn)
  ok(r.gold >= 20, "the picker, the two halves and the two lists wear gold frames, got " .. r.gold)
  ok(r.faded >= 2, "level columns fade toward the midline in BOTH, got " .. r.faded)
  ok(r.mag_bar >= 1, "the recovered list colours its bars by pool, got " .. r.mag_bar)
  ok(r.pool_icons >= 2, "a missing ability icon and the recovery row fall back to the pool's icon, got " .. r.pool_icons)
  ok(r.out == 0, "the mirrored layout draws levels, not flow bars")
  ok(has(r.labels, "MAGICKA") and has(r.labels, "STAMINA") and has(r.labels, "BOTH"), "the picker offers magicka, stamina and both")
  ok(has(r.labels, "SPENT BY SKILL") and has(r.labels, "RECOVERED BY"), "the two lists have their headers")
  ok(has(r.labels, "0s"), "the lane carries its own time axis")
  ok(r.icons >= 3, "rows wear their ability icons, got " .. r.icons)
  local order, n = RV.rows()
  ok(n == 2 and order[1].id == 501 and order[2].id == 502, "the spend list ranks the skills by what they spent, got " .. n)
  ok(order[1].total == 26 * 2500 and order[1].n == 26, "a skill's total is its casts times its real cost, got " .. tostring(order[1].total) .. " over " .. tostring(order[1].n))
  ok(order[1].mag > 0 and order[1].sta == 0 and order[2].sta > 0 and order[2].mag == 0, "a magicka skill is magicka and a stamina skill is stamina")
  ok(has(r.labels, "Crushing Shock") and has(r.labels, "Rending Slashes") and has(r.labels, "Heavy Attack") and has(r.labels, "Recovery"), "rows name the skills, the restorer and the recovery")
  local rec, nr = RV.recovered()
  ok(nr == 2, "the recovered list has the heavy attack and the recovery, got " .. nr)
  local heavy, recovery
  for i = 1, nr do if rec[i].id == 701 then heavy = rec[i] else recovery = rec[i] end end
  ok(heavy and heavy.total == 6 * 3240 and heavy.n == 6, "the heavy attack's total is its restores, got " .. tostring(heavy and heavy.total))
  ok(recovery and recovery.id == 0 and recovery.mag == 20 * 500 and recovery.sta == 20 * 900, "the recovery row is the regained minus the energized, per pool, got " .. tostring(recovery and recovery.mag) .. " " .. tostring(recovery and recovery.sta))

  local canvas = VermilionGraphWindowViewportCanvas
  local mag_lbl
  for _, c in ipairs(H.controls) do
    if c._hidden == false and (c._name or ""):find("^VermilionTargetLbl") and c._text == "MAGICKA" then mag_lbl = mag_lbl or c end
  end
  ok(mag_lbl ~= nil, "the MAGICKA pick is drawn")
  local L = H.layout(mag_lbl)
  ok(RV.click(L.x + 2, L.y + 2) == true, "clicking MAGICKA picks it")
  ok(RV.pick() == 1 and sv.graph.res_pick == 1, "the pick persists in the saved variables")
  G.next_view(); G.prev_view()
  ok(view_label._text == "RESOURCES", "back on the view")
  r = scan()
  ok(r.sta == 0 and r.mag > 0 and r.out > 0, "a single pool draws its level lane and its flow lane, got mag " .. r.mag .. " sta " .. r.sta .. " out " .. r.out)
  ok(r.band >= 1 and r.ticks >= 1, "the band and the starvation mark stay in the single layout")
  ok(r.faded == 0, "the single layout draws solid columns")
  ok(has(r.labels, "LEVEL") and has(r.labels, "REGAINED") and has(r.labels, "SPENT"), "the two lanes name what they show")
  local order2, n2 = RV.rows()
  ok(n2 == 1 and order2[1].id == 501, "the spend list follows the pick, got " .. n2)
  local rec2, nr2 = RV.recovered()
  ok(nr2 == 2 and rec2[1].id == 701 and rec2[2].id == 0 and rec2[2].total == 20 * 500, "the recovered list follows the pick and ranks the heavy attack over the recovery, got " .. nr2)
  ok(RV.click(L.x + 2, L.y + 2) == false, "clicking the active pick changes nothing")

  local lane = RV.lane()
  local hit = VermilionGraphHit
  H.state.mouse_x = canvas:GetLeft() + lane.x + math.floor(lane.w * 0.5)
  H.state.mouse_y = canvas:GetTop() + lane.y + math.floor(lane.h * 0.5)
  hit._onOnMouseEnter(hit)
  H.advance(200)
  ok((VermilionHoverCardName._text or ""):find("Magicka", 1, true) ~= nil, "hovering the lane names the pool and its level, got " .. tostring(VermilionHoverCardName._text))
  ok((VermilionHoverCardStat._text or ""):find("regained", 1, true) ~= nil, "the card reads the flows of that second, got " .. tostring(VermilionHoverCardStat._text))
  local rows_seen = {}
  for _, c in ipairs(H.controls) do if c._hidden == false and type(c._text) == "string" then rows_seen[c._text] = true end end
  ok(rows_seen["Top spender · 10 s"], "the card names the top spender of the last ten seconds")
  ok(rows_seen["Recovery"], "the card names the recovery per tick")
  hit._onOnMouseExit(hit)

  local name_lbl
  for _, c in ipairs(H.controls) do
    if c._hidden == false and (c._name or ""):find("^VermilionTargetLbl") and c._text == "Heavy Attack" then name_lbl = c end
  end
  ok(name_lbl ~= nil, "the heavy attack has its row")
  local NL = H.layout(name_lbl)
  H.state.mouse_x, H.state.mouse_y = NL.x + 5, NL.y + 5
  hit._onOnMouseEnter(hit)
  H.advance(200)
  ok(VermilionHoverCardName._text == "Heavy Attack", "hovering a restore row names the source, got " .. tostring(VermilionHoverCardName._text))
  ok((VermilionHoverCardStat._text or ""):find("restores", 1, true) ~= nil, "the card counts the restores, got " .. tostring(VermilionHoverCardStat._text))
  ok(RV.hovered() ~= nil and RV.hovered().id == 701, "the hovered row is tracked")
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
  local rec3, nr3 = RV.recovered()
  ok(n3 == 1 and order3[1].id == 501 and order3[1].n == 26 and nr3 == 2 and rec3[1].n == 6, "both lists are rebuilt from the saved streams, got " .. n3 .. " and " .. nr3)
  r = scan()
  ok(r.mag > 0, "a loaded session draws the pool")

  local old = {}
  for k, v in pairs(sess) do old[k] = v end
  old.desc = {}
  for k, v in pairs(sess.desc) do old.desc[k] = v end
  old.desc.casts, old.desc.restores = nil, nil
  old.streams = {}
  for k, v in pairs(sess.streams) do old.streams[k] = v end
  old.streams.casts, old.streams.restores = nil, nil
  old.head = {}
  for k, v in pairs(sess.head) do old.head[k] = v end
  old.head.regen = nil
  G.on_flush_click()
  ok(G.load_session(old), "a session recorded before casts and restores loads")
  while view_label._text ~= "RESOURCES" do G.next_view() end
  local _, n4 = RV.rows()
  local rec4, nr4 = RV.recovered()
  ok(n4 == 0 and nr4 == 1 and rec4[1].id == 0, "no casts means an empty spend list and the recovery alone explains the regained, got " .. n4 .. " and " .. nr4)
  ok(VermilionGraphWindowViewportNoDataLabel._hidden == true, "the pools still draw")

  RV.set_pick(3)
  G.on_flush_click()
  while view_label._text ~= "SKILL" do G.next_view() end
  H.slotted, H.ability_costs, H.state.active_bar, H.state.power, H.state.stats = nil, nil, nil, nil, nil
  H.ability_icons[701] = nil
  sv.settings.session_autosave = before_auto
end
