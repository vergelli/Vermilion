return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G, M, TB = Vermilion.Graph, Vermilion.Metrics, Vermilion.TemporalBuffer

  M.reset()
  Vermilion.Visibility.set("graph", true)

  local function steady(seconds)
    for _ = 1, seconds do
      H.damage_out({ hit = 1000, ability_id = 31, target_unit_id = 900 })
      H.advance(1000)
    end
  end
  local function bands()
    local out = {}
    for _, c in ipairs(H.controls) do
      if c._hidden == false and (c._name or ""):find("^VermilionDeadBand") then out[#out + 1] = c end
    end
    return out
  end
  local function show(name)
    while VermilionGraphWindowViewLabel._text ~= name do G.next_view() end
    G.rerender()
  end

  G.on_flush_click()
  G.on_record_click()
  steady(30)
  G.on_stop_click()
  show("SKILL")
  ok(#bands() == 0, "no death, no band, got " .. #bands())

  G.on_flush_click()
  G.on_record_click()
  steady(20)
  H.death(true)
  H.advance(20000)
  H.death(false)
  steady(20)
  H.death(true)
  H.advance(10000)
  H.death(false)
  steady(20)
  G.on_stop_click()

  local function check(label)
    for _, view in ipairs({ "SKILL", "TYPE", "CRIT" }) do
      show(view)
      local b = bands()
      ok(#b == 2, label .. ": view " .. view .. " paints one band per death, got " .. #b)
      local cw = VermilionGraphWindowViewportCanvas:GetWidth()
      local long, short = b[1]._w, b[2]._w
      if long < short then long, short = short, long end
      ok(long > short, label .. ": the longer death has the wider band, got " .. long .. " and " .. short)
      ok(long / cw > 0.15 and long / cw < 0.35, label .. ": twenty seconds of ninety, got " .. long .. " of " .. cw)
      ok(b[1]._h > 0, label .. ": the band has height")
      ok(b[1]._a and b[1]._a < 0.3, label .. ": it stays soft so the bars read through it")
    end
    show("PRESSURE")
    ok(#bands() == 0, label .. ": Pressure has no band, and switching to it leaves nothing behind, got " .. #bands())
    show("RESOURCES")
    ok(#bands() == 0, label .. ": neither has Resources, got " .. #bands())
    show("SKILL")
  end
  check("live")

  local sess = Vermilion.SessionStore.capture()
  G.on_flush_click()
  ok(#bands() == 0, "a flush clears the bands, got " .. #bands())
  ok(G.load_session(sess), "the session reloads")
  check("loaded")

  local alloc = H.addon_alloc(function()
    for _ = 1, 20 do G.rerender() end
  end)
  ok(alloc < (HARNESS_DEBUG and 400000 or 120000), string.format("twenty renders allocate %.0f bytes", alloc))

  G.on_flush_click()
  Vermilion.Visibility.set("graph", false)
  M.reset()
end
