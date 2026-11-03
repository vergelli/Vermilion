return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local TB = Vermilion.TemporalBuffer
  Vermilion.Visibility.set("graph", true)
  local keep = TB.capacity()
  local tick = 0
  local out = Vermilion.FilmTest.run({ 1 }, function() tick = tick + 1; return tick end)
  ok(out:find("^minutes samples") ~= nil, "the report has a header")
  ok(out:find(string.char(10) .. "1 60 ", 1, true) ~= nil, "one minute is sixty samples, got " .. out)
  ok(TB.capacity() == keep and TB.count() == 0, "the buffer returns to its capacity, empty")
  ok(not TB.is_recording(), "the test leaves nothing recording")
end
