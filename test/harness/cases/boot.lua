return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local C = Vermilion.Constants

  ok(type(SLASH_COMMANDS["/vermilion"]) == "function", "the slash command must be registered")
  ok(Vermilion.SavedVars ~= nil, "savedvars must open at load")
  for _, key in ipairs({ "probe", "graph", "temporal", "copybox", "settings", "skill_overrides", "logo" }) do
    ok(type(Vermilion.SavedVars[key]) == "table", "savedvars default section missing: " .. key)
  end

  ok(rawget(_G, "VermilionGraphWindow") ~= nil, "the graph window must exist")
  ok(rawget(_G, "VermilionSettingsPanel") ~= nil, "the settings panel must exist")
  ok(rawget(_G, "VermilionLogo") ~= nil, "the logo must exist")
  ok(VermilionGraphWindowRecordBtn and VermilionGraphWindowStopBtn and VermilionGraphWindowFlushBtn, "the record buttons must exist")

  local manifest = assert(io.open(HARNESS_ROOT .. "/Vermilion.txt")):read("*a")
  local mv = manifest:match("## Version:%s*([%d%.]+)")
  ok(mv == C.VERSION, "manifest Version and constants VERSION must match: " .. tostring(mv) .. " vs " .. tostring(C.VERSION))
  ok(manifest:find("## APIVersion: 101051 101050", 1, true), "APIVersion must list the PTS and the live patch")

  ok(C.DEBUG == HARNESS_DEBUG, "the harness drives the debug flag: " .. tostring(C.DEBUG))
  ok(Vermilion.TemporalBuffer.capacity() > 0, "the temporal buffer must be sized at load")
  ok(not Vermilion.TemporalBuffer.is_recording(), "nothing records at load")
  ok(H.chat_contains("Vermilion"), "the load line greets in chat")
end
