return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local AR = Vermilion.AutoRecord
  local TB = Vermilion.TemporalBuffer
  local sv = Vermilion.SavedVars
  sv.settings = sv.settings or {}
  local before_auto, before_stop = sv.settings.session_autosave, sv.settings.auto_stop

  Vermilion.Metrics.reset()
  Vermilion.Graph.on_flush_click()
  H.combat_state(false)
  H.set_bosses({})
  AR.set_mode("off")
  AR.set_auto_stop(false)
  sv.settings.session_autosave = false
  ok(not H.update_registered("VermilionAutoRecTick"), "no tick with auto-record off and auto-stop off")

  Vermilion.Graph.on_record_click()
  H.combat_state(true)
  H.advance(2000)
  H.combat_state(false)
  H.advance(8000)
  ok(TB.is_recording(), "with auto-stop off a manual recording survives leaving combat")
  Vermilion.Graph.on_stop_click()
  Vermilion.Graph.on_flush_click()

  local btn = VermilionSettingsPanelAutoStopBtn
  ok(btn ~= nil and btn._text == "Auto-stop: Off", "settings button reads Off by default, got " .. tostring(btn and btn._text))
  H.sounds = {}
  Vermilion.Settings.on_autostop_click()
  ok(AR.get_auto_stop() == true and sv.settings.auto_stop == true, "the button turns auto-stop on and persists it")
  ok(btn._text == "Auto-stop: On", "the button reads On, got " .. tostring(btn._text))
  ok(H.update_registered("VermilionAutoRecTick"), "auto-stop alone registers the tick")

  Vermilion.Graph.on_record_click()
  ok(TB.is_recording(), "manual recording started")
  H.combat_state(true)
  H.advance(3000)
  H.combat_state(false)
  H.advance(2000)
  ok(TB.is_recording(), "the grace holds the recording for a few seconds after combat")
  H.combat_state(true)
  H.advance(1000)
  ok(TB.is_recording(), "re-engaging within the grace cancels the stop")
  H.combat_state(false)
  H.advance(7000)
  ok(not TB.is_recording(), "a manual recording stops on its own after the grace")
  ok(TB.count() > 0, "the recording stays frozen for review")
  ok(not AR.is_auto_session(), "an auto-stopped manual recording is still a manual session")
  ok(VermilionGraphWindowStatusLabel._text:find("NOT SAVED", 1, true) ~= nil,
     "after the auto-stop the status reminds it is not saved, got " .. tostring(VermilionGraphWindowStatusLabel._text))
  ok(VermilionGraphWindowSaveBtn._enabled == true, "the save icon is ready after an auto-stop")

  H.combat_state(true)
  H.advance(2000)
  ok(not TB.is_recording(), "auto-stop never starts a recording on its own")
  H.combat_state(false)
  H.advance(7000)

  Vermilion.Graph.on_flush_click()
  Vermilion.Graph.on_record_click()
  H.advance(3000)
  ok(TB.is_recording(), "a recording started out of combat keeps going while no combat happens")
  Vermilion.Graph.on_stop_click()
  Vermilion.Graph.on_flush_click()

  AR.set_mode("combat")
  H.combat_state(true)
  ok(TB.is_recording() and AR.is_auto_active(), "auto-record still starts on combat with auto-stop on")
  H.combat_state(false)
  H.advance(7000)
  ok(not TB.is_recording(), "auto-record still stops after its grace")
  AR.set_mode("off")
  ok(H.update_registered("VermilionAutoRecTick"), "the tick stays while auto-stop is on")

  Vermilion.Settings.on_autostop_click()
  ok(AR.get_auto_stop() == false, "the button turns auto-stop off")
  ok(not H.update_registered("VermilionAutoRecTick"), "the tick goes away with both off")

  Vermilion.Graph.on_flush_click()
  sv.settings.session_autosave, sv.settings.auto_stop = before_auto, before_stop
  AR.set_auto_stop(before_stop == true)
  Vermilion.Metrics.reset()
end
