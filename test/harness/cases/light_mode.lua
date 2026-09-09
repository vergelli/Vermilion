return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G = Vermilion.Graph

  Vermilion.Metrics.reset()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  local sv = Vermilion.SavedVars
  sv.settings = sv.settings or {}
  sv.settings.light_mode = true
  sv.settings.light_alpha_pct = 40

  H.state.mouse_x, H.state.mouse_y = 1900, 1000
  G.on_record_click()
  ok(G.is_light_active(), "recording with light mode on must enter light")
  ok(VermilionGraphWindowChromeTop._hidden == true, "chrome strips must hide")
  ok(VermilionGraphWindowBg._hidden == true, "outer border must hide")
  ok(VermilionGraphWindowRecordBtn._hidden == true, "record button must hide")
  ok(VermilionGraphWindowReadoutLabel._hidden == true, "the live readout hides with the chrome")
  ok(VermilionGraphWindowStopBtn._hidden == true, "minimal controls stay hidden until hover")
  ok(math.abs((VermilionGraphWindow._alpha or 1) - 0.4) < 0.01,
     "window must dim to the configured alpha, got " .. tostring(VermilionGraphWindow._alpha))

  local w = H.layout(VermilionGraphWindow)
  H.state.mouse_x, H.state.mouse_y = w.x + 10, w.y + 10
  H.advance(300)
  ok(VermilionGraphWindow._alpha == 1, "hover must go fully opaque")
  ok(VermilionGraphWindowStopBtn._hidden == false, "hover must reveal stop")
  ok(VermilionGraphWindowTabs._hidden == false, "hover must reveal the view tabs")
  ok(VermilionGraphWindowChromeTop._hidden == true, "chrome stays off even on hover")

  H.state.mouse_x, H.state.mouse_y = 1900, 1000
  H.advance(300)
  ok(math.abs((VermilionGraphWindow._alpha or 1) - 0.4) < 0.01, "leaving must dim again")
  ok(VermilionGraphWindowStopBtn._hidden == true, "leaving must tuck the minimal controls")

  Vermilion.Settings.on_lightalpha_track_click(VermilionSettingsPanelSliderTrackLightAlpha)
  ok(Vermilion.SavedVars.settings.light_alpha_pct ~= nil, "the opacity slider persists")

  G.on_stop_click()
  ok(not G.is_light_active(), "stop must exit light mode")
  ok(VermilionGraphWindowChromeTop._hidden == false, "chrome must restore on stop")
  ok(VermilionGraphWindow._alpha == 1, "alpha must restore on stop")
  ok(VermilionGraphWindowRecordBtn._hidden == false, "record button must restore")
  ok(not H.update_registered("VermilionLightPoll"), "the hover poll must unregister")

  sv.settings.light_mode = false
  G.on_record_click()
  ok(not G.is_light_active(), "light off means recording keeps the chrome")
  ok(VermilionGraphWindowChromeTop._hidden == false, "chrome untouched with light off")
  Vermilion.Settings.on_light_click()
  ok(sv.settings.light_mode == true and G.is_light_active(), "turning the setting on mid-recording enters light")
  Vermilion.Settings.on_light_click()
  ok(sv.settings.light_mode == false and not G.is_light_active(), "turning it off leaves light")
  G.on_stop_click()

  sv.settings.light_alpha_pct = nil
  G.on_flush_click()
  Vermilion.Visibility.set("graph", false)
  H.state.mouse_x, H.state.mouse_y = 400, 300
  Vermilion.Metrics.reset()
end
