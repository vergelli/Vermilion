return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G = Vermilion.Graph

  Vermilion.Metrics.reset()
  Vermilion.TemporalBuffer.clear()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  local view_label = VermilionGraphWindowViewLabel
  while view_label._text ~= "CRIT" do G.next_view() end
  G.on_record_click()

  for _ = 1, 10 do
    H.damage_out({ hit = 1000 })
    H.advance(1000)
  end
  ok(Vermilion.TemporalBuffer.count() == 10, "expected 10 samples, got " .. Vermilion.TemporalBuffer.count())

  local cw = H.layout(VermilionGraphWindowViewportCanvas).w
  local function fill_extents()
    local left, right = math.huge, 0
    for _, c in ipairs(H.controls) do
      local name = c._name or ""
      if c._hidden == false and name:find("^VermilionEdpsFill") and c._anchor_list then
        local x = c._anchor_list[1].ox or 0
        if x < left then left = x end
        if x + (c._w or 0) > right then right = x + (c._w or 0) end
      end
    end
    return left, right
  end

  local left, right = fill_extents()
  ok(right > cw * 0.96, string.format("bars must stay pinned to the right edge, right=%d cw=%d", right, cw))
  ok(left > cw * 0.28 and left < cw * 0.40,
     string.format("10/60 samples on a 15-slot axis should leave the left third empty, left=%d cw=%d", left, cw))
  ok(VermilionGridTL._text == "-15s", "growing axis must label the lookback span, got " .. tostring(VermilionGridTL._text))
  ok(VermilionGridTR._text == "now", "the right edge is now, got " .. tostring(VermilionGridTR._text))

  local widths = {}
  for _, c in ipairs(H.controls) do
    local name = c._name or ""
    if c._hidden == false and name:find("^VermilionEdpsFill") and c._w then widths[c._w] = true end
  end
  local distinct = 0
  for _ in pairs(widths) do distinct = distinct + 1 end
  ok(distinct == 1, "bar width must be uniform, got " .. distinct .. " widths")

  for _ = 1, 55 do
    H.damage_out({ hit = 1000 })
    H.advance(1000)
  end
  ok(Vermilion.TemporalBuffer.count() == 60, "buffer should be full")
  left, right = fill_extents()
  ok(left < 12 and right > cw * 0.96, string.format("full buffer must span the whole axis, left=%d right=%d cw=%d", left, right, cw))

  G.on_stop_click()
  G.on_flush_click()

  G.on_record_click()
  for _ = 1, 22 do
    H.damage_out({ hit = 1000 })
    H.advance(1000)
  end
  left, right = fill_extents()
  ok(left > cw * 0.22, string.format("while recording, 22/30 samples still leave the left quarter empty, left=%d cw=%d", left, cw))
  G.on_stop_click()
  local sl, sr = fill_extents()
  ok(sr > cw * 0.96, string.format("frozen bars keep the right edge, right=%d cw=%d", sr, cw))
  ok(sl < cw * 0.08, string.format("after Stop the axis fits the recording and the left gap closes, left=%d cw=%d", sl, cw))
  ok(VermilionGridTL._text == "-21s" or VermilionGridTL._text == "-22s", "the frozen axis labels the recorded span, got " .. tostring(VermilionGridTL._text))
  ok(VermilionGridYMax._hidden == false and (VermilionGridYMax._text or "") ~= "", "the axis names its maximum")
  G.on_flush_click()
  while view_label._text ~= "SKILL" do G.next_view() end
  Vermilion.Visibility.set("graph", false)
end
