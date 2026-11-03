return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local TB, G = Vermilion.TemporalBuffer, Vermilion.Graph
  local old_cap = TB.capacity()

  Vermilion.Metrics.reset()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  TB.init(240)
  local view_label = VermilionGraphWindowViewLabel
  while view_label._text ~= "SKILL" do G.next_view() end

  local function run(seconds)
    for _ = 1, seconds do
      H.damage_out({ hit = 1500, ability_id = 62951 })
      H.advance(1000)
    end
  end

  G.on_record_click()
  local live = Vermilion.Constants.TEMPORAL.LIVE_WINDOW_S
  run(math.floor(live / 2))
  ok(TB.count() < live and G.window_denom() == live, "a young recording already uses the live window, got " .. G.window_denom())
  run(live)
  ok(TB.count() > live and G.window_denom() == live, "the live window does not grow with the recording, got " .. G.window_denom())
  local width = G.column_pitch()
  run(30)
  ok(G.window_denom() == live and G.column_pitch() == width, "the bars keep their width while the window scrolls")

  local canvas = VermilionGraphWindowViewportCanvas
  local left = H.layout(canvas).x
  local name_ok = { "^VermilionGraphRes%d", "^VermilionShieldHeat", "^VermilionGraphUlt%d" }
  local band_cells = 0
  for _, c in ipairs(H.controls) do
    if c._hidden == false and type(c._name) == "string" then
      for i = 1, #name_ok do
        if c._name:find(name_ok[i]) then
          band_cells = band_cells + 1
          ok(H.layout(c).x >= left - 1, "band cell " .. c._name .. " stays inside the viewport, got x " .. H.layout(c).x .. " left " .. left)
        end
      end
    end
  end

  ok(band_cells > 0, "the live view draws band cells to check")

  local S, avg = Vermilion.Settings, VermilionGraphAvgLine
  ok(S.average_line() == false and avg._hidden == true, "the average line is off by default")
  S.on_avg_click()
  ok(S.average_line() == true and avg._hidden == false, "one click draws the average line")
  ok(VermilionSettingsPanelAvgBtn._text == "Average line: On", "the button names its state")
  while view_label._text ~= "RESOURCES" do G.next_view() end
  ok(avg._hidden == true, "the average line belongs to the bar views")
  while view_label._text ~= "SKILL" do G.next_view() end
  ok(avg._hidden == false, "the average line returns on the bar views")
  S.on_avg_click()
  ok(S.average_line() == false and avg._hidden == true, "a second click removes it")

  local n = TB.count()
  ok(n > live, "the buffer keeps more than the live window, got " .. n)
  G.on_stop_click()
  ok(G.window_denom() == TB.count(), "stopping shows the whole film, got " .. G.window_denom() .. " of " .. TB.count())

  G.on_flush_click()
  TB.init(old_cap)
end
