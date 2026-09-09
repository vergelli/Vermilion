return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G = Vermilion.Graph
  local CV = Vermilion.ContribView
  local view_label = VermilionGraphWindowViewLabel
  local hit = VermilionGraphHit

  local function visible_labels()
    local t = {}
    for _, c in ipairs(H.controls) do
      local name = c._name or ""
      if c._hidden == false and name:find("^VermilionContribLbl") and c._text then t[#t + 1] = c._text end
    end
    return t
  end
  local function has(list, text)
    for _, v in ipairs(list) do if v == text then return true end end
    return false
  end
  local function find_prefix(list, prefix)
    for _, v in ipairs(list) do if v:sub(1, #prefix) == prefix then return v end end
    return nil
  end

  Vermilion.Metrics.reset()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  local canvas = VermilionGraphWindowViewportCanvas
  local w0, h0 = VermilionGraphWindow:GetDimensions()
  local cw0, ch0 = canvas:GetDimensions()
  VermilionGraphWindow:SetDimensions(420, 312)
  canvas:SetDimensions(392, 160)
  G.on_resize_stop()
  H.ability_names = {}
  for k = 1, 12 do H.ability_names[8000 + k] = string.format("Skill %02d", k) end

  G.on_record_click()
  for _ = 1, 3 do
    for k = 1, 12 do H.damage_out({ hit = 100 * (13 - k), ability_id = 8000 + k }) end
    H.advance(1000)
  end
  G.on_stop_click()
  while view_label._text ~= "CONTRIB" do G.next_view() end

  local rows, n = CV.rows()
  ok(n == 12, "twelve contributions, got " .. tostring(n))
  local labels = visible_labels()
  ok(has(labels, "Skill 01"), "the top row shows the biggest skill")
  ok(not has(labels, "Skill 12"), "the smallest skill does not fit at the default size")
  local off, max_off = CV.scroll_state()
  ok(off == 0 and max_off > 0, "the list starts at the top with room to scroll, max " .. tostring(max_off))
  ok(find_prefix(labels, "+") ~= nil, "the overflow line reads +N more")

  hit._onOnMouseWheel(hit, -1)
  labels = visible_labels()
  off = CV.scroll_state()
  ok(off == 1, "one wheel notch scrolls one row, got " .. tostring(off))
  ok(not has(labels, "Skill 01") and has(labels, "Skill 02"), "the first row scrolled out of view")
  ok(find_prefix(labels, "1 above") ~= nil, "the overflow line counts the rows above")

  for _ = 1, 30 do hit._onOnMouseWheel(hit, -1) end
  off = CV.scroll_state()
  ok(off == max_off, "scrolling stops at the end")
  ok(has(visible_labels(), "Skill 12"), "the last row is reachable")
  for _ = 1, 30 do hit._onOnMouseWheel(hit, 1) end
  ok(CV.scroll_state() == 0 and has(visible_labels(), "Skill 01"), "scrolling back returns to the top")

  hit._onOnMouseWheel(hit, -1)
  G.next_view()
  G.prev_view()
  ok(CV.scroll_state() == 0, "leaving and returning resets the scroll")

  G.on_flush_click()
  while view_label._text ~= "SKILL" do G.next_view() end
  VermilionGraphWindow:SetDimensions(w0, h0)
  canvas:SetDimensions(cw0, ch0)
  G.on_resize_stop()
  H.ability_names = nil
  Vermilion.Visibility.set("graph", false)
  Vermilion.Metrics.reset()
end
