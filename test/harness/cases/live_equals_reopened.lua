return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G, M, SS, U = Vermilion.Graph, Vermilion.Metrics, Vermilion.SessionStore, Vermilion.Ultimate

  local function report()
    local hit = VermilionGraphSummaryHit
    hit._onOnMouseEnter(hit)
    local rows = {}
    for i = 1, 19 do
      local name, val = rawget(_G, "VermilionHoverCardRowName" .. i), rawget(_G, "VermilionHoverCardRowVal" .. i)
      if name and name._hidden == false then rows[#rows + 1] = tostring(name._text) .. " = " .. tostring(val._text) end
    end
    hit._onOnMouseExit(hit)
    return table.concat(rows, "\n")
  end
  local function duration_line()
    for _, section in ipairs(Vermilion.ExportReport.SECTIONS) do
      local line = (section() or ""):match("Duration: [%d%.]+ s")
      if line then return line end
    end
  end

  M.reset()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  G.on_record_click()
  H.advance(400)
  for _ = 1, 12 do
    H.damage_out({ hit = 1000, ability_id = 31, target_unit_id = 900 })
    H.advance(1000)
  end
  H.advance(1700)
  G.on_stop_click()
  ok(U.has_data() == false, "a fight with no ultimate change has no ultimate to show")
  H.ult_power(250)
  ok(U.has_data() == false, "and a change after Stop does not give it one")
  local rows, duration = report(), duration_line()
  ok(duration ~= nil, "the export names a duration")
  G.on_save_click()
  H.advance(400)
  ok(G.load_session(SS.get(SS.count())), "the saved fight opens")
  ok(U.has_data() == false, "and after reopening it still has none")
  H.ult_power(300)
  ok(U.has_data() == false, "not even when the ultimate moves while looking at it")
  ok(report() == rows, "the damage report reads the same, got\n" .. report() .. "\nwas\n" .. rows)
  ok(duration_line() == duration, "the export gives the same duration, got " .. tostring(duration_line()) .. " was " .. tostring(duration))

  G.on_flush_click()
  G.on_record_click()
  H.advance(100)
  H.ult_power(200)
  for _ = 1, 8 do
    H.damage_out({ hit = 1000, ability_id = 31, target_unit_id = 900 })
    H.advance(1000)
  end
  G.on_stop_click()
  ok(U.has_data() == false, "one change right after Record merges with the starting value and is no data")
  local early = report()
  G.on_save_click()
  H.advance(400)
  ok(G.load_session(SS.get(SS.count())), "the saved fight opens")
  ok(report() == early, "and that fight reads the same reopened, got\n" .. report() .. "\nwas\n" .. early)

  G.on_flush_click()
  G.on_record_click()
  H.ult_power(120)
  for _ = 1, 8 do
    H.ult_power(120 + _ * 10)
    H.damage_out({ hit = 1000, ability_id = 31, target_unit_id = 900 })
    H.advance(1000)
  end
  G.on_stop_click()
  ok(U.has_data() == true, "a fight with ultimate changes has it")
  local with_ult = report()
  G.on_save_click()
  H.advance(400)
  ok(G.load_session(SS.get(SS.count())), "the saved fight opens")
  ok(U.has_data() == true, "and keeps it after reopening")
  ok(report() == with_ult, "the report reads the same, got\n" .. report() .. "\nwas\n" .. with_ult)

  local function peak_line()
    for _, section in ipairs(Vermilion.ExportReport.SECTIONS) do
      local line = (section() or ""):match("Peak at s;[^\n]+")
      if line then return line end
    end
  end
  G.on_flush_click()
  H.advance(30000)
  G.on_record_click()
  H.advance(2500)
  H.damage_out({ hit = 1000, ability_id = 31, target_unit_id = 900 })
  H.advance(100)
  G.on_stop_click()
  ok(Vermilion.TemporalBuffer.count() >= 2 and G.export_summary().peak == 0, "stopping right after the first hit leaves no sample with damage")
  ok(G.export_summary().peak_t_off == 0, "and no peak means no peak time, got " .. tostring(G.export_summary().peak_t_off))
  local short = peak_line()
  ok(short == nil or not short:find("-", 1, true), "the export has no negative time, got " .. tostring(short))
  G.on_save_click()
  H.advance(400)
  ok(G.load_session(SS.get(SS.count())), "the saved fight opens")
  ok(peak_line() == short, "and reads the same, got " .. tostring(peak_line()) .. " was " .. tostring(short))

  G.on_flush_click()
  Vermilion.Visibility.set("graph", false)
  M.reset()
end
