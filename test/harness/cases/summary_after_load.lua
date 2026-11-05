return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G, SS, DN, TB = Vermilion.Graph, Vermilion.SessionStore, Vermilion.DamageNames, Vermilion.TemporalBuffer
  H.ability_names = H.ability_names or {}
  H.ability_names[6101], H.ability_names[6102] = "Weak Strike", "Strong Strike"

  Vermilion.Metrics.reset()
  Vermilion.Visibility.set("graph", true)

  local function fight(hit, ability, critical)
    G.on_flush_click()
    G.on_record_click()
    for _ = 1, 12 do
      H.damage_out({ hit = hit, ability_id = ability, target_unit_id = 900, critical = critical })
      H.advance(1000)
    end
    G.on_stop_click()
    return SS.capture()
  end

  local weak = fight(1000, 6101)
  local strong = fight(90000, 6102)

  local function chip()
    return VermilionGraphSummaryLabel._text or ""
  end
  local function expect_avg(sess, label)
    local got = G.export_summary().avg
    local want = sess.head.sum.total_damage / (sess.head.sum.fight_ms / 1000)
    ok(math.abs(got - want) < 1, label .. ": the summary reads this session, got " .. tostring(got))
  end

  G.on_flush_click()
  ok(G.load_session(weak), "the weak session loads")
  expect_avg(weak, "weak")
  local weak_chip = chip()
  ok(G.load_session(strong), "the strong session loads")
  expect_avg(strong, "strong")
  local strong_chip = chip()
  ok(weak_chip ~= "" and strong_chip ~= "", "both show the header")
  ok(weak_chip ~= strong_chip, "each session has its own header, got " .. weak_chip)

  ok(G.load_session(weak), "going back loads the weak one")
  ok(chip() == weak_chip, "the header is the same as the first time, not the one of the session before it, got " .. chip() .. " and " .. weak_chip)
  ok(G.load_session(weak), "loading it twice")
  ok(chip() == weak_chip, "changes nothing")
  ok(G.load_session(strong), "and forward again")
  ok(chip() == strong_chip, "gives its own header back")

  ok(G.load_session(weak), "the weak one again")
  local names = DN.by_name(TB)
  ok(names["Weak Strike"] == weak.head.sum.total_damage, "the damage by skill reads this session")
  ok(names["Strong Strike"] == nil, "and nothing of the one before, even with the same number of samples")

  G.on_flush_click()
  ok(chip() == "" or VermilionGraphSummaryLabel._hidden == true, "a flush takes the header away")
  Vermilion.Visibility.set("graph", false)
  Vermilion.Metrics.reset()
end
