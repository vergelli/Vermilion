return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local function eq(a, b, msg)
    if a ~= b then error(msg .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")", 2) end
  end
  local S  = Vermilion.Settings
  local sv = Vermilion.SavedVars

  local svg = dofile(HARNESS_ROOT .. "/test/simlab/svg.lua")
  svg.apply_xml(HARNESS_ROOT .. "/ui/settings.xml")

  local panel = H.layout(VermilionSettingsPanel)
  ok(panel.w == 600 and panel.h == 300, string.format("panel must be 600x300, got %dx%d", panel.w, panel.h))
  local left_col = {
    VermilionSettingsPanelSampleBtn,
    VermilionSettingsPanelRecordingNote,
    VermilionSettingsPanelSliderTrackVPAlpha,
    VermilionSettingsPanelSliderTrackCritThresh,
  }
  local right_col = {
    VermilionSettingsPanelUnknownBtn,
    VermilionSettingsPanelLogoBtn,
    VermilionSettingsPanelSoundsBtn,
    VermilionSettingsPanelLightBtn,
    VermilionSettingsPanelSliderTrackLightAlpha,
  }
  for _, c in ipairs(left_col) do
    local r = H.layout(c)
    ok(r.x >= panel.x + 14 and r.x + r.w <= panel.x + 290, (c._name or "?") .. " must sit in the left column")
  end
  for _, c in ipairs(right_col) do
    local r = H.layout(c)
    ok(r.x == panel.x + 314, (c._name or "?") .. " must sit in the right column, x=" .. r.x)
    ok(r.x + r.w <= panel.x + 590, (c._name or "?") .. " must stay inside the panel")
    ok(r.y + r.h <= panel.y + panel.h - 30, (c._name or "?") .. " must clear the reset row")
  end
  for _, name in ipairs({ "SecGraph", "SecRecording", "SecGeneral" }) do
    local lbl = rawget(_G, "VermilionSettingsPanel" .. name)
    ok(lbl and type(lbl._text) == "string" and #lbl._text > 2, name .. " carries a section title")
  end
  ok((VermilionSettingsPanelVersionLabel._text or ""):find(Vermilion.Constants.VERSION, 1, true), "the panel shows the build version")

  Vermilion.Visibility.set("graph", true)
  S.toggle()
  ok(not VermilionSettingsPanel:IsHidden(), "panel must open")
  ok((VermilionSettingsPanelVPAlphaLabel._text or "") ~= "", "sliders refresh with the track geometry")

  local TB = Vermilion.TemporalBuffer
  eq(TB.capacity(), Vermilion.Constants.TEMPORAL.CAPACITY, "the buffer has one fixed capacity")
  eq(S.snapshot().time_window_s, 1800, "1 Hz keeps 30 minutes")
  ok(VermilionSettingsPanelSampleBtn._text:find("1 Hz", 1, true), "the button names the rate")
  S.on_sample_click()
  eq(S.snapshot().sample_rate_ms, 500, "the button moves to 2 Hz")
  eq(S.snapshot().time_window_s, 900, "2 Hz keeps 15 minutes")
  eq(TB.capacity(), Vermilion.Constants.TEMPORAL.CAPACITY, "the rate does not touch the buffer")
  ok(VermilionSettingsPanelSampleBtn._text:find("2 Hz", 1, true), "the button follows")
  TB.start_recording()
  S.on_sample_click()
  eq(S.snapshot().sample_rate_ms, 500, "the rate does not change mid recording")
  TB.stop_recording()
  S.on_reset_click()
  eq(S.snapshot().sample_rate_ms, 1000, "reset restores the sample rate")
  eq(S.snapshot().crit_threshold_pct, 50, "reset restores the crit threshold")

  local track = VermilionSettingsPanelSliderTrackCritThresh
  local function at(pct) H.state.mouse_x = track:GetLeft() + 2 + (track:GetWidth() - 4) * pct end
  at(0.73)
  track._onOnMouseDown(track)
  eq(S.snapshot().crit_threshold_pct, 73, "a press moves to any percent, not to fixed steps")
  eq(VermilionSettingsPanelCritThreshLabel._text, "73%", "the label follows")
  at(0.21)
  H.advance(50)
  eq(S.snapshot().crit_threshold_pct, 21, "dragging follows the mouse")
  eq(sv.graph.crit_threshold_pct, 21, "and persists")
  at(5)
  H.advance(50)
  eq(S.snapshot().crit_threshold_pct, 100, "dragging past the end clamps")
  track._onOnMouseUp(track)
  at(0.4)
  H.advance(50)
  eq(S.snapshot().crit_threshold_pct, 100, "releasing ends the drag")
  local fill = VermilionSettingsCritThreshFill
  ok(fill._w == track:GetWidth() - 4, "a full slider shows the whole fill")
  S.on_reset_click()
  eq(VermilionSettingsPanelCritThreshLabel._text, "50%", "reset moves the slider back")
  H.state.mouse_x = nil

  local old = {}
  for i = 1, 2400 do old[i] = { t = i * 200, eDPS = 1, ShDPS = 0, crit = 0, noncrit = 0 } end
  TB.load_session(old)
  eq(TB.count(), 2400, "an old long session loads whole")
  eq(TB.at(1).t, 200, "and keeps its first sample")
  TB.start_recording()
  eq(TB.capacity(), Vermilion.Constants.TEMPORAL.CAPACITY, "the next recording returns to the fixed capacity")
  TB.stop_recording()
  TB.clear()

  S.toggle()
  ok(VermilionSettingsPanel:IsHidden(), "panel must close")
  Vermilion.Visibility.set("graph", false)
end
