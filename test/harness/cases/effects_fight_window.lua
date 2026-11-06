return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G, M, DT, UV = Vermilion.Graph, Vermilion.Metrics, Vermilion.DebuffTracker, Vermilion.UptimeView
  H.ability_names = H.ability_names or {}
  local ID, LATE = 6201, 6202
  H.ability_names[ID], H.ability_names[LATE] = "Window Bleed", "Late Bleed"

  M.reset()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  G.on_record_click()

  local function effect(change, id, ends_in)
    local t = H.now()
    DT.on_effect(change, id, 900, (t + ends_in) / 1000, t, "reticleover", BUFF_EFFECT_TYPE_DEBUFF)
    Vermilion.Uptime.on_effect(change, id, 900, t / 1000, (t + ends_in) / 1000, t, "reticleover", BUFF_EFFECT_TYPE_DEBUFF, H.ability_names[id])
  end
  local function row_of(name)
    local order, n, rows = UV.compute()
    for i = 1, n do
      local r = rows[order[i]]
      if r.name == name then return r end
    end
  end

  effect(EFFECT_RESULT_GAINED, ID, 30000)
  H.advance(4000)
  H.damage_out({ hit = 1000, ability_id = 31, target_unit_id = 900 })
  H.advance(10000)
  H.damage_out({ hit = 1000, ability_id = 31, target_unit_id = 900 })
  ok(M.fight_ms() == 10000, "the fight is ten seconds, got " .. M.fight_ms())
  H.advance(1000)
  effect(EFFECT_RESULT_GAINED, LATE, 2000)
  H.advance(3000)
  effect(EFFECT_RESULT_FADED, LATE, 0)
  effect(EFFECT_RESULT_FADED, ID, 0)
  H.advance(1000)
  G.on_stop_click()

  local function check(label)
    local r = row_of("Window Bleed")
    ok(r, label .. ": the row exists")
    ok(r.covered == 10000, label .. ": only the fight counts, got " .. r.covered)
    ok(r.uptime == 1, label .. ": all of it, got " .. r.uptime)
    ok(r.apps == 1, label .. ": one application, got " .. r.apps)
    ok(r.down == 0, label .. ": nothing lost, got " .. r.down)
    local late = row_of("Late Bleed")
    if late then
      ok(late.covered == 0, label .. ": what starts after the last hit is not part of the fight, got " .. late.covered)
      ok(late.apps == 0, label .. ": and is not an application, got " .. late.apps)
    end
  end
  check("live")

  local found = {}
  for i = 1, DT.count() do
    local d = DT.get(i)
    found[d.name] = d
  end
  ok(found["Window Bleed"] and found["Window Bleed"].uptime_ms == 10000, "debuffs count the fight too, got " .. tostring(found["Window Bleed"] and found["Window Bleed"].uptime_ms))
  ok(DT.uptime_of(found["Window Bleed"]) == 1, "so the share is whole")
  ok(found["Window Bleed"].longest_gap_ms == 0, "no gap inside the fight, got " .. found["Window Bleed"].longest_gap_ms)
  if found["Late Bleed"] then
    ok(found["Late Bleed"].uptime_ms == 0, "a debuff after the last hit adds nothing, got " .. found["Late Bleed"].uptime_ms)
  end

  local sess = Vermilion.SessionStore.capture()
  G.on_flush_click()
  ok(G.load_session(sess), "the session reloads")
  check("loaded")

  G.on_flush_click()
  Vermilion.Visibility.set("graph", false)
  M.reset()
end
