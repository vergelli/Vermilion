return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local slash = SLASH_COMMANDS["/vermilion"]
  local shown = Vermilion.Visibility.get("graph")

  if Vermilion.Constants.DEBUG then
    H.chat = {}
    slash("stats")
    ok(#H.chat > 0, "with the debug keys on, /vermilion stats prints")
    slash("clear")
    ok(H.chat_contains("cleared") or #H.chat > 1, "with the debug keys on, /vermilion clear confirms")
  else
    H.chat = {}
    for _, cmd in ipairs({ "stats", "dump", "report", "gcprobe 10", "prof", "validate", "skills", "tag 1 templar", "clear" }) do
      slash(cmd)
      ok(#H.chat == 0, "in a release build the dev command '" .. cmd .. "' prints nothing")
      Vermilion.Visibility.set("graph", shown)
    end
    ok(Vermilion.Probe == nil or Vermilion.Probe.is_enabled == nil or not Vermilion.Probe.is_enabled(), "no probe runs in a release build")
  end

  H.chat = {}
  slash("help")
  ok(#H.chat >= 2, "/vermilion help always prints the help lines")
  Vermilion.Visibility.set("graph", shown)
end
