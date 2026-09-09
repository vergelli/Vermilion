return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local function eq(a, b, msg)
    if a ~= b then error(msg .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")", 2) end
  end
  local D = BUFF_EFFECT_TYPE_DEBUFF
  local BT = Vermilion.DebuffTracker
  local G = Vermilion.Graph
  Vermilion.Metrics.reset()
  Vermilion.TemporalBuffer.clear()
  G.on_flush_click()

  H.effect(EFFECT_RESULT_GAINED, 111, 600, 0, nil, "reticleover", D)
  eq(BT.count(), 0, "must not track outside a recording")

  G.on_record_click()
  local t0 = H.now()

  H.effect(EFFECT_RESULT_GAINED, 111, 600, 0, nil, "reticleover", D)
  H.advance(2000)
  H.effect(EFFECT_RESULT_GAINED, 111, 601, 0, nil, "boss1", D)
  H.advance(2000)
  H.effect(EFFECT_RESULT_FADED, 111, 600, 0, nil, "reticleover", D)
  H.advance(2000)
  H.effect(EFFECT_RESULT_FADED, 111, 601, 0, nil, "boss1", D)
  H.advance(1000)
  H.effect(EFFECT_RESULT_GAINED, 111, 600, 0, nil, "reticleover", D)
  H.advance(1000)
  H.effect(EFFECT_RESULT_FADED, 111, 600, 0, nil, "reticleover", D)

  H.effect(EFFECT_RESULT_GAINED, 222, 600, (H.now() + 2000) / 1000, nil, "reticleover", D)
  H.effect(EFFECT_RESULT_GAINED, 333, 600, 0, nil, "reticleover", BUFF_EFFECT_TYPE_BUFF)
  H.effect(EFFECT_RESULT_GAINED, 444, 700, 0, nil, "group2", D)
  H.effect(EFFECT_RESULT_GAINED, 555, 500, 0, nil, "player", D)
  H.effect(EFFECT_RESULT_GAINED, 666, 600, 0, COMBAT_UNIT_TYPE_OTHER, "reticleover", D)
  H.advance(4000)

  G.on_stop_click()

  eq(BT.count(), 2, "tracked debuff count")

  local rec1
  BT.iterate(function(_, rec) if rec.id == 111 then rec1 = rec end end)
  ok(rec1, "debuff 111 not tracked")
  eq(rec1.n_iv, 2, "union interval count for 111")
  eq(rec1.uptime_ms, 7000, "union uptime for 111")
  eq(rec1.applications, 3, "application count for 111")
  eq(rec1.unique_units, 2, "unique targets for 111")
  eq(rec1.max_conc, 2, "max concurrency for 111")
  eq(BT.concurrency_at(rec1, t0 + 3000), 2, "concurrency at t0+3s")
  eq(BT.concurrency_at(rec1, t0 + 5000), 1, "concurrency at t0+5s")
  ok(math.abs(BT.avg_concurrency(rec1) - (2000 * 1 + 2000 * 2 + 2000 * 1 + 1000 * 1) / 7000) < 1e-6, "average concurrency weighs the steps")

  local rec2
  BT.iterate(function(_, rec) if rec.id == 222 then rec2 = rec end end)
  ok(rec2, "debuff 222 not tracked")
  eq(rec2.n_iv, 1, "watchdog must have closed 222")
  ok(rec2.uptime_ms >= 1500 and rec2.uptime_ms <= 3000, "watchdog uptime for 222 out of range: " .. rec2.uptime_ms)

  local names = {}
  BT.iterate(function(_, r) names[r.id] = true end)
  ok(not names[333], "a buff on an enemy is not a debuff")
  ok(not names[444], "an effect on a group member is never a debuff of the player")
  ok(not names[555], "an effect on the player is never a debuff of the player")
  ok(not names[666], "a debuff another source applied never shows")

  local lines = BT.report_lines()
  ok(#lines >= 3, "report_lines too short")
  local excluded_line = false
  for _, l in ipairs(lines) do if l:find("not a debuff", 1, true) then excluded_line = true end end
  ok(excluded_line, "the report explains the buff exclusion")
  if Vermilion.Constants.DEBUG then
    ok(Vermilion.Diagnostics.get("debuffs.expired_watchdog") >= 1, "watchdog counter missing")
    ok(Vermilion.Diagnostics.get("debuffs.skipped_friendly") >= 2, "friendly counter missing")
  end

  H.ability_names = { [777] = "Twin Debuff", [778] = "Twin Debuff" }
  G.on_record_click()
  eq(BT.count(), 0, "new session must reset tracked debuffs")
  ok(BT.is_recording(), "tracker must follow recording state")
  H.effect(EFFECT_RESULT_GAINED, 777, 600, 0, nil, "reticleover", D)
  H.effect(EFFECT_RESULT_GAINED, 778, 601, 0, nil, "boss1", D)
  H.advance(1000)
  G.on_stop_click()
  eq(BT.count(), 1, "two ability ids with one name merge into one debuff")
  eq(BT.get(1).max_conc, 2, "the merged debuff counts both targets")
  H.ability_names = nil

  H.skill_keys = { [810] = {2, 4, 6}, [40095] = {1, 2, 3}, [811] = {0, 0, 0} }
  H.slotted = { [HOTBAR_CATEGORY_PRIMARY] = { [3] = 40095 } }
  H.passive_ids = { [830] = true }
  H.ability_names = { [810] = "Blockade Effect", [40095] = "Elemental Mock", [812] = "Elemental Mock",
                      [811] = "Sentinel Snare", [820] = "Major Breach", [830] = "Passive Mock", [840] = "Swappy", [40097] = "Swappy" }
  G.on_record_click()
  H.effect(EFFECT_RESULT_GAINED, 810, 600, 0, nil, "reticleover", D)
  H.effect(EFFECT_RESULT_GAINED, 812, 600, 0, nil, "reticleover", D)
  H.effect(EFFECT_RESULT_GAINED, 811, 600, 0, nil, "reticleover", D)
  H.effect(EFFECT_RESULT_GAINED, 820, 600, 0, nil, "reticleover", D)
  H.effect(EFFECT_RESULT_GAINED, 830, 600, 0, nil, "reticleover", D)
  H.effect(EFFECT_RESULT_GAINED, 840, 600, 0, nil, "reticleover", D)
  H.advance(1000)
  local by_name = {}
  BT.iterate(function(_, r) by_name[r.name] = r end)
  ok(by_name["Blockade Effect"] == nil, "an effect that belongs to a skill in the tree is not a debuff of the view")
  ok(by_name["Elemental Mock"] == nil, "an effect named like a slotted ability is excluded")
  ok(by_name["Sentinel Snare"], "zero-key sentinel ids never match a skill")
  ok(by_name["Major Breach"], "a named debuff stays")
  ok(by_name["Passive Mock"] == nil, "passives are excluded")
  ok(by_name["Swappy"], "an effect tracks before the bar swap")
  H.slotted[HOTBAR_CATEGORY_PRIMARY][5] = 40097
  H.fire(EVENT_ACTIVE_WEAPON_PAIR_CHANGED, 1, true)
  by_name = {}
  BT.iterate(function(_, r) by_name[r.name] = r end)
  ok(by_name["Swappy"] == nil, "a bar swap rescan purges matching rows retroactively")
  H.effect(EFFECT_RESULT_GAINED, 840, 600, 0, nil, "reticleover", D)
  by_name = {}
  BT.iterate(function(_, r) by_name[r.name] = r end)
  ok(by_name["Swappy"] == nil, "a re-gained skill effect stays excluded after the purge")
  G.on_stop_click()
  local skill_line, slot_line, purge_line, filter_line = false, false, false, false
  for _, l in ipairs(BT.report_lines()) do
    if l:find("skill effect", 1, true) then skill_line = true end
    if l:find("slotted ability", 1, true) then slot_line = true end
    if l:find("bar swap rescan", 1, true) then purge_line = true end
    if l:find("slotted filter: Elemental Mock", 1, true) then filter_line = true end
  end
  ok(skill_line and slot_line and purge_line and filter_line, "the report explains every exclusion and lists the slotted filter")
  H.skill_keys, H.slotted, H.passive_ids, H.ability_names = nil, nil, nil, nil

  G.on_flush_click()
  eq(BT.count(), 0, "flush must clear tracker")
  Vermilion.Metrics.reset()
end
