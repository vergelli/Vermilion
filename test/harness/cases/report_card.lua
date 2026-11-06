return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G = Vermilion.Graph

  Vermilion.Metrics.reset()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  local view_label = VermilionGraphWindowViewLabel
  while view_label._text ~= "SKILL" do G.next_view() end

  G.on_record_click()
  for i = 1, 6 do
    H.damage_out({ hit = 1000, ability_id = 31 })
    H.damage_out({ hit = 500, ability_id = 32, result = ACTION_RESULT_CRITICAL_DAMAGE })
    if i == 3 then
      H.shield_out({ hit = 900, target_unit_id = 900 })
      H.damage_out({ hit = 0, ability_id = 31, target_unit_id = 900 })
    end
    H.advance(1000)
  end
  G.on_stop_click()

  local hit = VermilionGraphSummaryHit
  local chip_label = VermilionGraphSummaryLabel
  local real_measure = chip_label.GetTextWidth
  chip_label.GetTextWidth = function(s) return math.min(#tostring(s._text or "") * 3, s._w or 0) end
  chip_label:SetWidth(40)
  G.on_resize_stop()
  local measured = chip_label._w
  chip_label.GetTextWidth = real_measure
  ok(measured > 40, "a narrow chip left by a shorter fight does not clip the next one, got " .. tostring(measured))
  ok(hit._hidden == false, "the chip hit-box must show with the chip")
  ok(VermilionGraphSummaryHelp._hidden == false, "the chip must wear its help icon")
  local chip = VermilionGraphSummaryLabel._text or ""
  ok(chip:find("AVG") and chip:find("PEAK") and chip:find("CRIT") and not chip:find("ACTIVE") and chip:find("SHIELD"),
     "the chip carries the session summary: " .. chip)
  ok(chip:find("|t14:14:Vermilion/assets/dtype/", 1, true) and chip:find("100%%"), "the chip ends with the dominant damage type icon and its share: " .. chip)
  hit._onOnMouseEnter(hit)
  ok(VermilionHoverCardName._text == "Damage report", "hovering the chip must open the damage report, got " .. tostring(VermilionHoverCardName._text))
  local stat = VermilionHoverCardStat._text or ""
  ok(stat:find("crit") ~= nil and stat:find("total") ~= nil, "report stat must read crit and total: " .. stat)
  local cp = tonumber(stat:match("|c%x%x%x%x%x%x(%d+)%% crit"))
  ok(cp and cp == 50, "crit counts hits, half of them here, got " .. tostring(cp))
  ok(VermilionHoverCardRowName1._text == "Damage dealt" and VermilionHoverCardRowName1._hidden == false, "row 1 is the damage dealt")
  ok(VermilionHoverCardRowVal1._text == "9,000" or VermilionHoverCardRowVal1._text == "9000" or VermilionHoverCardRowVal1._text:find("9"), "row 1 carries the total: " .. tostring(VermilionHoverCardRowVal1._text))
  ok(VermilionHoverCardRowName2._text == "Shields cracked" and (VermilionHoverCardRowVal2._text or ""):find("%%"), "row 2 is the shield share")
  ok(VermilionHoverCardRowName3._text == "Hits" and (VermilionHoverCardRowVal3._text or ""):find("^12"), "row 3 counts the hits: " .. tostring(VermilionHoverCardRowVal3._text))
  ok(VermilionHoverCardRowName4._text == "Peak at" and (VermilionHoverCardRowVal4._text or ""):find("s") ~= nil, "row 4 says when the peak was")
  ok(VermilionHoverCardRowName5._text == "Main damage type" and (VermilionHoverCardRowVal5._text or ""):find("100%%"), "row 5 names the main damage type, got " .. tostring(VermilionHoverCardRowVal5._text))
  ok(VermilionHoverCard._draw_tier == DT_HIGH, "the card draws above every label")
  hit._onOnMouseExit(hit)
  ok(VermilionHoverCard._hidden == true, "leaving the chip closes the report")

  local hr = H.layout(hit)
  H.state.mouse_x, H.state.mouse_y = hr.x + 4, hr.y + 4
  hit._onOnMouseEnter(hit)
  ok(H.update_registered("VermilionCardGuard"), "the open report watches the mouse")
  H.advance(300)
  ok(VermilionHoverCard._hidden == false, "the report stays while the mouse rests on the chip")
  H.state.mouse_x, H.state.mouse_y = hr.x - 200, hr.y - 200
  H.advance(300)
  ok(VermilionHoverCard._hidden == true, "the report closes on its own when the mouse leaves without an exit event")
  ok(not H.update_registered("VermilionCardGuard"), "the watch stops with the report")

  H.state.mouse_x, H.state.mouse_y = hr.x + 4, hr.y + 4
  hit._onOnMouseEnter(hit)
  ok(VermilionHoverCard._hidden == false, "the report reopens")
  G.on_move_start()
  ok(VermilionHoverCard._hidden == true, "dragging the window closes the report at once")
  H.advance(200)
  ok(not H.update_registered("VermilionCardGuard"), "the watch stops once the card is gone")
  local xml = assert(io.open(HARNESS_ROOT .. "/ui/graph.xml")):read("*a")
  ok(xml:find("<OnMoveStart>Vermilion.Graph.on_move_start()", 1, true) ~= nil, "the window wires OnMoveStart")
  ok(xml:find("<OnResizeStart>Vermilion.Graph.on_resize_start()", 1, true) ~= nil, "the window wires OnResizeStart")
  ok(xml:find("<OnMouseDoubleClick>Vermilion.Graph.on_title_double_click()", 1, true) ~= nil, "the title bar resets the size on double click")

  hit._onOnMouseEnter(hit)
  ok(VermilionHoverCard._hidden == false, "the report reopens for the watchdog check")
  local state = G.card_state()
  ok(state:find("hidden=false", 1, true) and state:find("report=true", 1, true), "the card probe reads the open report: " .. state)
  H.state.hold_fade = true
  hit._onOnMouseExit(hit)
  ok(VermilionHoverCard._hidden == false, "a fade whose callback never fires leaves the card on screen")
  H.advance(300)
  ok(VermilionHoverCard._hidden == true and (VermilionHoverCard._alpha or 0) == 0, "the watchdog forces the stuck card off")
  ok(not H.update_registered("VermilionCardGuard"), "the watchdog stops once the card is hidden")
  H.state.hold_fade = nil

  hit._onOnMouseEnter(hit)
  VermilionHoverCard:SetAlpha(0)
  H.state.hold_fade = true
  hit._onOnMouseExit(hit)
  ok(VermilionHoverCard._hidden == true, "leaving before the fade-in ticks hides the card without an animation")
  H.state.hold_fade = nil
  H.state.mouse_x, H.state.mouse_y = nil, nil

  ok(hit._onOnMouseUp == nil, "the chip only explains, the export has its own button")

  local session = Vermilion.SessionStore.capture()
  ok(G.load_session(session), "captured session must reload")
  hit._onOnMouseEnter(hit)
  ok(VermilionHoverCardRowName1._hidden == false and tonumber((VermilionHoverCardStat._text or ""):match("|c%x%x%x%x%x%x(%d+)%% crit")) == cp,
     "loaded session must show the same report")
  ok((VermilionHoverCardRowVal3._text or ""):find("^12"), "a library session reports its saved hits, got " .. tostring(VermilionHoverCardRowVal3._text))
  local saved_total = (VermilionHoverCardStat._text or ""):match("(%d[%d,%.k]*) total")
  ok(saved_total ~= nil and saved_total ~= "0", "a library session reports its saved total, got " .. tostring(VermilionHoverCardStat._text))
  hit._onOnMouseExit(hit)

  G.on_flush_click()
  ok(hit._hidden == true, "flush must hide the chip hit-box")

  local w0, h0 = VermilionGraphWindow:GetDimensions()
  VermilionGraphWindow:SetDimensions(700, 500)
  H.state.mouse_x, H.state.mouse_y = VermilionGraphWindow:GetLeft() + 20, VermilionGraphWindow:GetTop() + 10
  G.on_title_double_click()
  local w1, h1 = VermilionGraphWindow:GetDimensions()
  ok(w1 == Vermilion.Constants.GRAPH_DEFAULT_W and h1 == Vermilion.Constants.GRAPH_DEFAULT_H, "a double click on the title restores the default size")
  ok(w1 == 718 and h1 == 472, "and that size is a comfortable one, not the minimum, got " .. tostring(w1) .. "x" .. tostring(h1))
  local xml_w, xml_h = xml:match('name="VermilionGraphWindow".-<Dimensions x="(%d+)" y="(%d+)"/>')
  ok(tonumber(xml_w) == w1 and tonumber(xml_h) == h1, "a new install opens at that same size, got " .. tostring(xml_w) .. "x" .. tostring(xml_h))

  local status = VermilionGraphWindowStatusLabel
  local left = tonumber(xml:match('StatusLabel".-offsetX="(%d+)"'))
  local export_off, export_w = xml:match('ExportBtn".-offsetX="%-(%d+)".-Dimensions x="(%d+)"')
  local export_room = tonumber(export_off) + tonumber(export_w)
  ok(status._wrap == TEXT_WRAP_MODE_ELLIPSIS and status._max_lines == 1, "a long status is cut on one line")
  ok(left + status._max_x <= w1 - export_room, "after the double click it stops before the export button, got " .. tostring(status._max_x))
  local min_w = Vermilion.Constants.GRAPH_MIN_W
  ok(min_w > 440 and min_w < 600, "the minimum width grew a little, got " .. tostring(min_w))
  ok(VermilionGraphWindow._min_x == min_w, "and the window enforces it, got " .. tostring(VermilionGraphWindow._min_x))
  for _, width in ipairs({ min_w, 600, 1000 }) do
    VermilionGraphWindow:SetDimensions(width, 312)
    G.on_resize_stop()
    ok(status._max_x >= 80 and left + status._max_x <= width - export_room, "at " .. width .. " wide the status stays inside the row with room to read, got " .. tostring(status._max_x))
  end
  VermilionGraphWindow:SetDimensions(600, 312)
  G.on_resize_start()
  VermilionGraphWindow:SetDimensions(500, 312)
  VermilionGraphWindow._onOnUpdate(VermilionGraphWindow)
  ok(left + status._max_x <= 500 - export_room, "the cut follows the window during the drag, got " .. tostring(status._max_x))
  G.on_resize_stop()
  local function tab_rows()
    local rows, labels = {}, { "SKILL", "TYPE", "PRESSURE", "CRIT", "CONTRIB", "DEBUFFS", "RESOURCES", "UPTIME" }
    for v = 1, #labels do
      local hitbox = rawget(_G, "VermilionGraphTab" .. v)
      local label = rawget(_G, "VermilionGraphTab" .. v .. "Label")
      rows[v] = { x = hitbox._anchor_list[1].ox, w = hitbox._w, lw = label._w, lx = label._anchor_list[1].ox, text = #labels[v] * 7 }
    end
    return rows
  end
  for _, width in ipairs({ min_w, 560, 718, 1000 }) do
    local strip_w = width - 40
    VermilionGraphWindow:SetDimensions(width, 312)
    VermilionGraphWindowTabs:SetWidth(strip_w)
    G.on_resize_stop()
    local rows = tab_rows()
    local x = 0
    for v, r in ipairs(rows) do
      ok(r.x == x, "at " .. width .. " tab " .. v .. " starts where the last ended, got " .. tostring(r.x) .. " not " .. tostring(x))
      ok(r.w >= r.text + 6, "at " .. width .. " tab " .. v .. " fits its label, got " .. tostring(r.w) .. " for " .. tostring(r.text))
      ok(r.lw == r.w and r.lx == r.x, "its label follows it")
      x = x + r.w
    end
    ok(x <= strip_w and x > strip_w - 9, "at " .. width .. " the tabs fill the strip, got " .. tostring(x) .. " of " .. tostring(strip_w))
  end
  VermilionGraphWindow:SetDimensions(718, 312)
  VermilionGraphWindowTabs:SetWidth(678)
  G.on_resize_stop()
  local even = tab_rows()
  for v = 2, #even do
    ok(even[v].w == even[1].w, "with room to spare the tabs are all the same width, got " .. tostring(even[v].w) .. " and " .. tostring(even[1].w))
  end
  local zero = H.string_width_zero
  H.string_width_zero = true
  G.on_resize_stop()
  H.string_width_zero = zero
  local blind = tab_rows()
  for v = 2, #blind do
    ok(blind[v].w == blind[1].w, "if the font cannot be measured the tabs stay even")
  end
  VermilionGraphWindow:SetDimensions(w0, h0)
  VermilionGraphWindowTabs._w = nil
  G.on_resize_stop()
  H.state.mouse_x, H.state.mouse_y = 400, 300

  Vermilion.Visibility.set("graph", false)
  Vermilion.Metrics.reset()
end
