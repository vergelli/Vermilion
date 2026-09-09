return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local function eq(a, b, msg)
    if a ~= b then error(msg .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")", 2) end
  end

  local S  = Vermilion.Settings
  local sv = Vermilion.SavedVars

  S.on_reset_click()
  eq(S.snapshot().profile_id, "custom", "the panel starts on Custom")
  ok(S.on_profile_selected("solo") == nil and S.snapshot().profile_id == "custom", "an unknown preset id is ignored")
  sv.settings.user_profiles = sv.settings.user_profiles or {}
  sv.settings.user_profiles["PvP Night"] = { sample = 200, twindow = 30, vpalpha = 60, critthresh = 70 }
  S.on_profile_selected("user:PvP Night")
  eq(S.snapshot().sample_rate_ms, 200, "a user profile applies its sample rate")
  eq(S.snapshot().time_window_s, 30, "a user profile applies its window")
  eq(S.snapshot().viewport_alpha_pct, 60, "a user profile applies its viewport alpha")
  eq(S.snapshot().crit_threshold_pct, 70, "a user profile applies its crit threshold")
  eq(Vermilion.Graph.get_crit_threshold(), 70, "the graph follows the profile's crit threshold")
  eq(Vermilion.TemporalBuffer.capacity(), 150, "the buffer follows the profile")

  VermilionSettingsPanelPNameBoxEdit:SetText("Raid Night")
  S.on_profile_save_click()
  ok(sv.settings.user_profiles["Raid Night"], "user profile not persisted")
  eq(sv.settings.user_profiles["Raid Night"].sample, 200, "saved sample rate")
  eq(sv.settings.profile, "user:Raid Night", "profile id not persisted")
  eq(S.snapshot().profile_label, "* Raid Night", "profile label")

  local ss = VermilionSettingsPanelSliderTrackSample
  H.state.mouse_x = ss:GetLeft() + 1
  S.on_sample_track_click(ss)
  H.state.mouse_x = nil
  eq(S.snapshot().profile_id, "custom", "touching a slider drops back to Custom")
  eq(sv.settings.profile, "custom", "and persists it")

  S.on_reset_click()
  eq(S.snapshot().sample_rate_ms, 1000, "reset restores the default rate")
  eq(S.snapshot().time_window_s, 60, "reset restores the default window")
  eq(S.snapshot().profile_id, "custom", "reset lands on Custom")

  S.on_profile_selected("user:Raid Night")
  eq(S.snapshot().sample_rate_ms, 200, "loading a user profile restores the rate")
  eq(S.snapshot().time_window_s, 30, "loading a user profile restores the window")

  VermilionSettingsPanelPNameBoxEdit:SetText("")
  S.on_profile_save_click()
  ok(sv.settings.user_profiles["Raid Night"], "empty-name save overwrites the selected user profile")

  S.on_profile_delete_click()
  ok(VermilionSettingsConfirm._hidden == false, "deleting a profile asks first")
  ok((VermilionSettingsConfirmMsg._text or ""):find("Raid Night", 1, true), "the question names the profile")
  S.on_confirm_no()
  ok(sv.settings.user_profiles["Raid Night"] and VermilionSettingsConfirm._hidden == true, "Keep leaves the profile alone")
  S.on_profile_delete_click()
  S.on_confirm_yes()
  eq(sv.settings.user_profiles["Raid Night"], nil, "delete removes the profile")
  eq(S.snapshot().profile_id, "custom", "after delete fall back to custom")

  H.chat = {}
  S.on_profile_delete_click()
  eq(S.snapshot().profile_id, "custom", "deleting with nothing selected keeps Custom")
  ok(H.chat_contains("Select one"), "and explains what to do")
  sv.settings.user_profiles["PvP Night"] = nil
  S.on_reset_click()
end
