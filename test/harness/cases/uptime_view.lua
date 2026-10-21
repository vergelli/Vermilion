return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G, UV, TB, SS = Vermilion.Graph, Vermilion.UptimeView, Vermilion.TemporalBuffer, Vermilion.SessionStore
  local sv = Vermilion.SavedVars
  sv.settings = sv.settings or {}
  local before_auto = sv.settings.session_autosave
  local fx = dofile(HARNESS_ROOT .. "/test/harness/fixtures/uptime_trace.lua")

  Vermilion.Metrics.reset()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  local view_label = VermilionGraphWindowViewLabel
  while view_label._text ~= "SKILL" do G.next_view() end
  UV.set_pick(1)

  local tab = VermilionGraphTab8Label
  ok(tab and tab._text == "UPTIME", "the eighth tab reads UPTIME, got " .. tostring(tab and tab._text))

  H.ability_names = H.ability_names or {}
  H.ability_names[62951], H.ability_names[21765], H.ability_names[40385], H.ability_names[204009] = "Blockade of Frost", "Purifying Light", "Barbed Trap", "Tri Focus"
  H.slotted = { [HOTBAR_CATEGORY_PRIMARY] = { [3] = 62951, [4] = 21765, [5] = 40385, [6] = 204009 } }
  H.state.active_bar = HOTBAR_CATEGORY_PRIMARY
  sv.settings.session_autosave = true
  sv.library = { version = 1, sessions = {} }

  G.on_record_click()
  local base = H.now()
  local function fire(e)
    H.fire(EVENT_EFFECT_CHANGED, e.ch, 1, e.name, e.tag, (base + e.b) / 1000, (base + e.e) / 1000,
      1, "icon.dds", 0, BUFF_EFFECT_TYPE_DEBUFF, 0, 0, "Enemy", e.unit, e.aid, COMBAT_UNIT_TYPE_PLAYER)
  end
  local cursor, next_dmg = 0, 0
  for _, e in ipairs(fx.ef) do
    if e.t > 70000 then break end
    while cursor < e.t do
      local step = math.min(1000, e.t - cursor)
      H.advance(step)
      cursor = cursor + step
      if cursor >= next_dmg then
        H.damage_out({ hit = 1500, ability_id = 62951, result = ACTION_RESULT_DOT_TICK })
        H.damage_out({ hit = 800, ability_id = 40385, result = ACTION_RESULT_DOT_TICK })
        next_dmg = cursor + 1000
      end
    end
    fire(e)
  end
  H.advance(1500)
  ok(TB.count() >= 40, "the fight produced samples, got " .. TB.count())
  G.on_stop_click()
  H.advance(500)

  while view_label._text ~= "UPTIME" do G.next_view() end
  ok(VermilionGraphWindowViewportNoDataLabel._hidden == true, "the view has uptimes to draw")

  local function scan()
    local r = { labels = {}, ground = 0, press = 0, clip = 0, lines = 0, gold_dots = 0, rings = 0, segs = 0, discs = 0, tex_rings = 0, gauges = 0, heat = 0 }
    for _, c in ipairs(H.controls) do
      local name = c._name or ""
      if c._hidden == false then
        if name:find("^VermilionTargetSeg") and c._r then
          r.segs = r.segs + 1
          if math.abs(c._r - 0.86) < 0.01 and math.abs(c._g - 0.28) < 0.01 then r.ground = r.ground + 1 end
          if math.abs(c._r - 0.94) < 0.01 and math.abs(c._g - 0.88) < 0.01 then r.press = r.press + 1 end
          if math.abs(c._r - 0.80) < 0.01 and math.abs(c._g - 0.68) < 0.01 then r.clip = r.clip + 1 end
          if c._w == 5 and c._h == 5 then r.gold_dots = r.gold_dots + 1 end
          if c._w == 2 and c._h == 2 then r.rings = r.rings + 1 end
        elseif name:find("^VermilionTargetLbl") and type(c._text) == "string" then
          r.labels[#r.labels + 1] = c._text
        elseif name:find("^VermilionVizLine") then
          r.lines = r.lines + 1
        elseif name:find("^VermilionVizCd") and c._cd_pct then
          r.gauges = r.gauges + 1
        elseif name:find("^VermilionContribIcon") and type(c._tex) == "string" then
          if c._tex:find("dot.dds", 1, true) then r.discs = r.discs + 1 end
          if c._tex:find("ring.dds", 1, true) then r.tex_rings = r.tex_rings + 1 end
        end
        if name:find("^VermilionTargetSeg") and c._a and c._a > 0.05 and c._a < 0.56 and c._r and math.abs(c._r - 0.80) < 0.01 and math.abs(c._g - 0.68) < 0.01 then r.heat = r.heat + 1 end
      end
    end
    return r
  end
  local function has(list, text)
    for _, t in ipairs(list) do if t == text then return true end end
    return false
  end

  local r = scan()
  local order, n, rows = UV.rows()
  ok(n >= 3, "the timeline lists the effects that lasted, got " .. n)
  ok(rows[order[1]].slot == true, "slotted skills come first")
  ok(has(r.labels, "Blockade of Frost") and has(r.labels, "Traumatic Burns"), "rows are named")
  ok(has(r.labels, "COST OF GAPS") and has(r.labels, "REFRESHES") and has(r.labels, "REFRESH ERROR"), "the lists and the error strip carry their names")
  ok(r.ground >= math.min(n, 6), "every visible row has its gap ground, got " .. r.ground)
  ok(r.press >= 10, "presses are marked on the rows, got " .. r.press)
  ok(r.clip >= 3, "early presses are stippled in gold, got " .. r.clip)
  ok(r.gauges >= 1, "the refreshes list draws its gauges as radial cooldowns on the ring texture, got " .. r.gauges)
  ok(r.tex_rings >= 1, "every gauge sits on a dim textured ring, got " .. r.tex_rings)
  local costs, nc = UV.costs()
  ok(nc >= 1 and rows[costs[1]].cost > 0 and rows[costs[1]].down > 0, "a skill with damage and downtime has a priced gap, got " .. nc)
  local kb = nil
  for i = 1, n do if rows[order[i]].name == "Blockade of Frost" then kb = order[i] end end
  ok(kb ~= nil and rows[kb].dps > 0, "the damage of a DoT is joined to its row by name")

  local canvas = VermilionGraphWindowViewportCanvas
  local hit = VermilionGraphHit
  local lane = UV.lane()
  H.state.mouse_x = canvas:GetLeft() + lane.x + 20
  H.state.mouse_y = canvas:GetTop() + lane.y + 2 + 9
  hit._onOnMouseEnter(hit)
  H.advance(200)
  ok((VermilionHoverCardName._text or "") == rows[order[1]].name, "hovering the first row names its effect, got " .. tostring(VermilionHoverCardName._text))
  local seen = {}
  for _, c in ipairs(H.controls) do if c._hidden == false and type(c._text) == "string" then seen[c._text] = true end end
  ok(seen["Uptime"] and seen["Presses"] and seen["Mean error"] and seen["Down"], "the row card gives uptime, presses, mean error and downtime")
  ok(UV.hovered() == order[1], "the hovered row is remembered for the error strip")
  H.state.mouse_x = canvas:GetLeft() + 1
  H.state.mouse_y = canvas:GetTop() + 1
  hit._onOnMouseEnter(hit)
  H.advance(200)

  local rh_lbl
  for _, c in ipairs(H.controls) do
    if c._hidden == false and (c._name or ""):find("^VermilionTargetLbl") and c._text == "RHYTHM" then rh_lbl = rh_lbl or c end
  end
  ok(rh_lbl ~= nil, "the RHYTHM pick is drawn")
  local L = H.layout(rh_lbl)
  ok(UV.click(L.x + 2, L.y + 2) == true, "clicking RHYTHM picks it")
  ok(UV.pick() == 2 and sv.graph.upt_pick == 2, "the pick persists")
  G.next_view(); G.prev_view()
  r = scan()
  ok(r.lines >= 1, "the Poincare plot draws its diagonal, got " .. r.lines)
  ok(r.discs >= 3, "refresh intervals are round dots, got " .. r.discs)
  ok(r.tex_rings >= 1, "each skill's duration is a textured ring, got " .. r.tex_rings)
  ok(r.heat >= 3, "the density under the dots is painted, got " .. r.heat)
  ok(has(r.labels, "STEADINESS") and not has(r.labels, "COST OF GAPS") and not has(r.labels, "REFRESHES"), "the rhythm view lists steadiness only")
  local tl_lbl
  for _, c in ipairs(H.controls) do
    if c._hidden == false and (c._name or ""):find("^VermilionTargetLbl") and c._text == "TIMELINE" then tl_lbl = tl_lbl or c end
  end
  local LT = H.layout(tl_lbl)
  ok(UV.click(LT.x + 2, LT.y + 2) == true, "back to TIMELINE")
  G.next_view(); G.prev_view()

  local rects = UV.rects()
  H.state.mouse_x = canvas:GetLeft() + lane.x + 20
  H.state.mouse_y = canvas:GetTop() + rects[1].y0 + 5
  local scrolled = UV.scroll(1)
  ok(scrolled == true or scrolled == false, "the wheel answers over the rows")

  G.on_stop_click()
  H.advance(500)
  ok(SS.count() == 1, "the session saved")
  local sess = SS.get(1)
  ok(sess.streams.spans and sess.streams.press and sess.head.uptime and #sess.head.uptime.names >= 3, "the session carries the uptime streams and the key names")
  G.on_flush_click()
  ok(TB.count() == 0, "flushed")
  ok(G.load_session(sess), "the session loads back")
  while view_label._text ~= "UPTIME" do G.next_view() end
  local order2, n2, rows2 = UV.rows()
  ok(n2 == n, "the loaded session draws the same rows, got " .. n2 .. " vs " .. n)
  ok(rows2[order2[1]].pn > 0 and rows2[order2[1]].uptime > 0, "presses and uptime survive the round trip")

  G.on_flush_click()
  H.slotted, H.state.active_bar = nil, nil
  sv.settings.session_autosave = before_auto
end
