return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G = Vermilion.Graph

  Vermilion.Metrics.reset()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  local view_label = VermilionGraphWindowViewLabel
  while view_label._text ~= "SKILL" do G.next_view() end

  local names = { "SKILL", "TYPE", "OUTCOME", "CRIT", "CONTRIB" }
  for v = 1, 5 do
    local lbl = rawget(_G, "VermilionGraphTab" .. v .. "Label")
    local hit = rawget(_G, "VermilionGraphTab" .. v)
    ok(lbl and lbl._text == names[v], "tab " .. v .. " must read " .. names[v])
    ok(hit and type(hit._onOnMouseEnter) == "function", "tab " .. v .. " must explain itself on hover")
    H.last_tooltip = nil
    hit._onOnMouseEnter(hit)
    ok(type(H.last_tooltip) == "string" and #H.last_tooltip > 5, "tab " .. v .. " tooltip must carry text")
    hit._onOnMouseExit(hit)
  end
  ok(VermilionGraphTab1Line._hidden == false and VermilionGraphTab3Line._hidden == true, "only the active tab wears the line")

  H.sounds = {}
  VermilionGraphTab3._onOnMouseUp(VermilionGraphTab3, nil, true)
  ok(view_label._text == "OUTCOME", "clicking a tab switches the view, got " .. tostring(view_label._text))
  ok(H.sounds[#H.sounds] == ("sound:" .. Vermilion.Sound.name("page")), "switching a view turns a page")
  ok(VermilionGraphTab3Line._hidden == false and VermilionGraphTab1Line._hidden == true, "the line follows the active tab")

  H.sounds = {}
  VermilionGraphTab3._onOnMouseUp(VermilionGraphTab3, nil, true)
  ok(#H.sounds == 0, "clicking the active tab stays silent")

  VermilionGraphTab5._onOnMouseUp(VermilionGraphTab5, nil, true)
  ok(view_label._text == "CONTRIB", "the last tab reaches CONTRIB")
  G.next_view()
  ok(view_label._text == "SKILL" and VermilionGraphTab1Line._hidden == false, "arrow navigation still updates the tabs")
  ok(G.step_view(1) == true and view_label._text == "TYPE", "the keybind steps forward")
  ok(G.step_view(-1) == true and view_label._text == "SKILL", "the keybind steps back")

  local strip = VermilionGraphWindowTabs
  local w = strip:GetWidth()
  ok(w > 0, "the strip must have a width")
  local tw = math.floor(w / 5)
  ok(VermilionGraphTab1._w == tw and VermilionGraphTab5._w == tw, "tabs share the strip evenly")
  ok(VermilionGraphWindowPrevViewBtn._hidden ~= false, "the old arrows are not part of the chrome anymore")

  Vermilion.SavedVars.settings.light_mode = true
  H.state.mouse_x, H.state.mouse_y = 1900, 1000
  G.on_record_click()
  H.damage_out({ hit = 1000 })
  H.advance(1000)
  ok(strip._hidden == true, "light mode hides the tab strip")
  G.on_stop_click()
  ok(strip._hidden == false, "stopping brings the tabs back")
  Vermilion.SavedVars.settings.light_mode = false

  Vermilion.Visibility.set("graph", false)
  ok(G.step_view(1) == false, "the keybind does nothing while the graph is closed")
  G.on_flush_click()
  Vermilion.Metrics.reset()
end
