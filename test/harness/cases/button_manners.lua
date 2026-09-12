return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end

  local BUTTONS = {
    "VermilionGraphWindowRecordBtn", "VermilionGraphWindowStopBtn", "VermilionGraphWindowFlushBtn",
    "VermilionGraphWindowLibBtn", "VermilionGraphWindowSaveBtn",
    "VermilionGraphWindowPrevViewBtn", "VermilionGraphWindowNextViewBtn",
    "VermilionGraphWindowSettingsBtn", "VermilionGraphWindowCloseBtn",
    "VermilionLibraryOpenBtn", "VermilionLibraryLockBtn", "VermilionLibraryDeleteBtn", "VermilionLibraryCloseBtn",
    "VermilionSettingsPanelAutoRecBtn", "VermilionSettingsPanelAutosaveBtn", "VermilionSettingsPanelAutoStopBtn",
    "VermilionSettingsPanelSoundsBtn", "VermilionSettingsPanelUnknownBtn", "VermilionSettingsPanelLogoBtn",
    "VermilionSettingsPanelResetBtn", "VermilionSettingsPanelCloseBtn",
    "VermilionSettingsPanelPSaveBtn", "VermilionSettingsPanelPDeleteBtn", "VermilionSettingsPanelLightBtn", "VermilionSettingsPanelKillsBtn",
  }
  for _, name in ipairs(BUTTONS) do
    local c = rawget(_G, name)
    ok(c ~= nil, name .. " must exist after init")
    ok(type(c._onOnMouseEnter) == "function", name .. " must explain itself on hover")
    ok(type(c._onOnMouseExit) == "function", name .. " must hide its tooltip on exit")
    H.last_tooltip = nil
    c._onOnMouseEnter(c)
    ok(type(H.last_tooltip) == "string" and #H.last_tooltip > 3, name .. " tooltip must carry text")
    c._onOnMouseExit(c)
  end

  local function last_sound() return H.sounds and H.sounds[#H.sounds] or nil end
  local function clear() H.sounds = {} end
  local S = Vermilion.Sound

  for _, cue in ipairs(S.cues()) do
    ok(type(S.name(cue)) == "string" and #S.name(cue) > 0, "cue " .. cue .. " maps to a game sound")
  end

  Vermilion.Metrics.reset()
  Vermilion.Visibility.set("graph", false)
  clear()
  Vermilion.Graph.toggle()
  ok(last_sound() == ("sound:" .. S.name("open")), "opening the graph opens a book")
  clear()
  Vermilion.Graph.on_record_click()
  ok(last_sound() == ("sound:" .. S.name("record")), "record confirms with its own cue")
  H.damage_out({ hit = 1000 })
  H.advance(1000)
  clear()
  Vermilion.Graph.on_stop_click()
  ok(last_sound() == ("sound:" .. S.name("stop")), "stop confirms with its own cue")
  clear()
  Vermilion.Graph.next_view()
  ok(last_sound() == ("sound:" .. S.name("page")), "changing the view turns a page")
  clear()
  Vermilion.Graph.on_flush_click()
  ok(last_sound() == ("sound:" .. S.name("discard")), "flush sounds like a decline")
  clear()
  Vermilion.Graph.on_close_click()
  ok(last_sound() == ("sound:" .. S.name("close")), "closing the graph closes the book")

  clear()
  Vermilion.Settings.toggle()
  ok(last_sound() == ("sound:" .. S.name("open")), "settings opens like a book")
  clear()
  Vermilion.Settings.toggle()
  ok(last_sound() == ("sound:" .. S.name("close")), "settings closes like a book")

  clear()
  Vermilion.Library.toggle()
  ok(last_sound() == ("sound:" .. S.name("open")), "the library opens like a book")
  clear()
  Vermilion.Library.toggle()
  ok(last_sound() == ("sound:" .. S.name("close")), "the library closes like a book")
  clear()
  Vermilion.Library.hide()
  ok(last_sound() == nil, "hiding an already hidden library stays silent")

  clear()
  Vermilion.Assign.show()
  ok(last_sound() == ("sound:" .. S.name("open")), "the assignment window opens like a book")
  clear()
  Vermilion.Assign.hide()
  ok(last_sound() == ("sound:" .. S.name("close")), "and closes like one")

  Vermilion.Settings.on_sounds_click()
  ok(Vermilion.SavedVars.settings.sounds == false, "the toggle turns sounds off")
  ok(VermilionSettingsPanelSoundsBtn._text == "Sounds: Off", "the button says so")
  clear()
  Vermilion.Graph.next_view()
  ok(last_sound() == nil, "with sounds off, Vermilion's own sounds stay silent")
  Vermilion.Settings.on_sounds_click()
  ok(Vermilion.SavedVars.settings.sounds == true, "the toggle turns sounds back on")
  ok(last_sound() == ("sound:" .. S.name("confirm")), "turning sounds on confirms audibly")
  clear()
  Vermilion.Graph.next_view()
  ok(last_sound() == ("sound:" .. S.name("page")), "sounds are back")

  clear()
  Vermilion.Settings.on_reset_click()
  ok(Vermilion.SavedVars.settings.sounds == nil, "reset puts sounds back to the default")

  Vermilion.Metrics.reset()
end
