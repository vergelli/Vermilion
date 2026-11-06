return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G, S, FS, TB = Vermilion.Graph, Vermilion.Settings, Vermilion.FightStats, Vermilion.TemporalBuffer

  Vermilion.Metrics.reset()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  G.on_record_click()
  while VermilionGraphWindowViewLabel._text ~= "SKILL" do G.next_view() end

  local line, avg = VermilionGraphMedianLine, VermilionGraphAvgLine
  ok(S.median_line() == false and line._hidden == true, "the median line is off by default")
  ok(VermilionSettingsPanelMedianBtn._text == "Median line: Off", "the button names its state")

  for _ = 1, 40 do
    H.damage_out({ hit = 1000, ability_id = 31, target_unit_id = 900 })
    H.advance(1000)
  end
  S.on_median_click()
  ok(S.median_line() == true and VermilionSettingsPanelMedianBtn._text == "Median line: On", "one click turns it on")
  ok(line._hidden == true, "it does not draw while recording")
  for _ = 1, 15 do
    H.damage_out({ hit = 5000, ability_id = 31, target_unit_id = 900 })
    H.advance(1000)
  end
  G.on_stop_click()
  ok(line._hidden == false, "it draws once the fight is stopped")
  local st = FS.compute(TB)
  ok(FS.median(TB, true) == st.p50, "it is the same median the header card shows, got " .. tostring(FS.median(TB, true)) .. " and " .. tostring(st.p50))
  ok(st.p50 < st.p90, "this fight has a spread to read")

  S.on_avg_click()
  local h_med, h_avg = -line._anchor_list[1].oy, -avg._anchor_list[1].oy
  ok(avg._hidden == false and h_med < h_avg, "a burst pulls the average above the median, got " .. tostring(h_med) .. " and " .. tostring(h_avg))
  local dmg = Vermilion.Metrics.totals()
  local avg_v = dmg / (Vermilion.Metrics.fight_ms() / 1000)
  local want = (h_avg - 18) * st.p50 / avg_v
  ok(math.abs((h_med - 18) - want) <= 1.5, "both lines share the scale of the bars, got " .. tostring(h_med - 18) .. " for " .. tostring(want))
  S.on_avg_click()
  ok(line._hidden == false and avg._hidden == true, "each line has its own switch")

  local calls = 0
  local counting = {
    count = function() return TB.count() end,
    at = function(i) calls = calls + 1 return TB.at(i) end,
  }
  FS.median(counting, true)
  local first_calls = calls
  calls = 0
  FS.median(counting, true)
  ok(first_calls > 2 or calls <= 2, "the first reading walks the fight")
  ok(calls <= 2, "a redraw of the same fight does not sort it again, walked " .. tostring(calls))

  while VermilionGraphWindowViewLabel._text ~= "RESOURCES" do G.next_view() end
  ok(line._hidden == true, "the line belongs to the bar views")
  while VermilionGraphWindowViewLabel._text ~= "TYPE" do G.next_view() end
  ok(line._hidden == false, "it returns on TYPE")
  while VermilionGraphWindowViewLabel._text ~= "SKILL" do G.next_view() end

  local first = FS.median(TB, true)
  S.on_avg_click()
  G.on_flush_click()
  ok(line._hidden == true and avg._hidden == true, "New takes both lines away")
  S.on_avg_click()
  G.on_record_click()
  for _ = 1, 40 do
    H.damage_out({ hit = 3000, ability_id = 31, target_unit_id = 900 })
    H.shield_out({ hit = 2000 })
    H.advance(1000)
  end
  G.on_stop_click()
  local second = FS.median(TB, true)
  ok(second ~= first, "another fight reads its own median, got " .. tostring(second))
  ok(FS.median(TB, false) < second, "and the views without shields read without them, got " .. tostring(FS.median(TB, false)) .. " and " .. tostring(second))

  S.on_avg_click()
  local skill_med, skill_avg = line._anchor_list[1].oy, avg._anchor_list[1].oy
  while VermilionGraphWindowViewLabel._text ~= "TYPE" do G.next_view() end
  ok(line._anchor_list[1].oy == skill_med, "TYPE stacks shields in its bars, so its median counts them too, got " .. tostring(line._anchor_list[1].oy) .. " and " .. tostring(skill_med))
  ok(avg._anchor_list[1].oy == skill_avg, "and so does its average, got " .. tostring(avg._anchor_list[1].oy) .. " and " .. tostring(skill_avg))
  while VermilionGraphWindowViewLabel._text ~= "SKILL" do G.next_view() end
  S.on_avg_click()

  S.on_median_click()
  ok(S.median_line() == false and line._hidden == true, "a second click removes it")

  S.on_median_click()
  S.on_reset_click()
  ok(S.median_line() == false and line._hidden == true, "Reset turns it off")
  ok(VermilionSettingsPanelMedianBtn._text == "Median line: Off", "and the button says so")

  G.on_flush_click()
  Vermilion.Visibility.set("graph", false)
  Vermilion.Metrics.reset()
end
