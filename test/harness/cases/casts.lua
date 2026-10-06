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

  H.slotted = {
    [HOTBAR_CATEGORY_PRIMARY] = { [3] = 501, [4] = 502, [5] = 503, [8] = 41001 },
    [HOTBAR_CATEGORY_BACKUP]  = { [3] = 601 },
  }
  H.skill_costs = {
    [HOTBAR_CATEGORY_PRIMARY] = { [3] = { [COMBAT_MECHANIC_FLAGS_MAGICKA] = 2700 }, [4] = { [COMBAT_MECHANIC_FLAGS_STAMINA] = 2200 }, [5] = {} },
    [HOTBAR_CATEGORY_BACKUP]  = { [3] = { [COMBAT_MECHANIC_FLAGS_MAGICKA] = 3100 } },
  }
  H.state.active_bar = HOTBAR_CATEGORY_PRIMARY
  H.ability_names = H.ability_names or {}
  H.ability_names[501], H.ability_names[502], H.ability_names[503], H.ability_names[601] = "Crushing Shock", "Rending Slashes", "Free Proc", "Elemental Blockade"

  H.skill_used(3)
  ok(Cst.count() == 0, "casts outside a recording are not kept")

  sv.settings.session_autosave = true
  sv.library = { version = 1, sessions = {} }
  G.on_record_click()
  H.skill_used(3); H.skill_used(4); H.skill_used(5); H.skill_used(3)
  H.skill_used(8)
  H.skill_used(1)
  H.state.active_bar = HOTBAR_CATEGORY_BACKUP
  H.skill_used(3)
  H.state.active_bar = HOTBAR_CATEGORY_PRIMARY
  local t, id, pool, cost, n = Cst.records()
  ok(n == 5, "five skill casts recorded, the ultimate and the first slot ignored, got " .. n)
  ok(id[1] == 501 and pool[1] == 1 and cost[1] == 2700, "a magicka skill is keyed to its ability with its magicka cost")
  ok(id[2] == 502 and pool[2] == 2 and cost[2] == 2200, "a stamina skill carries its stamina cost")
  ok(id[3] == 503 and pool[3] == 0 and cost[3] == 0, "a free cast is kept with no pool")
  ok(id[5] == 601 and cost[5] == 3100, "the back bar resolves its own ability and cost")
  H.damage_out({ hit = 1000, ability_id = 501 })
  H.advance(1000)
  local top, tc = Cst.spend_top(0, t[n] + 1, 1)
  ok(top == 501 and tc == 5400, "the top magicka spender over a window sums its casts, got " .. tostring(top) .. " " .. tostring(tc))
  local top_s, tcs = Cst.spend_top(0, t[n] + 1, 2)
  ok(top_s == 502 and tcs == 2200, "the stamina side ranks on its own")

  for _ = 1, 600 do H.skill_used(3) end
  local alloc = H.addon_alloc(function()
    for _ = 1, 200 do H.skill_used(3) end
  end)
  ok(alloc < (HARNESS_DEBUG and 40000 or 64), string.format("two hundred casts into warm arrays allocate %.0f addon-side bytes", alloc))
  ok(Cst.count() == 805, "every cast was kept, got " .. Cst.count())

  G.on_stop_click()
  H.advance(500)
  ok(SS.count() == 1, "the session saved")
  local sess = SS.get(1)
  ok(sess.desc.casts and sess.streams.casts, "the session carries a casts stream")
  G.on_flush_click()
  ok(Cst.count() == 0, "flush clears the casts")
  ok(G.load_session(sess), "the session loads back")
  local t2, id2, pool2, cost2, n2 = Cst.records()
  ok(n2 == 805 and id2[1] == 501 and cost2[1] == 2700 and pool2[2] == 2 and pool2[3] == 0, "casts survive the round trip, got " .. n2)
  ok(t2[1] >= 0 and t2[1] <= 1000, "cast times are relative to the session start, got " .. tostring(t2[1]))

  G.on_flush_click()
  H.slotted, H.skill_costs, H.state.active_bar = nil, nil, nil
  sv.settings.session_autosave = before_auto
end
