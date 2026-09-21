return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local DT = Vermilion.DevTools
  local EL = Vermilion.EncounterLog
  local slash = SLASH_COMMANDS["/vermilion"]

  ok(type(Vermilion.slash) == "function", "the slash handler is exposed for the panel to reuse")
  ok(EL.available(), "the encounter log wrappers are detected on this client")
  ok(EL.status_line():find("Encounter.log", 1, true), "the status line names the engine file")

  if not Vermilion.Constants.DEBUG then
    ok(rawget(_G, "VermilionDevPanel") == nil, "a release build never builds the developer panel")
    DT.toggle()
    ok(rawget(_G, "VermilionDevPanel") == nil and not DT.is_open(), "the release stub ignores toggle")
    ok(#DT.actions == 0, "the release stub carries no actions")
    Vermilion.Visibility.set("graph", true)
    Vermilion.Settings.toggle()
    ok(VermilionSettingsPanelDevBtn._hidden == true, "the DEV button stays hidden in release")
    Vermilion.Settings.toggle()
    H.state.elog = false
    slash("elog")
    ok(H.state.elog == false, "elog is a debug command; release ignores it")
    ok(Vermilion.Trace.mark("x"):find("disabled"), "the trace stub answers mark with disabled")
    return
  end

  Vermilion.Visibility.set("graph", true)
  Vermilion.Settings.toggle()
  ok(VermilionSettingsPanelDevBtn._hidden == false, "the DEV button shows in a debug build")
  ok((VermilionSettingsPanelDevBtn._text or "") == "DEV", "the DEV button is labelled")
  Vermilion.Settings.toggle()

  ok(not DT.is_open(), "the panel starts closed")
  DT.toggle()
  ok(DT.is_open() and not VermilionDevPanel:IsHidden(), "toggle opens the panel")
  local r = H.layout(VermilionDevPanel)
  ok(r.w >= 600 and r.h >= 380, string.format("the panel has room for two columns, got %dx%d", r.w, r.h))

  local n_actions, n_sections = 0, 0
  local seen = {}
  for _, e in ipairs(DT.actions) do
    if e.section then n_sections = n_sections + 1
    else
      n_actions = n_actions + 1
      ok(type(e.label) == "string" and #e.label > 0, "every action has a label")
      ok(type(e.cmd) == "string" and #e.cmd > 0, "every action has a command")
      ok(not seen[e.cmd], "duplicate command in the panel: " .. e.cmd)
      seen[e.cmd] = true
    end
  end
  ok(n_sections >= 4, "the actions are grouped in sections")
  ok(n_actions >= 25, "the panel wraps the debug commands, got " .. n_actions)
  ok(#DT.rows() == n_actions, "one row per action, got " .. #DT.rows())

  local hints = {}
  for _, row in ipairs(DT.rows()) do
    ok(type(row.name._text) == "string" and row.name._text == row.action.label, "the row shows the action label")
    hints[row.action.cmd] = row.hint._text
  end
  ok(hints["trace start"] == "trace start", "a plain row shows the command it runs")
  ok(hints["elog"] == "OFF", "the encounter log row shows the engine state, got " .. tostring(hints["elog"]))

  H.clear_chat()
  local seen_error
  for _, row in ipairs(DT.rows()) do
    if row.action.cmd ~= "flush" then
      local ok_run, err = pcall(row.control._onOnMouseUp, row.control, 1, true)
      if not ok_run then seen_error = row.action.cmd .. ": " .. tostring(err) end
    end
  end
  ok(seen_error == nil, "every row runs without error, first failure " .. tostring(seen_error))
  ok(Vermilion.EncounterLog.is_enabled() == true, "clicking the encounter log row switched the engine log on")
  for _, row in ipairs(DT.rows()) do
    if row.action.cmd == "elog" then ok(row.hint._text == "ON", "the row refreshes to ON after the click") end
  end
  ok(H.chat_contains("encounter log ON"), "the toggle reports the new state in chat")

  slash("elog off")
  ok(not EL.is_enabled(), "elog off switches it off")
  slash("elog status")
  ok(not EL.is_enabled() and H.chat_contains("encounter log OFF"), "status reports without toggling")
  slash("elog on")
  ok(EL.is_enabled(), "elog on switches it on")
  slash("elog")
  ok(not EL.is_enabled(), "bare elog toggles")

  local sv = {}
  local T = Vermilion.Trace
  T.clear(sv)
  T.start()
  slash("mark boss pull")
  H.damage_out({ hit = 500 })
  T.stop()
  T.save(sv)
  local codec = dofile(HARNESS_ROOT .. "/test/simlab/tracecodec.lua")
  local events = codec.decode_chunks(sv.trace.chunks)
  ok(events[1].tag == "EP" and events[1].args[1] == GetTimeStamp(), "a trace opens with the wall-clock epoch")
  local mk
  for _, e in ipairs(events) do if e.tag == "MK" then mk = e end end
  ok(mk and mk.args[1] == "boss pull" and mk.args[2] == GetTimeStamp(), "mark writes a labelled MK line with the epoch")
  ok(H.chat_contains("mark 'boss pull' epoch=" .. GetTimeStamp()), "mark echoes the pair to chat")
  T.clear(sv)

  DT.toggle()
  ok(not DT.is_open() and VermilionDevPanel:IsHidden(), "toggle closes the panel")

  Vermilion.Probe.set_enabled(false)
  Vermilion.Graph.set_pixel_grid(true)
  Vermilion.Metrics.reset()
end
