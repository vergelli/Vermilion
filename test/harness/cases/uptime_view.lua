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
  fire({ ch = EFFECT_RESULT_GAINED, name = "Barbed Trap", tag = "", b = H.now() - base, e = H.now() - base + 20000, unit = 9001, aid = 40385 })
  for _ = 1, 4 do
    for _ = 1, 18 do
      H.advance(500)
      H.damage_out({ hit = 800, ability_id = 40385, result = ACTION_RESULT_DOT_TICK })
      H.advance(250)
      H.damage_out({ hit = 1500, ability_id = 62951, result = ACTION_RESULT_DOT_TICK })
      H.advance(250)
    end
    fire({ ch = EFFECT_RESULT_UPDATED, name = "Barbed Trap", tag = "", b = H.now() - base, e = H.now() - base + 20000, unit = 9001, aid = 40385 })
  end
  H.advance(1500)
  ok(TB.count() >= 40, "the fight produced samples, got " .. TB.count())
  G.on_stop_click()
  H.advance(500)

  while view_label._text ~= "UPTIME" do G.next_view() end
  ok(VermilionGraphWindowViewportNoDataLabel._hidden == true, "the view has uptimes to draw")

  local function scan()
    local r = { labels = {}, ground = 0, press = 0, clip = 0, lines = 0, segs = 0, discs = 0, tex_rings = 0, gauges = 0 }
    for _, c in ipairs(H.controls) do
      local name = c._name or ""
      if c._hidden == false then
        if name:find("^VermilionTargetSeg") and c._r then
          r.segs = r.segs + 1
          if math.abs(c._r - 0.86) < 0.01 and math.abs(c._g - 0.28) < 0.01 then r.ground = r.ground + 1 end
          if math.abs(c._r - 0.94) < 0.01 and math.abs(c._g - 0.88) < 0.01 then r.press = r.press + 1 end
          if math.abs(c._r - 0.80) < 0.01 and math.abs(c._g - 0.68) < 0.01 then r.clip = r.clip + 1 end
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
  ok(G.saved_view(8) == 8 and G.saved_view(1) == 1, "a saved tab comes back, UPTIME too")
  ok(G.saved_view(99) == nil and G.saved_view(nil) == nil and G.saved_view("x") == nil, "and nothing else does")
  ok(has(r.labels, "COST OF GAPS, ESTIMATED") and has(r.labels, "REFRESHES") and has(r.labels, "REFRESH ERROR"), "the lists and the error strip carry their names")
  ok(r.ground >= math.min(n, 6), "every visible row has its gap ground, got " .. r.ground)
  ok(r.press >= 3, "presses are marked on the rows, got " .. r.press)
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
  ok(seen["Uptime"] and seen["Refreshes"] and seen["Mean error"] and seen["Down"], "the row card gives uptime, presses, mean error and downtime")
  ok(UV.hovered() == order[1], "the hovered row is remembered for the error strip")
  H.state.mouse_x = canvas:GetLeft() + 1
  H.state.mouse_y = canvas:GetTop() + 1
  hit._onOnMouseEnter(hit)
  H.advance(200)

  local labels = {}
  for _, c in ipairs(H.controls) do
    if c._hidden == false and type(c._text) == "string" then labels[c._text] = true end
  end
  ok(not labels["RHYTHM"] and not labels["TIMELINE"] and not labels["STEADINESS"], "UPTIME is one view with no picker")
  local top = rows[order[1]]
  if top.slot and top.iv_n >= 3 then
    ok(seen["Steadiness"], "the row card carries the steadiness of a slotted skill")
  end
  ok(UV.click(1, 1) == false, "clicks on UPTIME change nothing")
  local tot = UV.totals()
  local clip, late, late_n = 0, 0, 0
  for oi = 1, order.n do
    local rr = rows[order[oi]]
    if rr.slot then
      for i = 1, rr.pn do
        if rr.pe[i] > 500 then clip = clip + rr.pe[i] elseif rr.pe[i] < -500 then late = late - rr.pe[i]; late_n = late_n + 1 end
      end
    end
  end
  ok(math.abs(tot.clip - clip) < 1 and math.abs(tot.late - late) < 1 and tot.late_n == late_n, "the refresh totals add the early and late errors of slotted skills")
  ok(clip > 0 or late_n > 0, "the recorded fixture has refresh errors to total")
  if tot.shown then ok(labels["REFRESH TOTALS"], "the totals box is drawn when it fits") end

  local rects = UV.rects()
  H.state.mouse_x = canvas:GetLeft() + lane.x + 20
  H.state.mouse_y = canvas:GetTop() + rects[1].y0 + 5
  local scrolled = UV.scroll(1)
  ok(scrolled == true or scrolled == false, "the wheel answers over the rows")

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
  local function shown(prefix)
    local k, i = 0, 1
    while rawget(_G, prefix .. i) do
      if not rawget(_G, prefix .. i)._hidden then k = k + 1 end
      i = i + 1
    end
    return k, i - 1
  end
  local cd_on, cd_made = shown("VermilionVizCd")
  ok(cd_made > 0 and cd_on > 0, "UPTIME draws its rings, got " .. cd_on .. " of " .. cd_made)
  G.next_view()
  ok(shown("VermilionVizCd") == 0, "no ring stays on screen after leaving UPTIME, got " .. shown("VermilionVizCd"))
  ok(shown("VermilionVizLine") == 0, "no viz line stays on screen after leaving UPTIME, got " .. shown("VermilionVizLine"))
  while view_label._text ~= "SKILL" do G.next_view() end
  ok(shown("VermilionVizCd") == 0, "no ring shows on the bar views")
  local function line_marks()
    local k = 0
    for _, ctl in ipairs(H.controls) do
      if ctl._hidden == false and (ctl._name or ""):find("Line%d+$") then k = k + 1 end
    end
    return k
  end
  for _, want in ipairs({ "SKILL", "TYPE", "CRIT" }) do
    while view_label._text ~= want do G.next_view() end
    ok(line_marks() == 0, "the " .. want .. " view draws bars with no line over them, got " .. line_marks())
  end

  G.on_flush_click()
  H.slotted, H.state.active_bar = nil, nil
  sv.settings.session_autosave = before_auto
end
