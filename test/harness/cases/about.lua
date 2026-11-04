return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local A, R, TB = Vermilion.About, Vermilion.StorageReport, Vermilion.TemporalBuffer
  local sv = Vermilion.SavedVars

  ok(R.size_of("abc", 0) == 5, "a string counts its quotes")
  ok(R.size_of(12, 0) == 2, "a number counts its digits")
  ok(R.size_of({ a = 1 }, 0) == 8 + 4 + 5 + 3 + 1 + 4, "a table counts its entry and layout")
  ok(R.format_bytes(512) == "512 B", "bytes")
  ok(R.format_bytes(2048) == "2 KB", "kilobytes")
  ok(R.format_bytes(1572864) == "1.5 MB", "megabytes")

  local keep_lib, keep_probe = sv.library, sv.probe
  sv.library = { version = 1, sessions = { { head = {}, streams = { x = { data = { string.rep("a", 4000) } } } } } }
  sv.probe = { log = string.rep("b", 1000) }
  local r = R.report()
  ok(r.sessions > 4000 and r.sessions < 5000, "sessions count their packed data, got " .. r.sessions)
  ok(r.diagnostics > 1000 and r.diagnostics < 1200, "diagnostics count the probe, got " .. r.diagnostics)
  ok(r.total == r.sessions + r.diagnostics + r.preferences, "the total adds the three")
  ok(r.film >= TB.capacity() * 1990, "the film counts its empty slots")
  ok(r.heap > 0, "the heap is read")

  Vermilion.Visibility.set("graph", true)
  ok(VermilionAbout._hidden == true, "About starts closed")
  A.toggle()
  ok(VermilionAbout._hidden == false, "About opens")
  ok(VermilionAboutName._text:find(Vermilion.Constants.VERSION, 1, true), "it names the version")
  ok(VermilionAboutAuthor._text:find("Federico Vergelli", 1, true), "it names the author")
  ok(VermilionAboutCredit1._text ~= nil and VermilionAboutCredit1._text ~= "", "it lists the credits")
  ok(VermilionAboutSessionsValue._text:find("/24", 1, true), "it shows the library use, got " .. tostring(VermilionAboutSessionsValue._text))
  ok(VermilionAboutSessionsFill._hidden == false, "a used section draws its bar")
  ok(VermilionAboutDiagnosticsFill._w > 0, "diagnostics draw too")
  local panel = H.layout(VermilionAbout)
  for _, c in ipairs({ VermilionAboutName, VermilionAboutSessionsGroove, VermilionAboutFilmGroove }) do
    local rect = H.layout(c)
    ok(rect.x + rect.w <= panel.x + panel.w, (c._name or "?") .. " stays inside the window")
    ok(rect.y + rect.h <= panel.y + panel.h, (c._name or "?") .. " stays above the bottom edge")
  end
  A.toggle()
  ok(VermilionAbout._hidden == true, "About closes")

  sv.library, sv.probe = keep_lib, keep_probe
  Vermilion.Visibility.set("graph", false)
end
