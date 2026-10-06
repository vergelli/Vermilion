return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G, R, TB, SS = Vermilion.Graph, Vermilion.Resources, Vermilion.TemporalBuffer, Vermilion.SessionStore
  local sv = Vermilion.SavedVars
  sv.settings = sv.settings or {}
  local before_auto = sv.settings.session_autosave

  Vermilion.Metrics.reset()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  local view_label = VermilionGraphWindowViewLabel
  while view_label._text ~= "SKILL" do G.next_view() end
  H.state.power = { [POWERTYPE_MAGICKA] = { value = 30000, max = 30000 }, [POWERTYPE_STAMINA] = { value = 20000, max = 20000 } }

  sv.settings.session_autosave = true
  sv.library = { version = 1, sessions = {} }
  G.on_record_click()
  ok(R.is_recording(), "the resource tracker follows the recording")
  local mag, sta = 30000, 20000
  for i = 1, 9 do
    mag = mag - 4000; H.res_power(POWERTYPE_MAGICKA, mag, 30000)
    mag = mag + 1000; H.res_power(POWERTYPE_MAGICKA, mag, 30000)
    if i % 3 == 0 then sta = sta - 3000; H.res_power(POWERTYPE_STAMINA, sta, 20000) end
    sta = sta + 600; H.res_power(POWERTYPE_STAMINA, sta, 20000)
    H.damage_out({ hit = 1000, ability_id = 31 })
    H.advance(1000)
  end
  local n = TB.count()
  ok(n >= 8, "samples accumulated, got " .. n)
  local last = TB.at(n)
  ok(last.mag > 0 and last.mag < 0.2, "the magicka level is the pool's share of its max at the sample, got " .. tostring(last.mag))
  ok(math.abs(last.mag - mag / 30000) < 1e-6, "the level matches the last power event")
  ok(last.mag_in == 1000 and last.mag_out == 4000, "the flows of the sample are what was regained and spent in that second, got +" .. tostring(last.mag_in) .. " -" .. tostring(last.mag_out))
  ok(last.sta_in == 600 and (last.sta_out == 3000 or last.sta_out == 0), "stamina flows follow the same rule")
  local sum = R.summary(TB)
  ok(sum.has and sum.mag_out > 0 and math.abs(sum.mag_sigma - 0.25) < 0.05, "the fight's magicka regen/spend ratio is a quarter, got " .. tostring(sum.mag_sigma))
  ok(sum.mag_low_pct > 0, "the share of the fight under 15% magicka is counted, got " .. tostring(sum.mag_low_pct))
  local sg, gin, gout = R.window_sigma(TB, n, 10, 1)
  ok(sg and math.abs(sg - 0.25) < 0.05 and gin > 0 and gout > 0, "the ten-second window ratio reads the same on a steady pattern, got " .. tostring(sg))

  local drawn, lows, labels = 0, 0, {}
  for _, c in ipairs(H.controls) do
    local name = c._name or ""
    if c._hidden == false and name:find("^VermilionGraphRes") then
      if name:find("Lbl") then labels[#labels + 1] = c._text
      else
        drawn = drawn + 1
        if c._r and math.abs(c._r - 0.95) < 0.01 and math.abs(c._g - 0.42) < 0.01 then lows = lows + 1 end
      end
    end
  end
  ok(drawn > 4, "the resource strip draws cells for both pools, got " .. drawn)
  ok(lows > 0, "cells under 30% wear the vermilion tint")
  ok(#labels == 2 and ((labels[1] == "M" and labels[2] == "S") or (labels[1] == "S" and labels[2] == "M")), "the rows are lettered M and S")

  local alloc = H.addon_alloc(function()
    for i = 1, 1000 do H.res_power(POWERTYPE_MAGICKA, 10000 + (i % 7) * 100, 30000) end
  end)
  ok(alloc < (HARNESS_DEBUG and 4000 or 64), string.format("a thousand power events allocate %.0f addon-side bytes (budget %d)", alloc, HARNESS_DEBUG and 4000 or 64))

  G.on_stop_click()
  H.advance(500)
  ok(SS.count() == 1, "the session saved")
  local sess = SS.get(1)
  local names = {}
  for _, f in ipairs(sess.desc.series) do names[f.name] = true end
  ok(names.mag and names.sta and names.mag_in and names.sta_out, "the session description carries the resource fields")

  G.on_flush_click()
  ok(TB.count() == 0, "flushed")
  ok(G.load_session(sess), "the session loads back")
  local back = TB.at(TB.count())
  ok(math.abs(back.mag - last.mag) < 0.002 and back.mag_out == 4000 and back.mag_in == 1000, "levels and flows survive the round trip, got " .. tostring(back.mag) .. " " .. tostring(back.mag_out))
  local drawn2 = 0
  for _, c in ipairs(H.controls) do
    local name = c._name or ""
    if c._hidden == false and name:find("^VermilionGraphRes") and not name:find("Lbl") then drawn2 = drawn2 + 1 end
  end
  ok(drawn2 > 4, "a loaded session draws the strip too")

  local old = {}
  for k, v in pairs(sess) do old[k] = v end
  old.desc = {}
  for k, v in pairs(sess.desc) do old.desc[k] = v end
  local series_desc = {}
  for _, f in ipairs(sess.desc.series) do
    if not (f.name == "mag" or f.name == "sta" or f.name == "mag_in" or f.name == "mag_out" or f.name == "sta_in" or f.name == "sta_out") then
      series_desc[#series_desc + 1] = f
    end
  end
  old.desc.series = series_desc
  local V = Vermilion.lib.vsf
  local recs = V.unpack(sess.streams.series, sess.desc.series)
  old.streams = {}
  for k, v in pairs(sess.streams) do old.streams[k] = v end
  old.streams.series = V.pack(function(r, name) return recs[r][name] or 0 end, series_desc, #recs)
  G.on_flush_click()
  ok(G.load_session(old), "a session recorded before the resource fields loads")
  local s1 = TB.at(1)
  ok(s1.mag == 0 and s1.sta == 0 and s1.mag_in == 0, "it carries zero levels and flows")
  local drawn3 = 0
  for _, c in ipairs(H.controls) do
    local name = c._name or ""
    if c._hidden == false and name:find("^VermilionGraphRes") then drawn3 = drawn3 + 1 end
  end
  ok(drawn3 == 0, "and shows no resource strip, got " .. drawn3)

  G.on_flush_click()
  H.state.power = nil
  sv.settings.session_autosave = before_auto
end
