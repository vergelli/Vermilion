return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G, R, SS = Vermilion.Graph, Vermilion.Restores, Vermilion.SessionStore
  local sv = Vermilion.SavedVars
  sv.settings = sv.settings or {}
  local before_auto = sv.settings.session_autosave

  Vermilion.Metrics.reset()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  local view_label = VermilionGraphWindowViewLabel
  while view_label._text ~= "SKILL" do G.next_view() end

  H.state.stats = { [STAT_MAGICKA_REGEN_COMBAT] = 953, [STAT_STAMINA_REGEN_COMBAT] = 1210 }
  H.ability_names = H.ability_names or {}
  H.ability_names[701], H.ability_names[702] = "Heavy Attack", "Essence of Magicka"

  H.energize({ ability_id = 701, amount = 3240, pool = COMBAT_MECHANIC_FLAGS_MAGICKA })
  ok(R.count() == 0, "restores outside a recording are not kept")

  sv.settings.session_autosave = true
  sv.library = { version = 1, sessions = {} }
  G.on_record_click()
  ok(R.regen(1) == 953 and R.regen(2) == 1210, "the recovery per tick is read from the stats when the recording starts, got " .. tostring(R.regen(1)) .. " " .. tostring(R.regen(2)))
  H.energize({ ability_id = 701, amount = 3240, pool = COMBAT_MECHANIC_FLAGS_MAGICKA })
  H.advance(1000)
  H.energize({ ability_id = 702, amount = 7500, pool = COMBAT_MECHANIC_FLAGS_MAGICKA })
  H.energize({ ability_id = 701, amount = 2900, pool = COMBAT_MECHANIC_FLAGS_STAMINA })
  H.energize({ ability_id = 703, amount = 999, pool = COMBAT_MECHANIC_FLAGS_MAGICKA, target_type = COMBAT_UNIT_TYPE_GROUP })
  H.energize({ ability_id = 704, amount = 500, pool = COMBAT_MECHANIC_FLAGS_HEALTH or 99 })
  H.damage_out({ hit = 1000, ability_id = 501 })
  H.advance(1000)
  local t, id, pool, amt, n = R.records()
  ok(n == 3, "three restores to the player kept, another unit's and a health restore ignored, got " .. n)
  ok(id[1] == 701 and pool[1] == 1 and amt[1] == 3240, "a magicka restore carries its source and amount")
  ok(id[3] == 701 and pool[3] == 2 and amt[3] == 2900, "the pool comes from the event's power type")
  local top, ta = R.top(0, t[n] + 1, 1)
  ok(top == 702 and ta == 7500, "the top magicka restorer over a window is the potion, got " .. tostring(top) .. " " .. tostring(ta))
  ok(R.sum(1) == 10740 and R.sum(2) == 2900, "sums per pool add up, got " .. R.sum(1) .. " " .. R.sum(2))

  for _ = 1, 600 do H.energize({ ability_id = 701, amount = 100 }) end
  local alloc = H.addon_alloc(function()
    for _ = 1, 200 do H.energize({ ability_id = 701, amount = 100 }) end
  end)
  ok(alloc < (HARNESS_DEBUG and 40000 or 64), string.format("two hundred restores into warm arrays allocate %.0f addon-side bytes", alloc))

  G.on_stop_click()
  H.advance(500)
  ok(SS.count() == 1, "the session saved")
  local sess = SS.get(1)
  ok(sess.desc.restores and sess.streams.restores, "the session carries a restores stream")
  ok(sess.head.regen and sess.head.regen.mag == 953 and sess.head.regen.sta == 1210, "the session head keeps the recovery per tick")
  G.on_flush_click()
  ok(R.count() == 0 and R.regen(1) == 0, "flush clears the restores and the regen")
  ok(G.load_session(sess), "the session loads back")
  local _, id2, pool2, amt2, n2 = R.records()
  ok(n2 == 803 and id2[2] == 702 and amt2[2] == 7500 and pool2[3] == 2, "restores survive the round trip, got " .. n2)
  ok(R.regen(1) == 953, "the regen comes back with the session, got " .. tostring(R.regen(1)))

  G.on_flush_click()
  H.state.stats = nil
  sv.settings.session_autosave = before_auto
end
