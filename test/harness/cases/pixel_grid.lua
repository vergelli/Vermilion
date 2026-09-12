return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G = Vermilion.Graph

  local checked = 0
  for _, sc in ipairs({ 1, 0.8, 0.9, 1.25 }) do
    for cw = 200, 1000, 1 do
      for _, denom in ipairs({ 15, 37, 75, 150, 300, 600, 1200, 2400 }) do
        local n, P, x0, bw, base_p = G.column_geometry(cw, denom, sc, 14.3)
        checked = checked + 1
        ok(P == math.floor(P) and P >= 1, "pitch must be a whole physical pixel")
        ok(x0 >= 0, "the blank remainder never goes negative")
        ok(x0 + n * P <= math.floor(cw * sc), "columns never overrun the canvas")
        local minp = math.floor(6 * sc + 0.5)
        if denom >= math.floor(math.floor(cw * sc) / minp) then
          ok(x0 < minp, string.format("steady state leaves less than one pitch blank (cw=%d sc=%.2f denom=%d x0=%d P=%d)", cw, sc, denom, x0, P))
        end
        ok(math.abs(bw * sc - math.floor(bw * sc + 0.5)) < 1e-6, "bar width is a whole physical pixel")
        ok(bw * sc <= P and bw * sc >= P - 1, "bar plus gap equals the pitch")
      end
    end
  end
  ok(checked > 20000, "sweep ran")

  Vermilion.Metrics.reset()
  Vermilion.TemporalBuffer.clear()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  local view_label = VermilionGraphWindowViewLabel
  while view_label._text ~= "CRIT" do G.next_view() end
  G.on_record_click()
  for _ = 1, 120 do
    H.damage_out({ hit = 1500 })
    H.advance(1000)
  end
  G.on_stop_click()

  local canvas = VermilionGraphWindowViewportCanvas
  local cw0, ch0 = canvas:GetDimensions()
  local function bars()
    local lefts, widths = {}, {}
    for _, c in ipairs(H.controls) do
      local name = c._name or ""
      if c._hidden == false and name:find("^VermilionEdpsFill") and c._anchor_list then
        lefts[#lefts + 1] = c._anchor_list[1].ox or 0
        widths[c._w or 0] = true
      end
    end
    table.sort(lefts)
    local pitches = {}
    for i = 2, #lefts do pitches[string.format("%.3f", lefts[i] - lefts[i - 1])] = true end
    local nw, np = 0, 0
    for _ in pairs(widths) do nw = nw + 1 end
    for _ in pairs(pitches) do np = np + 1 end
    return #lefts, nw, np, lefts
  end

  for _, sc in ipairs({ 1, 0.8 }) do
    H.state.ui_scale = sc
    for _, cw in ipairs({ 331, 350, 407, 605, 699 }) do
      canvas:SetDimensions(cw, ch0)
      G.on_resize_stop()
      local n, nw, np, lefts = bars()
      ok(n >= 40, "bars drawn at cw=" .. cw .. ": " .. n)
      ok(nw == 1, string.format("one bar width at cw=%d sc=%.2f, got %d", cw, sc, nw))
      ok(np == 1, string.format("one pitch at cw=%d sc=%.2f, got %d", cw, sc, np))
      ok(lefts[#lefts] < cw and lefts[1] >= 0, "columns stay inside the canvas at cw=" .. cw)
    end
  end
  H.state.ui_scale = nil

  G.set_pixel_grid(false)
  ok(G.pixel_grid() == false, "the switch turns the grid off")
  canvas:SetDimensions(331, ch0)
  G.on_resize_stop()
  local _, nw_off = bars()
  ok(nw_off == 1, "the old path still draws")
  G.set_pixel_grid(true)
  canvas:SetDimensions(cw0, ch0)
  G.on_resize_stop()

  G.on_flush_click()
  while view_label._text ~= "SKILL" do G.next_view() end
  Vermilion.Visibility.set("graph", false)
  Vermilion.Metrics.reset()
end
