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
  local rows, duration = report(), duration_line()
  ok(duration ~= nil, "the export names a duration")
  G.on_save_click()
  H.advance(400)
  ok(G.load_session(SS.get(SS.count())), "the saved fight opens")
  ok(U.has_data() == false, "and after reopening it still has none")
  ok(report() == rows, "the damage report reads the same, got\n" .. report() .. "\nwas\n" .. rows)
  ok(duration_line() == duration, "the export gives the same duration, got " .. tostring(duration_line()) .. " was " .. tostring(duration))

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

  G.on_flush_click()
  Vermilion.Visibility.set("graph", false)
  M.reset()
end
