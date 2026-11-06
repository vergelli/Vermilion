return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G, S, W, TB = Vermilion.Graph, Vermilion.Settings, Vermilion.FilmWindow, Vermilion.TemporalBuffer
  local cols = Vermilion.FilmColumns.cols

  local function tallest()
    local top = 0
    for _, c in ipairs(H.controls) do
      if c._hidden == false and type(c._name) == "string" and c._name:find("^VermilionEosSeg") and (c._h or 0) > top then
        top = c._h
      end
    end
    return top
  end
  local function show(view)
    while VermilionGraphWindowViewLabel._text ~= view do G.next_view() end
  end

  Vermilion.Metrics.reset()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  G.on_record_click()
  show("SKILL")
  H.advance(20000)
  for _ = 1, 60 do
    H.damage_out({ hit = 1000, ability_id = 31, target_unit_id = 900 })
    H.advance(1000)
  end
  for _ = 1, 10 do
    H.damage_out({ hit = 9000, ability_id = 31, target_unit_id = 900 })
    H.advance(1000)
  end
  G.on_stop_click()

  local xml = assert(io.open(HARNESS_ROOT .. "/ui/settings.xml")):read("*a")
  local function y_of(name)
    return tonumber(xml:match('name="%$%(parent%)' .. name .. '".-offsetY="(%-?%d+)"'))
  end
  local sample_y, zoom_y, bucket_y, reset_y = y_of("SampleBtn"), y_of("ZoomScaleBtn"), y_of("UnknownBtn"), 300 - 8 - 22
  ok(zoom_y >= sample_y + 24 and zoom_y + 22 <= bucket_y, "the switch sits in GRAPH, under the sample rate and above the bucket, got " .. tostring(zoom_y) .. " and " .. tostring(bucket_y))
  ok(bucket_y + 64 <= reset_y, "and the bucket still clears Reset, got " .. tostring(bucket_y))

  local btn, label = VermilionSettingsPanelZoomScaleBtn, VermilionGridYMax
  local n = TB.count()
  local whole = label._text
  ok(S.zoom_local_scale() == false, "zoom keeps the scale of the whole fight by default")
  ok(btn._text == "Zoom scale: Whole fight", "the button names its state, got " .. tostring(btn._text))

  for _ = 1, 40 do
    if not W.zoom(-1, 0, n) then break end
  end
  G.rerender()
  ok(W.is_zoomed() and cols.last < 25, "the view sits on the silence before the first hit, got " .. tostring(cols.last))
  ok(label._text == whole, "by default the scale does not move, got " .. tostring(label._text))

  S.on_zoom_scale_click()
  ok(S.zoom_local_scale() == true and btn._text == "Zoom scale: Visible part", "one click follows the visible part, got " .. tostring(btn._text))
  ok(label._text == whole, "a stretch with nothing in it keeps the scale of the fight, got " .. tostring(label._text))

  W.center_on(0.45, n)
  S.on_zoom_scale_click()
  ok(label._text == whole, "off, a quiet stretch keeps the scale of the fight")
  local quiet = tallest()
  S.on_zoom_scale_click()
  ok(label._text ~= whole, "on, the top of the scale is the top of this stretch, got " .. tostring(label._text))
  local grown = tallest()
  ok(grown > quiet * 2, "so its bars grow, got " .. tostring(quiet) .. " to " .. tostring(grown))
  local top_here = 0
  for i = cols.first, cols.last do
    local s = TB.at(i)
    if s.eDPS + s.ShDPS > top_here then top_here = s.eDPS + s.ShDPS end
  end
  ok(top_here > 0 and top_here < 3000, "the view is really on the quiet part, got " .. tostring(top_here))

  local avg = VermilionGraphAvgLine
  S.on_avg_click()
  ok(avg._hidden == true, "the average of the whole fight is above this scale, so it leaves the chart")

  show("TYPE")
  ok(label._text ~= whole, "TYPE follows too")
  show("CRIT")
  ok(label._text ~= whole, "CRIT follows too")
  show("SKILL")

  W.reset()
  G.rerender()
  ok(label._text == whole, "with the whole film in view it is the same scale again, got " .. tostring(label._text))
  ok(avg._hidden == false, "and the average returns")
  S.on_avg_click()

  W.zoom(-1, 0.45, n)
  G.rerender()
  S.on_reset_click()
  ok(S.zoom_local_scale() == false and btn._text == "Zoom scale: Whole fight", "Reset goes back to the whole fight")
  ok(label._text == whole, "and redraws, got " .. tostring(label._text))

  W.reset()
  G.on_flush_click()
  Vermilion.Visibility.set("graph", false)
  Vermilion.Metrics.reset()
end
