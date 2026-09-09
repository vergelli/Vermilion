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
    if i == 3 then H.shield_out({ hit = 900 }) end
    H.advance(1000)
  end
  G.on_stop_click()

  local hit = VermilionGraphSummaryHit
  ok(hit._hidden == false, "the chip hit-box must show with the chip")
  ok(VermilionGraphSummaryHelp._hidden == false, "the chip must wear its help icon")
  local chip = VermilionGraphSummaryLabel._text or ""
  ok(chip:find("AVG") and chip:find("PEAK") and chip:find("CRIT") and chip:find("ACTIVE") and chip:find("SHIELD"),
     "the chip carries the session summary: " .. chip)
  hit._onOnMouseEnter(hit)
  ok(VermilionHoverCardName._text == "Damage report", "hovering the chip must open the damage report, got " .. tostring(VermilionHoverCardName._text))
  local stat = VermilionHoverCardStat._text or ""
  ok(stat:find("crit") ~= nil and stat:find("total") ~= nil, "report stat must read crit and total: " .. stat)
  local cp = tonumber(stat:match("|c%x%x%x%x%x%x(%d+)%% crit"))
  ok(cp and cp == 33, "the crit share is a third here, got " .. tostring(cp))
  ok(VermilionHoverCardRowName1._text == "Damage dealt" and VermilionHoverCardRowName1._hidden == false, "row 1 is the damage dealt")
  ok(VermilionHoverCardRowVal1._text == "9,000" or VermilionHoverCardRowVal1._text == "9000" or VermilionHoverCardRowVal1._text:find("9"), "row 1 carries the total: " .. tostring(VermilionHoverCardRowVal1._text))
  ok(VermilionHoverCardRowName2._text == "Shields cracked" and (VermilionHoverCardRowVal2._text or ""):find("%%"), "row 2 is the shield share")
  ok(VermilionHoverCardRowName3._text == "Hits" and (VermilionHoverCardRowVal3._text or ""):find("^12"), "row 3 counts the hits: " .. tostring(VermilionHoverCardRowVal3._text))
  ok(VermilionHoverCardRowName4._text == "Peak at" and (VermilionHoverCardRowVal4._text or ""):find("s") ~= nil, "row 4 says when the peak was")
  ok(VermilionHoverCardRowName5._text == "Time dealing damage" and (VermilionHoverCardRowVal5._text or ""):find("%%"), "row 5 is the active share")
  ok((VermilionHoverCardTime._text or ""):find("copy") ~= nil, "the card must tell the user the chip is clickable")
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
  ok(xml:find("<OnResizeStart>Vermilion.Graph.on_move_start()", 1, true) ~= nil, "the window wires OnResizeStart")
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

  H.sounds = {}
  hit._onOnMouseUp(hit, nil, true)
  ok(H.sounds[#H.sounds] == ("sound:" .. Vermilion.Sound.name("click")), "clicking the chip must confirm with a sound")
  ok(Vermilion.CopyBox.is_visible(), "clicking the chip must open the copy box")
  local eb = rawget(_G, "VermilionCopyBoxEdit")
  local txt = eb and eb._text or ""
  ok(txt:find("Damage report", 1, true) ~= nil and txt:find("Hits:", 1, true) ~= nil and txt:find("|c", 1, true) == nil,
     "copy text must carry the report in plain text: " .. txt)
  Vermilion.CopyBox.hide()

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
  VermilionGraphWindow:SetDimensions(w0, h0)
  H.state.mouse_x, H.state.mouse_y = 400, 300

  Vermilion.Visibility.set("graph", false)
  Vermilion.Metrics.reset()
end
