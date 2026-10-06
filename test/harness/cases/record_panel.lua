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

  local btn, caret, tag, panel = VermilionGraphWindowRecordBtn, VermilionGraphWindowRecordMenuBtn, VermilionGraphWindowRecModeLabel, VermilionGraphWindowRecPanel
  ok(btn and caret and tag and panel, "the record button has a main half, an arrow and a panel")
  ok(caret._text:find("large_downArrow_up.dds", 1, true), "the arrow is the game's own down arrow texture, got " .. tostring(caret._text))
  ok(not btn._text:find("Armed", 1, true) and btn._text:find("Record", 1, true), "the main half reads Record, never Armed")
  ok(panel:IsHidden(), "the panel starts closed")

  G.on_record_menu_click()
  ok(not panel:IsHidden(), "the arrow opens the panel")
  local rows = {}
  for _, c in ipairs(H.controls) do
    if c._parent and c._parent._parent == panel and c._tex and c._tex:find("RadioButton", 1, true) then rows[#rows + 1] = c end
  end
  ok(#rows == 7, "seven radio dots: three starts, two stops, two saves, got " .. #rows)
  local function dots(frag) local n = 0 for _, d in ipairs(rows) do if d._tex:find(frag, 1, true) then n = n + 1 end end return n end
  ok(dots("RadioButtonDown.dds") == 3 and dots("RadioButtonUp.dds") >= 2, "one choice is lit per row, by hand everywhere, got " .. dots("RadioButtonDown.dds") .. " lit")
  local summary
  for _, c in ipairs(H.controls) do
    if c._parent == panel and type(c._text) == "string" and c._text:find("Starts ", 1, true) then summary = c end
  end
  ok(summary and summary._text == "Starts when you press Record, stops when you press Stop, saves only when you press Save.", "the sentence reads the manual combination back, got " .. tostring(summary and summary._text))

  local function click(label_text)
    for _, c in ipairs(H.controls) do
      if c._parent and c._parent._parent == panel and c._text == label_text then
        local hit = c._parent
        hit._onOnMouseUp(hit, 1, true)
        return true
      end
    end
    return false
  end
  ok(click("Any fight"), "the Any fight radio is clickable")
  ok(AR.get_mode() == "combat" and sv.settings.auto_record == "combat", "choosing a start writes the pref")
  ok(summary._text:find("with any fight", 1, true) and summary._text:find("a few seconds after the fight ends", 1, true), "an automatic start implies stopping with the fight, got " .. tostring(summary._text))
  ok(dots("RadioButtonDisabled") == 2, "the stop row is greyed while the start is automatic, got " .. dots("RadioButtonDisabled"))
  ok(btn._text:find("Record", 1, true) and not btn._text:find("Armed", 1, true), "the main half still reads Record")
  ok(tag._text:find("any fight", 1, true) and tag._text:find("stops with the fight", 1, true), "the tag names the mode and the implied stop, got " .. tostring(tag._text))

  ok(click("By hand"), "back to a manual start")
  ok(AR.get_mode() == "off" and dots("RadioButtonDisabled") == 0, "the stop row comes back")
  ok(click("When the fight ends"), "the stop radio is clickable")
  ok(AR.get_auto_stop() == true and sv.settings.auto_stop == true, "choosing the stop writes the pref")
  ok(click("When it stops"), "the save radio is clickable")
  ok(sv.settings.session_autosave == true, "choosing the save writes the pref")
  ok(summary._text == "Starts when you press Record, stops a few seconds after the fight ends, saves itself into the library.", "the sentence follows every choice, got " .. tostring(summary._text))

  G.on_record_menu_click()
  ok(panel:IsHidden(), "the arrow closes the panel")
  G.on_record_menu_click()
  G.on_close_click()
  ok(panel:IsHidden(), "closing the window closes the panel")
  Vermilion.Visibility.set("graph", true)

  G.on_record_main_click()
  ok(TB.is_recording() and btn._text:find("Recording", 1, true), "the main half starts a recording and says so")
  ok(H.update_registered("VermilionRecPulse"), "the dot pulses while recording")
  G.on_record_main_click()
  ok(not TB.is_recording(), "the main half stops it")
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
