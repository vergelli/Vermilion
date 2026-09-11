return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G = Vermilion.Graph
  local label = VermilionGraphWindowViewLabel

  Vermilion.Metrics.reset()
  Vermilion.Visibility.set("graph", true)
  ok(VermilionGraphWindow._hidden == false, "the graph shows on demand")
  G.on_flush_click()
  ok(VermilionGraphWindowViewportNoDataLabel._hidden == false, "an empty graph shows the no-data text")

  G.on_record_click()
  for _ = 1, 6 do
    H.damage_out({ hit = 1200, ability_id = 31 })
    H.damage_out({ hit = 400, ability_id = 33, damage_type = DAMAGE_TYPE_SHOCK })
    H.advance(1000)
  end
  G.on_stop_click()
  ok(VermilionGraphWindowViewportNoDataLabel._hidden == true, "data hides the no-data text")

  local seen = {}
  local start = label._text
  for _ = 1, 6 do
    seen[label._text] = true
    G.next_view()
  end
  ok(label._text == start, "six steps forward come back to the first view")
  local n = 0
  for _ in pairs(seen) do n = n + 1 end
  ok(n == 6, "six distinct views cycle, got " .. n)
  ok(seen["SKILL"] and seen["TYPE"] and seen["TARGETS"] and seen["CRIT"] and seen["CONTRIB"] and seen["DEBUFFS"], "the views are SKILL, TYPE, TARGETS, CRIT, CONTRIB and DEBUFFS")

  G.prev_view()
  local back = label._text
  G.next_view()
  ok(label._text == start and back ~= start, "previous view steps back")

  G.on_flush_click()
  Vermilion.Visibility.set("graph", false)
  ok(VermilionGraphWindow._hidden == true, "the graph hides on demand")
  Vermilion.Metrics.reset()
end
