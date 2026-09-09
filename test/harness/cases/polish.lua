return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G = Vermilion.Graph
  local sv = Vermilion.SavedVars
  sv.settings = sv.settings or {}
  local before_auto = sv.settings.session_autosave
  sv.settings.session_autosave = false

  Vermilion.Metrics.reset()
  G.on_flush_click()
  Vermilion.Visibility.set("graph", false)
  ok(VermilionGraphWindow._hidden == true, "graph starts hidden for the fade test")
  Vermilion.Visibility.set("graph", true)
  ok(VermilionGraphWindow._hidden == false, "the graph shows")
  ok((VermilionGraphWindow._alpha or 1) == 1, "the fade lands on full alpha")
  Vermilion.Visibility.set("graph", false)
  Vermilion.Visibility.set("graph", true)
  ok((VermilionGraphWindow._alpha or 1) == 1, "a second open fades in again and lands on full alpha")

  ok(not Vermilion.Logo.is_beating(), "the logo rests while nothing records")
  G.on_record_click()
  H.damage_out({ hit = 800 })
  H.advance(1000)
  Vermilion.Visibility.set("graph", false)
  ok(Vermilion.Logo.is_beating(), "the logo breathes while a recording runs and the graph is closed")
  Vermilion.Logo.on_enter()
  ok(not Vermilion.Logo.is_beating(), "hovering the logo pauses the heartbeat")
  Vermilion.Logo.on_exit()
  ok(Vermilion.Logo.is_beating(), "leaving the logo resumes the heartbeat")
  Vermilion.Visibility.set("graph", true)
  G.on_stop_click()
  ok(not Vermilion.Logo.is_beating(), "Stop ends the heartbeat")
  local status = VermilionGraphWindowStatusLabel
  ok(status._text and status._text:find("NOT SAVED", 1, true), "status reads NOT SAVED")
  ok(status._r and status._r > 0.9 and status._b and status._b < 0.5, "NOT SAVED is amber")
  G.on_save_click()
  H.advance(400)
  ok(status._r and status._r < 0.7, "SAVED goes back to the quiet grey")

  G.on_flush_click()
  G.on_record_click()
  ok(status._r and status._r < 0.7, "a new recording resets the status colour")
  G.on_stop_click()

  ok(GetString(VERMILION_GRAPH_NO_DATA):find("rec.dds", 1, true), "the graph's empty state shows the Record glyph")
  ok(GetString(VERMILION_LIB_EMPTY):find("edit_save_up", 1, true), "the library's empty state shows the Save glyph")
  ok((VermilionGraphWindowRecordBtn._text or ""):find("rec.dds", 1, true), "the Record button wears its glyph")
  ok((VermilionGraphWindowStopBtn._text or ""):find("stop.dds", 1, true), "the Stop button wears its glyph")
  ok(VermilionGraphWindowReadoutLabel._text == "idle", "with nothing recording the header reads idle, got " .. tostring(VermilionGraphWindowReadoutLabel._text))
  G.on_record_click()
  H.advance(1000)
  ok(VermilionGraphWindowReadoutLabel._text ~= "idle", "while recording the header shows the number, got " .. tostring(VermilionGraphWindowReadoutLabel._text))
  G.on_stop_click()
  G.on_flush_click()
  ok(VermilionGraphWindowReadoutLabel._text == "idle", "after New the header is idle again")

  G.on_flush_click()
  Vermilion.Visibility.set("graph", false)
  sv.settings.session_autosave = before_auto
  Vermilion.Metrics.reset()
end
