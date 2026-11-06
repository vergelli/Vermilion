return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local C = Vermilion.Constants

  local text = assert(io.open(HARNESS_ROOT .. "/core/constants.lua")):read("*a")
  ok(text:find('DEV%s*=%s*false'), "the repository keeps DEV off")
  ok(text:find('MODE%s*=%s*""'), "the repository keeps MODE empty")
  ok(text:find('DEBUG%s*=%s*false'), "the repository keeps DEBUG off")

  if HARNESS_DEBUG then
    ok(C.DEBUG == true, "the debug run has the tools")
    ok(Vermilion.Probe.init ~= nil, "the probe is there")
    return
  end

  ok(C.DEBUG == false, "the release run has no tools")
  ok(Vermilion.Probe.init == nil, "the probe does not load")
  ok(Vermilion.EncounterLog.status_line == nil and Vermilion.EncounterLog.toggle == nil, "the log switch does not load")
  ok(Vermilion.Trace.is_recording == nil or Vermilion.Trace.is_recording() ~= true, "no trace runs")
  ok(rawget(_G, "VermilionAboutDiagnostics") == nil and rawget(_G, "VermilionAboutDiagnosticsFill") == nil, "About has no diagnostics bar")

  local seen = false
  local real = Vermilion.CopyBox.show
  Vermilion.CopyBox.show = function() seen = true end
  for _, cmd in ipairs({ "castprobe", "dump", "suspects", "report", "copy", "dev", "elog", "probe" }) do
    Vermilion.Graph.toggle()
    Vermilion.slash(cmd)
    ok(not seen, cmd .. " does nothing in a release")
  end
  Vermilion.CopyBox.show = real
  Vermilion.Visibility.set("graph", false)

  local sv = Vermilion.SavedVars
  local keep = sv.probe
  sv.probe = { log = string.rep("b", 1000) }
  ok(Vermilion.StorageReport.report().diagnostics == 0, "leftovers from a debug build are not reported")
  sv.probe = keep
end
