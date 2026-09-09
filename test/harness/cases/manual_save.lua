return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local SS = Vermilion.SessionStore
  local sv = Vermilion.SavedVars
  local btn = VermilionGraphWindowSaveBtn
  local status = VermilionGraphWindowStatusLabel

  sv.settings = sv.settings or {}
  local before_lib, before_auto = sv.library, sv.settings.session_autosave
  sv.library = { version = 1, sessions = {} }
  sv.settings.session_autosave = false
  SS.init()
  Vermilion.Metrics.reset()
  Vermilion.Visibility.set("graph", true)
  Vermilion.Graph.on_flush_click()
  H.state.zone = "Fungal Grotto"

  ok(btn ~= nil, "the save button must exist on the graph window")
  ok(type(btn._onOnMouseEnter) == "function", "the save button must explain itself on hover")
  ok(btn._enabled == false, "nothing to save on an empty graph")

  H.chat = {}
  ok(Vermilion.Graph.on_save_click() == false, "saving an empty graph is refused")
  ok(H.chat_contains("Nothing to save"), "refusal explains there is nothing to save")
  ok(SS.count() == 0, "no session stored for an empty graph")

  Vermilion.Graph.on_record_click()
  H.damage_out({ hit = 1200 })
  H.advance(1000)
  H.damage_out({ hit = 1800 })
  H.advance(1000)
  ok(btn._enabled == false, "save is disabled while recording")
  H.chat = {}
  ok(Vermilion.Graph.on_save_click() == false, "saving while recording is refused")
  ok(H.chat_contains("Stop the recording"), "refusal explains to stop first")
  ok(SS.count() == 0, "no session stored while recording")

  Vermilion.Graph.on_stop_click()
  H.advance(400)
  ok(SS.count() == 0, "with autosave off, stopping stores nothing")
  ok(btn._enabled == true, "a stopped recording can be saved")
  ok(status._text and status._text:find("NOT SAVED", 1, true), "the status line reminds that the recording is not saved, got " .. tostring(status._text))
  ok(H.update_registered("VermilionSavePulse"), "the save icon pulses to invite the save")
  H.advance(800)
  ok(not H.update_registered("VermilionSavePulse"), "the pulse ends on its own")
  ok((btn._alpha or 1) == 1, "the save icon comes back to full alpha")

  H.chat = {}
  ok(Vermilion.Graph.on_save_click() == true, "manual save accepted")
  ok(status._text and status._text:find("SAVING", 1, true), "while the capture runs the status reads SAVING, got " .. tostring(status._text))
  ok(H.update_registered("VermilionSavingSpin"), "a spinner ticks while saving")
  ok((btn._alpha or 1) < 1, "the save icon dims while saving")
  H.advance(400)
  ok(not H.update_registered("VermilionSavingSpin"), "the spinner stops when the save lands")
  ok((btn._alpha or 1) == 1, "the save icon comes back")
  ok(SS.count() == 1, "manual save stores exactly one session")
  ok(SS.get(1).head.manual == true, "a manual save is marked as such")
  ok(SS.get(1).head.zone == "Fungal Grotto", "the stored session carries the zone")
  ok(H.chat_contains("saved to the library"), "the chat line confirms the save")
  ok(status._text and status._text:find("SAVED", 1, true) and status._text:find("Fungal Grotto", 1, true),
     "the status line reads SAVED with the zone, got " .. tostring(status._text))
  ok(btn._enabled == false, "the icon goes grey once the recording is saved")

  H.chat = {}
  ok(Vermilion.Graph.on_save_click() == false, "a second press does not save twice")
  ok(H.chat_contains("already in the library"), "the second press explains the recording is already saved")
  ok(SS.count() == 1, "still one session")

  Vermilion.Graph.on_record_click()
  H.damage_out({ hit = 900 })
  H.advance(1000)
  Vermilion.Graph.on_stop_click()
  H.advance(400)
  ok(btn._enabled == true, "a new recording can be saved again")

  Vermilion.Graph.on_flush_click()
  ok(btn._enabled == false, "flushing disables the save icon")
  ok(status._text == "", "flushing clears the status")

  sv.settings.session_autosave = true
  Vermilion.Graph.on_record_click()
  H.damage_out({ hit = 1500 })
  H.advance(1000)
  Vermilion.Graph.on_stop_click()
  ok(status._text and status._text:find("SAVING", 1, true), "an autosave shows SAVING too, got " .. tostring(status._text))
  H.advance(400)
  ok(SS.count() == 2, "autosave stores the recording")
  ok(not H.update_registered("VermilionSavingSpin") and status._text:find("SAVED", 1, true) and not status._text:find("SAVING", 1, true),
     "after an autosave the spinner is gone and the status reads SAVED, got " .. tostring(status._text))
  ok(SS.get(2).head.manual == nil, "an autosaved session is not marked manual")
  ok(btn._enabled == false, "after autosave the icon is already grey")
  ok(Vermilion.Graph.on_save_click() == false, "pressing save after autosave never duplicates")
  ok(SS.count() == 2, "still two sessions")

  Vermilion.Graph.on_record_click()
  H.damage_out({ hit = 700 })
  H.advance(1000)
  Vermilion.Graph.toggle_record()
  ok(not Vermilion.TemporalBuffer.is_recording(), "the record keybind stops a running recording")
  H.advance(400)
  ok(SS.count() == 3, "three sessions")
  Vermilion.Graph.toggle_record()
  ok(Vermilion.TemporalBuffer.is_recording(), "the record keybind starts a recording")
  Vermilion.Graph.on_stop_click()
  H.advance(400)

  Vermilion.Graph.on_flush_click()
  sv.library, sv.settings.session_autosave = before_lib, before_auto
  SS.init()
  H.state.zone = nil
  Vermilion.Metrics.reset()
end
