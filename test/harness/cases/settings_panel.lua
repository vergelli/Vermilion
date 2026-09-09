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
  ok(panel.w == 600 and panel.h == 346, string.format("panel must be 600x346, got %dx%d", panel.w, panel.h))
  local left_col = {
    VermilionSettingsPanelProfileDropdown,
    VermilionSettingsPanelSliderTrackSample,
    VermilionSettingsPanelSliderTrackTWindow,
    VermilionSettingsPanelSliderTrackVPAlpha,
    VermilionSettingsPanelSliderTrackCritThresh,
  }
  local right_col = {
    VermilionSettingsPanelAutoRecBtn,
    VermilionSettingsPanelAutosaveBtn,
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
  do
    local a = H.layout(VermilionSettingsPanelAutosaveBtn)
    local b = H.layout(VermilionSettingsPanelAutoStopBtn)
    ok(b.y == a.y, "Auto-stop shares the Autosave row")
    ok(b.x >= a.x + a.w + 4, "Auto-stop starts after Autosave with a gap")
    ok(b.x + b.w <= panel.x + 590, "Auto-stop stays inside the panel")
    ok(a.w == b.w, "Autosave and Auto-stop split the row evenly")
  end
  for _, name in ipairs({ "SecProfile", "SecGraph", "SecRecording", "SecGeneral" }) do
    local lbl = rawget(_G, "VermilionSettingsPanel" .. name)
    ok(lbl and type(lbl._text) == "string" and #lbl._text > 2, name .. " carries a section title")
  end
  ok((VermilionSettingsPanelVersionLabel._text or ""):find(Vermilion.Constants.VERSION, 1, true), "the panel shows the build version")
  ok(VermilionSettingsConfirm._draw_tier == DT_HIGH, "the confirm dialog sits on the high draw tier")

  Vermilion.Visibility.set("graph", true)
  S.toggle()
  ok(not VermilionSettingsPanel:IsHidden(), "panel must open")
  ok((VermilionSettingsPanelSampleLabel._text or "") ~= "", "sliders refresh with the track geometry")

  local ts = VermilionSettingsPanelSliderTrackTWindow
  local ss = VermilionSettingsPanelSliderTrackSample
  local fill_s = VermilionSettingsSampleFill
  local fill_t = VermilionSettingsTWindowFill
  local function heavy_tint() return fill_s._g > 0.5 and fill_t._g > 0.5 end

  H.state.mouse_x = ts:GetLeft() + ts:GetWidth() * 0.999
  S.on_twindow_track_click(ts)
  eq(S.snapshot().time_window_s, 1200, "the window slider reaches 20 minutes")
  ok(not S.is_heavy_combo() and not heavy_tint(), "20 minutes at 1 Hz stays within the safe tint")
  ok(VermilionSettingsConfirm._hidden == true, "no question for a safe combination")

  H.state.mouse_x = ss:GetLeft() + ss:GetWidth() * 0.999
  S.on_sample_track_click(ss)
  ok(S.is_heavy_combo() and heavy_tint(), "5 Hz over 20 minutes tints the sliders")
  ok(VermilionSettingsConfirm._hidden == false, "an experimental combination asks first")
  local msg = VermilionSettingsConfirmMsg._text or ""
  ok(msg:find("1 Hz", 1, true) and msg:find("6000", 1, true), "the question states the cost and the recommendation: " .. msg)
  S.on_confirm_no()
  ok(VermilionSettingsConfirm._hidden == true, "Go back closes the question")
  ok(S.snapshot().sample_rate_ms == 1000 and S.snapshot().time_window_s == 1200, "Go back restores the previous values")
  ok(not heavy_tint(), "the tint follows the restored values")

  S.on_sample_track_click(ss)
  S.on_confirm_yes()
  ok(S.snapshot().sample_rate_ms == 200 and heavy_tint(), "Keep it anyway leaves the combination in place")
  ok(VermilionSettingsConfirm._hidden == true, "the question closes on Keep")
  eq(Vermilion.TemporalBuffer.capacity(), 6000, "the buffer follows the heavy combination")

  H.state.mouse_x = ts:GetLeft() + ts:GetWidth() * 0.5
  S.on_twindow_track_click(ts)
  ok(VermilionSettingsConfirm._hidden == true, "shrinking a heavy window does not ask again")
  S.on_reset_click()
  ok(not S.is_heavy_combo() and not heavy_tint(), "reset returns to the safe tint")
  eq(S.snapshot().sample_rate_ms, 1000, "reset restores the sample rate")
  eq(S.snapshot().time_window_s, 60, "reset restores the window")
  eq(S.snapshot().crit_threshold_pct, 50, "reset restores the crit threshold")
  H.state.mouse_x = nil

  local sxml = assert(io.open(HARNESS_ROOT .. "/ui/settings.xml")):read("*a")
  ok(sxml:find("<OnEnter>Vermilion.Settings.on_profile_save_click()", 1, true) ~= nil, "Enter saves the profile name")
  ok(sxml:find("Vermilion.Settings.on_pname_focus(true)", 1, true) ~= nil, "the profile name box lights up on focus")
  S.on_pname_focus(true)
  S.on_pname_focus(false)
  S.toggle()
  ok(VermilionSettingsPanel:IsHidden(), "panel must close")
  Vermilion.Visibility.set("graph", false)
end
