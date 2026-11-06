return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G, SS = Vermilion.Graph, Vermilion.SessionStore

  local function bars()
    local out = {}
    for i = 1, 400 do
      local b = rawget(_G, "VermilionFilmStripBar" .. i)
      if b and b._hidden == false then out[#out + 1] = tostring(b._h) end
    end
    return table.concat(out, ",")
  end
  local function fight(shape)
    G.on_flush_click()
    G.on_record_click()
    for i = 1, 24 do
      H.damage_out({ hit = shape(i), ability_id = 31, target_unit_id = 900 })
      H.advance(1000)
    end
    G.on_stop_click()
    G.on_save_click()
    H.advance(400)
    return SS.get(SS.count())
  end

  Vermilion.Metrics.reset()
  Vermilion.Visibility.set("graph", true)
  while VermilionGraphWindowViewLabel._text ~= "SKILL" do G.next_view() end
  local rising = fight(function(i) return i * 500 end)
  local falling = fight(function(i) return (25 - i) * 500 end)
  ok(rising.head.dur_ms == falling.head.dur_ms, "both fights last the same")

  ok(G.load_session(rising), "the first session opens")
  local first = bars()
  ok(first ~= "", "the film strip draws it")
  ok(G.load_session(falling), "the second session opens")
  local second = bars()
  ok(second ~= first, "the film strip draws the second one, got the same bars as the first: " .. second)
  ok(G.load_session(rising), "the first opens again")
  ok(bars() == first, "and its film strip comes back, got " .. bars())

  G.on_flush_click()
  Vermilion.Visibility.set("graph", false)
  Vermilion.Metrics.reset()
end
