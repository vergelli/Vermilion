return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local DT, U = Vermilion.DebuffTracker, Vermilion.Uptime
  local GAIN, FADE, UPD = EFFECT_RESULT_GAINED, EFFECT_RESULT_FADED, EFFECT_RESULT_UPDATED
  local DEBUFF = BUFF_EFFECT_TYPE_DEBUFF

  local function send(change, id, name, unit, begin_ms, end_ms, tag)
    local t = H.now()
    DT.on_effect(change, id, unit, end_ms / 1000, t, tag or "reticleover", DEBUFF)
    U.on_effect(change, id, unit, begin_ms / 1000, end_ms / 1000, t, tag or "reticleover", DEBUFF, name)
  end
  local function find(name)
    for i = 1, DT.count() do
      local r = DT.get(i)
      if r.name == name then return r end
    end
  end

  DT.reset()
  U.reset()
  DT.start_session(H.now())
  U.start_session(H.now())
  local SC = Vermilion.SkillColors
  local real = SC.ability_name
  SC.ability_name = function(id)
    if id == 501 then return "Burn" elseif id == 601 or id == 602 then return "Trap" end
    return real(id)
  end

  local t0 = H.now()
  send(GAIN, 501, "Burn", 7, t0, t0 + 4000)
  send(GAIN, 501, "Burn", 7, t0, t0 + 4000, "reticleoverplayer")
  send(UPD, 501, "Burn", 7, t0, t0 + 4000)
  send(UPD, 501, "Burn", 7, t0, t0 + 4000, "reticleoverplayer")
  send(GAIN, 601, "Trap", 7, t0, t0 + 20000)
  send(GAIN, 602, "Trap", 7, t0, t0 + 2000)
  send(UPD, 602, "Trap", 7, t0, t0 + 2000)
  H.advance(2000)
  local t2 = H.now()
  send(FADE, 602, "Trap", 7, t2, t2)
  H.advance(2000)
  local t4 = H.now()
  send(FADE, 501, "Burn", 7, t4, t4)
  send(FADE, 501, "Burn", 7, t4, t4, "reticleoverplayer")
  send(UPD, 501, "Burn", 7, t4, t4)
  H.advance(16000)
  local t20 = H.now()
  send(FADE, 601, "Trap", 7, t20, t20)
  DT.finalize(t20)
  U.finalize(t20)

  local burn, trap = find("Burn"), find("Trap")
  ok(burn, "Burn is tracked")
  ok(burn.uptime_ms == 4000, "a fade closes the effect now, however many echoes came before, got " .. tostring(burn.uptime_ms))
  ok(burn.applications == 1, "one application, not one per tag, got " .. tostring(burn.applications))
  ok(trap.uptime_ms == 20000, "two ids under one name stay open until the last one fades, got " .. tostring(trap.uptime_ms))
  ok(trap.applications == 1, "two ids in one cast are one application, got " .. tostring(trap.applications))

  local sk, _, st0, st1, sn = U.spans()
  local dur = {}
  local count = {}
  local names = U.keys()
  for i = 1, sn do
    local nm = names[sk[i]]
    dur[nm] = (dur[nm] or 0) + (st1[i] - st0[i])
    count[nm] = (count[nm] or 0) + 1
  end
  ok(dur["Burn"] == 4000 and count["Burn"] == 1, "Uptime reads one span of 4 s for Burn, got " .. tostring(dur["Burn"]) .. " in " .. tostring(count["Burn"]))
  ok(dur["Trap"] == 20000 and count["Trap"] == 1, "Uptime follows the longest id of Trap, got " .. tostring(dur["Trap"]) .. " in " .. tostring(count["Trap"]))

  U.reset()
  U.start_session(H.now())
  local ts = H.now()
  U.on_effect(GAIN, 701, 9, ts / 1000, (ts + 20000) / 1000, ts, "reticleoverplayer", 1, "Ally Buff")
  U.on_effect(GAIN, 701, 9, ts / 1000, (ts + 20000) / 1000, ts, "group1", 1, "Ally Buff")
  H.advance(1000)
  local t1 = H.now()
  U.on_effect(GAIN, 702, 9, t1 / 1000, (t1 + 20000) / 1000, t1, "reticleoverplayer", 1, "Ally Buff 2")
  local o_n = select(5, U.open_spans())
  ok(o_n == 0, "a buff on a groupmate opens nothing, got " .. tostring(o_n))
  U.finalize(H.now())
  ok(select(5, U.spans()) == 0, "and records no span")

  SC.ability_name = real
  DT.reset()
  U.reset()
end
