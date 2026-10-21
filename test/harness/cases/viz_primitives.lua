return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end

  local Pool = Vermilion.lib.plot.Pool
  local viz = Vermilion.lib.viz
  ok(viz and viz.surface and viz.spans and viz.stems and viz.scatter and viz.ring, "lib/viz loads its five modules")

  local canvas = WINDOW_MANAGER:CreateControl("VizTestCanvas", nil, CT_CONTROL)
  canvas:SetDimensions(600, 400)
  local c = {
    canvas = canvas,
    seg = Pool.new("VizTestSeg", canvas, CT_TEXTURE, function(x) x:SetDrawLevel(2) end, function(x) x:SetHidden(true) end),
    lbl = Pool.new("VizTestLbl", canvas, CT_LABEL, function(x) x:SetDrawLevel(5) end, function(x) x:SetHidden(true) end),
    line = Pool.new_virtual("VizTestLine", canvas, "VermilionGraphLineTemplate", function(x) x:SetThickness(1) end, function(x) x:SetHidden(true); x:ClearAnchors() end),
    icon = Pool.new("VizTestIcon", canvas, CT_TEXTURE, function(x) x:SetDrawLevel(7) end, function(x) x:SetHidden(true) end),
  }
  local S, SP, ST, SC, RG = viz.surface, viz.spans, viz.stems, viz.scatter, viz.ring

  local function scan(prefix)
    local r = { n = 0, w1 = 0, alpha = {}, colors = {}, maxx = -1, minx = 1e9 }
    for _, ctl in ipairs(H.controls) do
      if ctl._hidden == false and (ctl._name or ""):find("^" .. prefix) then
        r.n = r.n + 1
        if ctl._w == 1 then r.w1 = r.w1 + 1 end
        local key = string.format("%.2f %.2f %.2f", ctl._r or -1, ctl._g or -1, ctl._b or -1)
        r.colors[key] = (r.colors[key] or 0) + 1
        local al = ctl._anchor_list and ctl._anchor_list[1]
        if al then
          if al.ox > r.maxx then r.maxx = al.ox end
          if al.ox < r.minx then r.minx = al.ox end
        end
      end
    end
    return r
  end

  local function release()
    c.seg:ReleaseAllObjects(); c.lbl:ReleaseAllObjects(); c.line:ReleaseAllObjects(); c.icon:ReleaseAllObjects()
  end

  local scale = { x0 = 50, w = 500, t0 = 0, span = 100000 }
  local col = { r = 0.9, g = 0.5, b = 0.2 }
  local t0 = { 0, 10000, 25000, 60000, 90000 }
  local t1 = { 9000, 20000, 50000, 70000, 120000 }
  local press = { 10000, 25000, 60000 }
  local clip = { 0, 0, 3000 }

  S.begin(c)
  local up = SP.row(c, scale, 20, 14, col, t0, t1, 5, press, 3, clip, nil)
  ok(math.abs(up - 0.64) < 0.001, "a row reports the covered share of the scale, merged and clamped, got " .. tostring(up))
  local r = scan("VizTestSeg")
  ok(r.colors["0.90 0.50 0.20"] == 5, "five spans draw as five boxes in the row colour, got " .. tostring(r.colors["0.90 0.50 0.20"]))
  ok(r.colors["0.94 0.88 0.86"] == 3, "every press leaves a mark, got " .. tostring(r.colors["0.94 0.88 0.86"]))
  ok((r.colors["0.80 0.68 0.40"] or 0) >= 3, "a clip is stippled before its press, got " .. tostring(r.colors["0.80 0.68 0.40"]))
  ok(r.colors["0.86 0.28 0.18"] == 1, "the gap ground is one box under the row")
  ok(c.drawn == r.n, "the surface counts what it drew, got " .. tostring(c.drawn) .. " vs " .. r.n)
  release()

  local xs = { 5000, 20000, 40000, 60000, 80000 }
  local vs = { 2.5, -1.5, 0.2, 6.0, -0.3 }
  local up_c, dn_c, in_c = { r = 0.8, g = 0.68, b = 0.4 }, { r = 0.86, g = 0.28, b = 0.18 }, { r = 0.46, g = 0.8, b = 0.35 }
  S.begin(c)
  local clamped = ST.plot(c, scale, 60, 80, xs, vs, 5, -4, 4, -0.5, 0.5, up_c, dn_c, in_c, nil)
  ok(clamped == 1, "a value beyond the scale is clamped and reported, got " .. tostring(clamped))
  r = scan("VizTestSeg")
  ok((r.colors["0.80 0.68 0.40"] or 0) >= 3 and (r.colors["0.86 0.28 0.18"] or 0) >= 2 and (r.colors["0.46 0.80 0.35"] or 0) >= 4, "stems above the band are gold, below vermilion, inside green")
  ok(r.w1 >= 5, "each stem is a one-pixel column, got " .. r.w1)
  release()

  local sx = { 10, 10.5, 9.8, 20, 19.5, 4 }
  local sy = { 10.2, 9.9, 10, 19.8, 20, 25 }
  S.begin(c)
  local outside = SC.plot(c, 100, 100, 200, 24, sx, sy, 6, col, { diagonal = true, rings = { x = { 10, 20 }, y = { 10, 20 }, r = { 2, 2 }, n = 2, col = in_c } })
  ok(outside == 1, "a dot beyond the range is clamped and reported, got " .. tostring(outside))
  r = scan("VizTestSeg")
  ok(r.colors["0.90 0.50 0.20"] == 6, "six dots, got " .. tostring(r.colors["0.90 0.50 0.20"]))
  ok(r.colors["0.46 0.80 0.35"] == 48, "two rings of twenty-four boxes, got " .. tostring(r.colors["0.46 0.80 0.35"]))
  local lines = scan("VizTestLine")
  ok(lines.n == 1, "the diagonal is one line control, got " .. lines.n)
  release()

  S.begin(c)
  local lit = RG.gauge(c, 300, 300, 30, 0.75, col, 3, nil)
  ok(lit == 27, "three quarters of thirty-six boxes are lit, got " .. tostring(lit))
  r = scan("VizTestSeg")
  ok(r.n == 36, "a gauge is thirty-six boxes, got " .. r.n)
  local lit_boxes, dim_boxes = 0, 0
  for _, ctl in ipairs(H.controls) do
    if ctl._hidden == false and (ctl._name or ""):find("^VizTestSeg") then
      if ctl._a and ctl._a > 0.9 then lit_boxes = lit_boxes + 1 elseif ctl._a and ctl._a < 0.2 then dim_boxes = dim_boxes + 1 end
    end
  end
  ok(lit_boxes == 27 and dim_boxes == 9, "lit and dim boxes split by the fraction, got " .. lit_boxes .. " and " .. dim_boxes)
  release()

  S.begin(c)
  S.label(c, "UPTIME", 10, 10, 80, 14, TEXT_ALIGN_LEFT, col, 1)
  S.icon(c, "/esoui/art/icons/icon_missing.dds", 10, 30, 18, 1)
  S.frame(c, 0, 0, 100, 50, col, 0.4, 6)
  ok(c.drawn == 6, "a label, an icon and a frame of four boxes count six controls, got " .. tostring(c.drawn))
  release()

  local nolines = { canvas = canvas, seg = c.seg, lbl = c.lbl, icon = c.icon }
  S.begin(nolines)
  ok(S.line(nolines, 0, 0, 10, 10, col, 1, 1) == false and nolines.dropped == 1, "a surface without a line pool drops the line and counts it")
  release()

  local function draw_all()
    S.begin(c)
    SP.row(c, scale, 20, 14, col, t0, t1, 5, press, 3, clip, nil)
    ST.plot(c, scale, 60, 80, xs, vs, 5, -4, 4, -0.5, 0.5, up_c, dn_c, in_c, nil)
    SC.plot(c, 100, 100, 200, 24, sx, sy, 6, col, { diagonal = true })
    RG.gauge(c, 300, 300, 30, 0.75, col, 3, nil)
    release()
  end
  draw_all()
  local bytes = H.addon_alloc(draw_all)
  ok(bytes < (HARNESS_DEBUG and 6000 or 64), string.format("drawing every primitive again allocates %.0f addon-side bytes (budget %d)", bytes, HARNESS_DEBUG and 6000 or 64))

end
