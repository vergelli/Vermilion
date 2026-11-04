return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G, E, R = Vermilion.Graph, Vermilion.Export, Vermilion.ExportReport

  Vermilion.Metrics.reset()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()

  ok(VermilionGraphWindowExportBtn._enabled == false, "no data, no export")
  E.open()
  ok(VermilionExport._hidden == true, "opening with no data does nothing")

  G.on_record_click()
  ok(VermilionGraphWindowExportBtn._enabled == false, "no export while recording")
  for i = 1, 400 do
    H.damage_out({ hit = 1000, ability_id = 31 })
    H.damage_out({ hit = 500, ability_id = 32, result = ACTION_RESULT_CRITICAL_DAMAGE })
    H.advance(1000)
  end
  G.on_stop_click()
  ok(VermilionGraphWindowExportBtn._enabled == true, "a stopped session can be exported")

  E.open()
  ok(VermilionExport._hidden == false, "the window opens")
  ok(VermilionExportProgress._hidden == false and VermilionExportBody._hidden == true, "it shows the progress while it builds")
  ok(H.update_registered("VermilionExportBuild"), "the report builds across frames")
  for _ = 1, #R.SECTIONS + 2 do H.advance(20) end
  ok(not H.update_registered("VermilionExportBuild"), "the build stops when it is done")
  ok(VermilionExportProgress._hidden == true and VermilionExportBody._hidden == false, "then it shows the text")

  local txt = VermilionExportEdit._text or ""
  for _, needle in ipairs({ "## Summary", "## Skills", "## Targets", "## Timeline", "Total damage;" }) do
    ok(txt:find(needle, 1, true), "the report carries " .. needle .. ": " .. txt:sub(1, 400))
  end
  ok(not txt:find("##[^\n]*\n[^\n]*\n\n"), "a section with no rows is left out")
  ok(not txt:find("|", 1, true), "no pipe reaches the edit box, the game reads it as markup")

  local _, n, totals = Vermilion.ContribView.compute()
  local order = Vermilion.ContribView.rows()
  ok(n >= 2, "the session has skills")
  local tot = totals.damage + totals.shield
  local name = order[1].name
  local line = txt:match("\n1;" .. name:gsub("%p", "%%%0") .. ";[^\n]*")
  ok(line, "the first skill is in the table: " .. name)
  local reported = tonumber(line:match("^\n1;[^;]*;[^;]*;[^;]*;([%d%.]+)"))
  ok(math.abs(reported - order[1].v / tot * 100) < 0.051, "the skill share equals what CONTRIB computes")

  local sm = G.export_summary()
  ok(txt:find("Crit rate, share of hits %;50.0", 1, true), "half of the hits were crits: " .. txt:sub(1, 700))
  ok(txt:find("Damage from crits %;33.3", 1, true), "and a third of the damage came from them")
  ok(txt:find("Total damage;" .. string.format("%d", math.floor(sm.total_damage + 0.5)), 1, true), "the total equals the header summary")

  ok(R.paginate("a\nb", 100)[1] == "a\nb", "a short report stays in one page")
  local big = {}
  for i = 1, 500 do big[i] = string.format("%04d %s", i, string.rep("x", 40)) end
  local joined = table.concat(big, "\n")
  local pages = R.paginate(joined, 2000)
  ok(#pages > 1, "a long report splits")
  local seen = 0
  for i, p in ipairs(pages) do
    ok(#p <= 2000 + 64, "a page stays under the limit")
    ok(p:find("Part " .. i .. " of " .. #pages, 1, true), "each page says which part it is")
    for num in p:gmatch("\n(%d%d%d%d) x") do seen = seen + 1; ok(tonumber(num) == seen, "no line is lost or reordered") end
  end
  ok(seen == 500, "every line survives the split, saw " .. seen)

  ok(#txt > 3000, "the report is long enough to test the shrink, got " .. #txt)
  VermilionExportEdit._max = 3000
  E.open()
  for _ = 1, #R.SECTIONS + 2 do H.advance(20) end
  local _, _, limit = E.pages()
  ok(limit < 24000, "an edit box that truncates shrinks the pages instead of losing text")
  ok(#VermilionExportEdit._text == #E.pages()[1], "the page fits whole, got " .. #VermilionExportEdit._text)
  ok(#E.pages() > 1, "the rest goes to the next parts")
  ok(VermilionExportNextBtn._hidden == false, "the pager appears")
  E.next_page()
  ok(select(2, E.pages()) == 2, "the pager moves")
  VermilionExportEdit._max = nil

  E.hide()
  ok(VermilionExport._hidden == true, "the window closes")
  ok(VermilionExportEdit._focused == false, "closing gives the keyboard back")

  local size, got = E.copy_test(3000)
  ok(size >= 3000 and got == #VermilionExportEdit._text, "the copy test reports what the box holds")
  ok(VermilionExportEdit._text:find("END " .. size, 1, true), "and ends with its size")
  E.hide()

  G.on_flush_click()
  Vermilion.Visibility.set("graph", false)
  Vermilion.Metrics.reset()
end
