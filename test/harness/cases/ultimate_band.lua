return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G, U = Vermilion.Graph, Vermilion.Ultimate

  Vermilion.Metrics.reset()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  local view_label = VermilionGraphWindowViewLabel
  while view_label._text ~= "SKILL" do G.next_view() end

  H.slotted = {
    [HOTBAR_CATEGORY_PRIMARY] = { [8] = 41001 },
    [HOTBAR_CATEGORY_BACKUP]  = { [8] = 41002 },
  }
  H.state.ult_costs = { [HOTBAR_CATEGORY_PRIMARY] = 250, [HOTBAR_CATEGORY_BACKUP] = 400 }
  H.ability_icons = H.ability_icons or {}
  H.ability_icons[41001] = "EsoUI/Art/Icons/ult_front.dds"
  H.ability_icons[41002] = "EsoUI/Art/Icons/ult_back.dds"
  H.state.active_bar = HOTBAR_CATEGORY_PRIMARY

  G.on_record_click()
  local v = 0
  for _ = 1, 20 do
    v = v + 25
    H.ult_power(v)
    H.damage_out({ hit = 1000 })
    H.advance(1000)
  end
  H.state.active_bar = HOTBAR_CATEGORY_BACKUP
  H.fire(EVENT_ACTIVE_WEAPON_PAIR_CHANGED, 2, true)
  H.advance(1000)
  H.state.active_bar = HOTBAR_CATEGORY_PRIMARY
  H.fire(EVENT_ACTIVE_WEAPON_PAIR_CHANGED, 1, true)
  H.ult_used()
  H.ult_power(0)
  for _ = 1, 5 do
    H.damage_out({ hit = 1000 })
    H.advance(1000)
  end
  G.on_stop_click()

  local snap = U.snapshot()
  ok(snap.costs[1] == 250 and snap.costs[2] == 400, "both bars carry their own ultimate cost, got " .. tostring(snap.costs[1]) .. "/" .. tostring(snap.costs[2]))
  ok(snap.bars[1] == 41001 and snap.bars[2] == 41002, "both bars know their ultimate")
  ok(snap.steps > 10, "power updates build the charge curve, steps=" .. snap.steps)
  ok(snap.used == 1, "the cast registers exactly once, used=" .. snap.used)
  ok(snap.abilities == 2, "one ability record per bar at session start, got " .. snap.abilities)
  local st = U.steps()
  ok(U.pct_at(st[1], 1) <= 0.2, "charge starts near zero")
  ok(U.pct_at(st[1] + 19500, 1) >= 1, "the front bar (cost 250) is ready at 500 power")
  ok(U.pct_at(st[1] + 14500, 2) < 1, "the back bar (cost 400) is still charging at 375 power")

  local rows, ready, charging, tick = {}, {}, false, false
  local icons = {}
  for _, c in ipairs(H.controls) do
    local name = c._name or ""
    if c._hidden == false and name:find("^VermilionGraphUlt") then
      if name:find("Icon") then
        icons[#icons + 1] = c._tex
      elseif c._h == 5 and c._r then
        local y = c._anchor_list and c._anchor_list[1].oy
        rows[y] = true
        if c._r > 0.95 and c._g > 0.85 and c._b < 0.5 then ready[y] = true end
        if (c._a or 1) < 0.6 then charging = true end
      elseif c._h == 9 and c._w == 2 then
        tick = true
      end
    end
  end
  local n_rows = 0
  for _ in pairs(rows) do n_rows = n_rows + 1 end
  ok(n_rows == 2, "two ultimates draw two rows, got " .. n_rows)
  local ys = {}
  for y in pairs(rows) do ys[#ys + 1] = y end
  table.sort(ys)
  ok(ready[ys[1]] == true, "the front bar row shows the bright ready state")
  ok(ready[ys[2]] == true, "the back bar reaches its cost too and shows ready")
  local chip_h = (VermilionGraphSummaryBg._hidden == false) and (VermilionGraphSummaryBg._h + 8) or 0
  ok(chip_h > 0, "the chip is up after stop")
  ok(ys[1] >= 4 + chip_h, "rows sit below the summary chip, first row at " .. tostring(ys[1]))
  ok(charging, "charging segments render dimmed")
  ok(tick, "the cast renders as a tick over its row")
  ok(#icons == 2 and icons[1] == "EsoUI/Art/Icons/ult_front.dds" and icons[2] == "EsoUI/Art/Icons/ult_back.dds", "each row wears its own ultimate icon")

  local canvas = VermilionGraphWindowViewportCanvas
  local ch = canvas:GetHeight()
  local top_most = ch
  for _, c in ipairs(H.controls) do
    local name = c._name or ""
    if c._hidden == false and name:find("^VermilionEosSeg") and c._h and c._h > 0 then
      local oy = c._anchor_list and c._anchor_list[1].oy or 0
      local top = ch + oy - c._h
      if top < top_most then top_most = top end
    end
  end
  ok(top_most >= 28 + chip_h - 1, "bars stay below the chip and the ultimate area, top at " .. tostring(top_most) .. " chip " .. chip_h)

  H.ability_names = H.ability_names or {}
  H.ability_names[41001] = "Aggressive Horn"
  H.ability_names[41002] = "Dawnbreaker"
  local hit = VermilionGraphHit
  H.state.mouse_x = canvas:GetLeft() + canvas:GetWidth() - 30
  H.state.mouse_y = canvas:GetTop() + chip_h + 4 + 2
  hit._onOnMouseEnter(hit)
  H.advance(200)
  ok(VermilionHoverCardName._text == "Aggressive Horn", "hovering the front row names its ultimate, got " .. tostring(VermilionHoverCardName._text))
  ok((VermilionHoverCardStat._text or ""):find("ready to cast") ~= nil or (VermilionHoverCardStat._text or ""):find("charged") ~= nil,
     "the ultimate card says charged or ready, got " .. tostring(VermilionHoverCardStat._text))
  H.state.mouse_y = canvas:GetTop() + chip_h + 4 + 5 + 9 + 2
  H.advance(200)
  ok(VermilionHoverCardName._text == "Dawnbreaker", "hovering the back row names the other ultimate, got " .. tostring(VermilionHoverCardName._text))
  hit._onOnMouseExit(hit)
  H.state.mouse_x, H.state.mouse_y = 400, 300

  local sum_hit = VermilionGraphSummaryHit
  sum_hit._onOnMouseEnter(sum_hit)
  local found = false
  for i = 1, 9 do
    local rn = rawget(_G, "VermilionHoverCardRowName" .. i)
    if rn and rn._hidden == false and (rn._text or ""):find("Ultimate", 1, true) then found = true end
  end
  ok(found, "the damage report carries the ultimate rows")
  sum_hit._onOnMouseExit(sum_hit)

  local session = Vermilion.SessionStore.capture()
  ok(session and session.streams.ult ~= nil and session.streams.ulta ~= nil, "the session persists the ultimate streams")
  ok(G.load_session(session), "the captured session reloads")
  local snap2 = U.snapshot()
  ok(snap2.steps == snap.steps, "the reloaded session keeps the charge curve")
  ok(snap2.used == 1, "the reloaded session keeps the cast")
  ok(snap2.abilities == 2, "the reloaded session keeps both bars")
  ok(U.cost_at(2, st[1] + 1000) == 400, "the reloaded session keeps the back bar cost")
  ok(U.has_data(), "the band renders for the loaded session")
  local icons2 = 0
  for _, c in ipairs(H.controls) do
    local name = c._name or ""
    if c._hidden == false and name:find("^VermilionGraphUltIcon") then icons2 = icons2 + 1 end
  end
  ok(icons2 == 2, "the loaded session draws both icons again")

  G.on_flush_click()
  ok(not U.has_data(), "flush clears the ultimate session")

  G.on_record_click()
  for _ = 1, 3 do
    H.damage_out({ hit = 1000 })
    H.advance(1000)
  end
  local ghost = false
  for _, c in ipairs(H.controls) do
    local name = c._name or ""
    if c._hidden == false and name:find("^VermilionGraphUlt") then ghost = true end
  end
  ok(not ghost, "without a single power update the band does not draw at all")
  G.on_stop_click()
  G.on_flush_click()
  Vermilion.Visibility.set("graph", false)
  H.slotted = nil
  H.state.ult_costs = nil
  H.state.active_bar = nil
  Vermilion.Metrics.reset()
end
