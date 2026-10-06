return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G, Cst, SS = Vermilion.Graph, Vermilion.Casts, Vermilion.SessionStore
  local sv = Vermilion.SavedVars
  sv.settings = sv.settings or {}
  local before_auto = sv.settings.session_autosave

  Vermilion.Metrics.reset()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  local view_label = VermilionGraphWindowViewLabel
  while view_label._text ~= "SKILL" do G.next_view() end

  local MAGF, STAF = COMBAT_MECHANIC_FLAGS_MAGICKA, COMBAT_MECHANIC_FLAGS_STAMINA
  H.slotted = {
    [HOTBAR_CATEGORY_PRIMARY] = { [3] = 501, [4] = 502, [5] = 503, [6] = 504, [8] = 41001 },
    [HOTBAR_CATEGORY_BACKUP]  = { [3] = 601 },
  }
  H.ability_costs = {
    [501] = { base = 2700, flags = MAGF, cost = { [MAGF] = 2500 } },
    [502] = { base = 2200, flags = STAF, cost = { [STAF] = 2200 } },
    [503] = { base = 0, flags = 0 },
    [601] = { base = 3100, flags = MAGF, cost = {} },
  }
  H.skill_costs = {
    [HOTBAR_CATEGORY_PRIMARY] = { [6] = { [STAF] = 1800 } },
    [HOTBAR_CATEGORY_BACKUP]  = { [3] = { [MAGF] = 4300 } },
  }
  H.state.active_bar = HOTBAR_CATEGORY_PRIMARY
  H.ability_names = H.ability_names or {}
  H.ability_names[501], H.ability_names[502], H.ability_names[503], H.ability_names[504], H.ability_names[601] = "Crushing Shock", "Rending Slashes", "Free Proc", "Old Skill", "Elemental Blockade"

  H.skill_used(3)
  ok(Cst.count() == 0, "casts outside a recording are not kept")

  sv.settings.session_autosave = true
  sv.library = { version = 1, sessions = {} }
  G.on_record_click()
  H.skill_used(3); H.skill_used(4); H.skill_used(5); H.skill_used(3)
  H.skill_used(8)
  H.skill_used(1)
  H.skill_used(6)
  H.state.active_bar = HOTBAR_CATEGORY_BACKUP
  H.skill_used(3)
  H.state.active_bar = HOTBAR_CATEGORY_PRIMARY
  local t, id, pool, cost, n = Cst.records()
  ok(n == 6, "six skill casts recorded, the ultimate and the first slot ignored, got " .. n)
  ok(id[1] == 501 and pool[1] == 1 and cost[1] == 2500, "a magicka skill takes its pool from the mechanic mask and its real cost from the game, got pool " .. tostring(pool[1]) .. " cost " .. tostring(cost[1]))
  ok(id[2] == 502 and pool[2] == 2 and cost[2] == 2200, "a stamina skill carries its stamina cost")
  ok(id[3] == 503 and pool[3] == 0 and cost[3] == 0, "a free cast is kept with no pool")
  ok(id[5] == 504 and pool[5] == 2 and cost[5] == 1800, "without base cost info the slot cost per mechanic decides, got pool " .. tostring(pool[5]) .. " cost " .. tostring(cost[5]))
  ok(id[6] == 601 and pool[6] == 1 and cost[6] == 4300, "when the ability cost is unknown the back bar's slot cost fills in, got " .. tostring(cost[6]))
  H.damage_out({ hit = 1000, ability_id = 501 })
  H.advance(1000)
  local top, tc = Cst.spend_top(0, t[n] + 1, 1)
  ok(top == 501 and tc == 5000, "the top magicka spender over a window sums its casts, got " .. tostring(top) .. " " .. tostring(tc))
  local top_s, tcs = Cst.spend_top(0, t[n] + 1, 2)
  ok(top_s == 502 and tcs == 2200, "the stamina side ranks on its own")

  local lines = Cst.probe_lines()
  ok(#lines >= 7 and lines[2]:find("Crushing Shock", 1, true) and lines[2]:find("pool=1 cost=2500", 1, true), "the probe lists the slotted skills with the pool and cost the recorder would take, got " .. tostring(lines[2]))

  for _ = 1, 600 do H.skill_used(3) end
  local alloc = H.addon_alloc(function()
    for _ = 1, 200 do H.skill_used(3) end
  end)
  ok(alloc < (HARNESS_DEBUG and 40000 or 64), string.format("two hundred casts into warm arrays allocate %.0f addon-side bytes", alloc))
  ok(Cst.count() == 806, "every cast was kept, got " .. Cst.count())

  G.on_stop_click()
  H.advance(500)
  ok(SS.count() == 1, "the session saved")
  local sess = SS.get(1)
  ok(sess.desc.casts and sess.streams.casts, "the session carries a casts stream")
  G.on_flush_click()
  ok(Cst.count() == 0, "flush clears the casts")
  ok(G.load_session(sess), "the session loads back")
  local t2, id2, pool2, cost2, n2 = Cst.records()
  ok(n2 == 806 and id2[1] == 501 and cost2[1] == 2500 and pool2[2] == 2 and pool2[3] == 0 and cost2[6] == 4300, "casts survive the round trip with costs above 4095, got " .. n2 .. " and " .. tostring(cost2[6]))
  ok(t2[1] >= 0 and t2[1] <= 1000, "cast times are relative to the session start, got " .. tostring(t2[1]))

  G.on_flush_click()
  H.slotted, H.skill_costs, H.ability_costs, H.state.active_bar = nil, nil, nil, nil
  sv.settings.session_autosave = before_auto
end
