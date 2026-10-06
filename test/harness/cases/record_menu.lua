return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G, AR, TB = Vermilion.Graph, Vermilion.AutoRecord, Vermilion.TemporalBuffer
  local sv = Vermilion.SavedVars
  local before_mode, before_stop, before_save = AR.get_mode(), sv.settings.auto_stop, sv.settings.session_autosave

  Vermilion.Metrics.reset()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  AR.set_mode("off")
  AR.set_auto_stop(false)
  sv.settings.session_autosave = false
  G.refresh_record_button()

  local btn, caret, tag = VermilionGraphWindowRecordBtn, VermilionGraphWindowRecordMenuBtn, VermilionGraphWindowRecModeLabel
  ok(btn and caret and tag, "the record button has a main half, a caret and a mode tag")
  local xml = io.open(HARNESS_ROOT .. "/ui/graph.xml"):read("*a")
  local rx, ry, rw, rh = xml:match('name="%$%(parent%)RecordBtn".-offsetX="(%d+)" offsetY="(%d+)"/>%s*<Dimensions x="(%d+)" y="(%d+)"')
  local cx, cy, cw, ch = xml:match('name="%$%(parent%)RecordMenuBtn".-offsetX="(%d+)" offsetY="(%d+)"/>%s*<Dimensions x="(%d+)" y="(%d+)"')
  ok(rx and cx and tonumber(cx) == tonumber(rx) + tonumber(rw) and cy == ry and ch == rh, "the caret sits flush against the main half in the window layout")
  ok(btn._text:find("Record", 1, true) and not btn._text:find("Armed", 1, true), "manual mode reads Record, got " .. tostring(btn._text))
  ok(tag._text == "manual", "the tag names the mode, got " .. tostring(tag._text))

  H.menu = nil
  G.on_record_menu_click()
  local m = H.menu
  ok(m and m.shown, "the caret opens the native menu")
  local function item(frag)
    for _, it in ipairs(m.items) do if it.text:find(frag, 1, true) then return it end end
  end
  ok(item("Record now") and item("AUTOMATIC") and item("Boss fights") and item("Any fight") and item("Manual only"), "the menu lists the record action and the three modes")
  ok(item("WHEN A RECORDING STOPS") and item("Stop when the fight ends") and item("Save the session on stop") and item("What do the modes do"), "the menu lists the two stop options and the help entry")
  ok(item("Manual only").text:sub(1, #"●") == "●" and item("Boss fights").text:sub(1, #"○") == "○", "the current mode carries the filled mark")
  ok(item("AUTOMATIC").itype == MENU_ADD_OPTION_LABEL and item("AUTOMATIC").fn == nil, "headers are labels, not actions")

  item("Boss fights").fn()
  ok(AR.get_mode() == "boss" and sv.settings.auto_record == "boss", "choosing a mode writes the pref")
  ok(btn._text:find("Armed", 1, true), "an automatic mode outside a fight reads Armed, got " .. tostring(btn._text))
  ok(tag._text:find("boss", 1, true), "the tag follows the mode, got " .. tostring(tag._text))

  G.on_record_menu_click()
  m = H.menu
  ok(item("Boss fights").text:sub(1, #"●") == "●", "reopening shows the new mode marked")
  item("Stop when the fight ends").fn()
  ok(AR.get_auto_stop() == true and sv.settings.auto_stop == true, "the stop check toggles its pref")
  ok(tag._text:find("stops with the fight", 1, true), "the tag mentions the stop option")
  G.on_record_menu_click()
  m = H.menu
  ok(item("Stop when the fight ends").text:sub(1, #"☑") == "☑", "the stop check shows checked")
  item("Save the session on stop").fn()
  ok(sv.settings.session_autosave == true, "the save check toggles its pref")
  ok(tag._text:find("saves", 1, true), "the tag mentions the save option")

  item("Manual only").fn()
  ok(AR.get_mode() == "off" and btn._text:find("Record", 1, true) and not btn._text:find("Armed", 1, true), "back to manual reads Record")

  G.on_record_main_click()
  ok(TB.is_recording(), "the main half starts a recording")
  ok(btn._text:find("Recording", 1, true), "while recording the main half reads Recording, got " .. tostring(btn._text))
  ok(H.update_registered("VermilionRecPulse"), "the dot pulses while recording")
  G.on_record_menu_click()
  m = H.menu
  ok(item("Stop recording") and not item("Record now"), "while recording the first entry stops")
  G.on_record_main_click()
  ok(not TB.is_recording(), "the main half stops the recording")
  H.advance(100)
  ok(not H.update_registered("VermilionRecPulse"), "the pulse stops with the recording")
  G.on_flush_click()

  ok(rawget(_G, "VermilionSettingsPanelAutoRecBtn") == nil and rawget(_G, "VermilionSettingsPanelAutosaveBtn") == nil and rawget(_G, "VermilionSettingsPanelAutoStopBtn") == nil, "the settings panel no longer carries the three recording buttons")
  local note = VermilionSettingsPanelRecordingNote
  ok(note and type(note._text) == "string" and note._text:find("record button", 1, true), "the settings panel points to the record button")

  AR.set_mode(before_mode)
  AR.set_auto_stop(before_stop == true)
  sv.settings.session_autosave = before_save
  G.refresh_record_button()
end
