return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local SS, G, L = Vermilion.SessionStore, Vermilion.Graph, Vermilion.Library
  local sv = Vermilion.SavedVars

  sv.settings = sv.settings or {}
  local before_lib, before_auto = sv.library, sv.settings.session_autosave
  sv.library = { version = 1, sessions = {} }
  sv.settings.session_autosave = true
  SS.init()
  Vermilion.Metrics.reset()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  H.advance(31000)

  G.on_record_click()
  for i = 1, 24 do
    H.damage_out({ hit = (i <= 12) and 400 or 2400, ability_id = 31 })
    H.advance(1000)
  end
  G.on_stop_click()
  H.advance(400)
  ok(SS.count() == 1, "the session autosaved")
  local sp = SS.get(1).head.spark
  ok(type(sp) == "table" and #sp == 24, "the session head carries a 24-cell spark")
  ok(sp[24] == 255, "the strongest bin is the peak, got " .. tostring(sp[24]))
  ok(sp[3] > 0 and sp[3] < sp[20], "a weaker bin sits below a stronger one, got " .. tostring(sp[3]) .. " vs " .. tostring(sp[20]))

  local Heat = Vermilion.Heat
  ok(Heat and Heat.N == 128 and Heat.lut(0)[3] > 0.45 and Heat.lut(127)[1] > 0.9, "the heat ramp is shared from core/heat.lua")
  ok(Heat.alpha(0) < 0.4 and Heat.alpha(127) == 1, "low levels fade in, high levels are solid")

  sv.library.sessions[#sv.library.sessions + 1] = {
    v = 1, head = { ts = 1, zone = "Old Fight", dur_ms = 10000, group_size = 0, build = "1.0.1", api = 101051, locked = false, sum = { avg = 100, peak = 200, crit_pct = 0.1 } },
    gkeys = {}, debuffs = {}, desc = SS.DESC, streams = {},
  }
  L.show()
  local lit, hidden = 0, 0
  for b = 1, 24 do
    local c = rawget(_G, "VermilionLibraryRow2Spark" .. b)
    if c and c._hidden == false then lit = lit + 1 else hidden = hidden + 1 end
  end
  ok(lit == 24, "the recorded session lights its whole strip, got " .. lit)
  local c1, c24 = VermilionLibraryRow2Spark1, VermilionLibraryRow2Spark24
  ok((c24._r or 0) > (c1._r or 0) and (c1._b or 0) > (c24._b or 0), "the strip runs from cool to hot with the output")
  ok((c1._a or 1) < (c24._a or 1), "weak cells are fainter than strong ones")
  local old_lit = 0
  for b = 1, 24 do
    local c = rawget(_G, "VermilionLibraryRow1Spark" .. b)
    if c and c._hidden == false then old_lit = old_lit + 1 end
  end
  ok(old_lit == 0, "a session saved before the strip existed shows none, got " .. old_lit)
  L.hide()

  sv.library, sv.settings.session_autosave = before_lib, before_auto
  SS.init()
  G.on_flush_click()
  Vermilion.Visibility.set("graph", false)
  Vermilion.Metrics.reset()
end
