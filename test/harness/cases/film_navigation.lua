return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local TB, G, W, O = Vermilion.TemporalBuffer, Vermilion.Graph, Vermilion.FilmWindow, Vermilion.FilmOverview
  local cols = Vermilion.FilmColumns.cols

  W.reset()
  local f, d = W.range(10, 480, true, 60)
  ok(f == 1 and d == 60, "recording uses the live window")
  f, d = W.range(100, 480, true, 60)
  ok(f == 41 and d == 60, "recording follows the newest samples")
  f, d = W.range(100, 480, false, 60)
  ok(f == 1 and d == 100 and not W.is_zoomed(), "a stopped film fits")
  ok(W.zoom(-1, 0.5, 100) and W.is_zoomed(), "the wheel zooms in")
  f, d = W.range(100, 480, false, 60)
  ok(d == 80 and f == 11, "zooming at the middle keeps the middle, got " .. f .. " " .. d)
  W.reset()
  W.zoom(-1, 0, 100)
  f, d = W.range(100, 480, false, 60)
  ok(f == 1, "zooming at the left edge keeps the left edge, got " .. f)
  W.reset()
  W.zoom(-1, 1, 100)
  f, d = W.range(100, 480, false, 60)
  ok(f + d - 1 == 100, "zooming at the right edge keeps the right edge, got " .. f .. " " .. d)
  for _ = 1, 40 do W.zoom(-1, 0.5, 100) end
  f, d = W.range(100, 480, false, 60)
  ok(d == 15, "zoom stops at the minimum span, got " .. d)
  ok(W.pan(1, 100), "shift wheel moves the window")
  for _ = 1, 200 do W.pan(1, 100) end
  f, d = W.range(100, 480, false, 60)
  ok(f + d - 1 == 100, "panning stops at the end")
  ok(W.pan(1, 100) == false, "panning past the end changes nothing")
  ok(W.center_on(0, 100), "the strip can jump to the start")
  f = W.range(100, 480, false, 60)
  ok(f == 1, "centering past the start clamps, got " .. f)
  for _ = 1, 40 do W.zoom(1, 0.5, 100) end
  ok(not W.is_zoomed(), "zooming all the way out returns to the whole film")
  ok(W.zoom(-1, 0.5, 10) == false, "a tiny film does not zoom")

  Vermilion.Metrics.reset()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  local view_label = VermilionGraphWindowViewLabel
  while view_label._text ~= "SKILL" do G.next_view() end
  local canvas = VermilionGraphWindowViewportCanvas
  local tall = canvas:GetHeight()

  G.on_record_click()
  for i = 1, 300 do
    H.damage_out({ hit = 500 + (i * 37) % 2000, ability_id = 62951 })
    H.advance(1000)
  end
  ok(not O.is_showing(), "the strip stays out of the way while recording")
  ok(canvas:GetHeight() == tall, "the chart keeps its height while recording")
  G.on_stop_click()
  local n = TB.count()
  ok(O.is_showing() and VermilionFilmStrip._hidden == false, "stopping shows the strip")
  ok(canvas:GetHeight() < tall, "the strip takes its room from the chart")
  ok(cols.first == 1 and cols.last == n and cols.denom == n, "the whole film shows")
  local bars = 0
  for i = 1, 400 do
    local b = rawget(_G, "VermilionFilmStripBar" .. i)
    if b and b._hidden == false then bars = bars + 1 end
  end
  ok(bars > 20, "the strip draws the fight, got " .. bars)

  local function mouse_at(frac)
    local L = H.layout(canvas)
    H.state.mouse_x = L.x + frac * L.w
    H.state.mouse_y = L.y + 40
  end
  local function wheel(delta)
    VermilionGraphHit._onOnMouseWheel(VermilionGraphHit, delta)
  end
  mouse_at(0.5)
  for _ = 1, 4 do wheel(1) end
  ok(W.is_zoomed() and cols.denom < n, "the wheel zooms the chart, got " .. cols.denom)
  ok(cols.last - cols.first + 1 <= cols.denom, "the view stays inside the window")
  ok(VermilionGridTR._text ~= "now", "a zoomed view does not call its right edge now")

  local before = cols.first
  H.state.shift = true
  wheel(-1)
  H.state.shift = false
  ok(cols.first > before, "shift wheel pans forward, " .. before .. " to " .. cols.first)
  local bands_left = H.layout(canvas).x
  for _, c in ipairs(H.controls) do
    if c._hidden == false and type(c._name) == "string" and c._name:find("^VermilionGraphRes%d") then
      ok(H.layout(c).x >= bands_left - 1, "resource cells stay inside a zoomed view")
    end
  end

  O.drag_to(0)
  ok(cols.first == 1, "dragging the strip to the start shows the start, got " .. cols.first)
  O.drag_to(1)
  ok(cols.last == n, "dragging the strip to the end shows the end, got " .. cols.last)

  local signature = {}
  local visible = 0
  for i = 1, 400 do
    local b = rawget(_G, "VermilionFilmStripBar" .. i)
    if b and b._hidden == false then visible = visible + 1; signature[i] = b._h end
  end
  ok(visible == bars, "panning keeps the strip as it was")
  O.drag_to(0.5)
  local a_first = cols.first
  O.drag_to(0.5)
  ok(cols.first == a_first, "the same position shows the same columns")
  local stride_top = {}
  for i = 1, 3 do stride_top[i] = cols[i].eos_peak end
  O.drag_to(0.6)
  O.drag_to(0.5)
  for i = 1, 3 do
    ok(cols[i].eos_peak == stride_top[i], "bars do not change value after moving away and back")
  end

  while view_label._text ~= "TYPE" do G.next_view() end
  ok(W.is_zoomed() and O.is_showing(), "the zoom follows across the bar views")
  while view_label._text ~= "RESOURCES" do G.next_view() end
  ok(not O.is_showing() and canvas:GetHeight() == tall, "other views give the room back")
  while view_label._text ~= "SKILL" do G.next_view() end

  O.mouse_down(2)
  ok(not W.is_zoomed() and cols.denom == n, "right click returns to the whole film")

  mouse_at(0.5)
  wheel(1)
  ok(W.is_zoomed(), "zoomed again")
  G.on_record_click()
  ok(not W.is_zoomed() and not O.is_showing(), "a new recording starts unzoomed with no strip")
  G.on_stop_click()
  G.on_flush_click()
  ok(not O.is_showing(), "an empty film has no strip")
  Vermilion.Visibility.set("graph", false)
end
