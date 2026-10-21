return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local U = Vermilion.Uptime
  local fx = dofile(HARNESS_ROOT .. "/test/harness/fixtures/uptime_trace.lua")
  ok(#fx.ef > 400 and #fx.ce > 100, "the fixture holds two real minutes of effects and ticks")

  H.ability_names = H.ability_names or {}
  H.ability_names[62951], H.ability_names[21765], H.ability_names[40385], H.ability_names[204009] = "Blockade of Frost", "Purifying Light", "Barbed Trap", "Tri Focus"
  H.slotted = { [HOTBAR_CATEGORY_PRIMARY] = { [3] = 62951, [4] = 21765, [5] = 40385, [6] = 204009 } }
  local base = H.now()
  U.reset()
  U.start_session(base)
  ok(U.is_recording(), "the tracker records after start")

  local function fire(e)
    H.fire(EVENT_EFFECT_CHANGED, e.ch, 1, e.name, e.tag, (base + e.b) / 1000, (base + e.e) / 1000,
      1, "icon.dds", 0, BUFF_EFFECT_TYPE_DEBUFF, 0, 0, "Enemy", e.unit, e.aid, COMBAT_UNIT_TYPE_PLAYER)
  end

  local cursor = 0
  for _, e in ipairs(fx.ef) do
    if e.t > cursor then H.advance(e.t - cursor); cursor = e.t end
    fire(e)
  end
  H.advance(2000)

  local names, slotted, nk = U.keys()
  ok(nk >= 8, "the replay registers the effects it saw by name, got " .. nk)
  ok(U.key_of("Puncturing Sweep") == nil, "a half-second per-hit effect is not an uptime")
  local kb = U.key_of("Blockade of Frost")
  ok(kb ~= nil and slotted[kb] == true, "a slotted skill is flagged as a skill")
  local kt = U.key_of("Traumatic Burns")
  ok(kt ~= nil and slotted[kt] == false, "a set proc is tracked and flagged as other")

  local ok_, ou, ot0, oe, on = U.open_spans()
  ok(on <= 32, "open slots stay bounded while recording, got " .. on)

  local pk, pu, pt, pe, pkind, pn = U.presses()
  local early, late, refresh, echo_like, units = 0, 0, 0, 0, {}
  for i = 1, pn do
    if pk[i] == kt then
      if pkind[i] == U.KIND_REFRESH then refresh = refresh + 1 end
      if pe[i] > 500 then early = early + 1 elseif pe[i] < -500 then late = late + 1 end
      units[pu[i]] = true
    end
  end
  local nu = 0
  for _ in pairs(units) do nu = nu + 1 end
  ok(refresh >= 15 and early >= 15 and early > late * 4, "Traumatic Burns is refreshed early on most presses, refreshes " .. refresh .. " early " .. early .. " late " .. late)
  ok(nu >= 4, "the set proc is tracked on several units, got " .. nu)

  local bk = kb
  local b_units, replaced, gaps = {}, 0, 0
  for i = 1, pn do
    if pk[i] == bk then
      b_units[pu[i]] = true
      if pkind[i] == U.KIND_REPLACE then replaced = replaced + 1 end
      if pkind[i] == U.KIND_GAP then gaps = gaps + 1 end
    end
  end
  local nb = 0
  for _ in pairs(b_units) do nb = nb + 1 end
  ok(nb >= 3, "Blockade of Frost is tracked on several enemies, got " .. nb)

  U.finalize(H.now())
  local _, _, _, _, on2 = U.open_spans()
  ok(on2 == 0, "finalize closes every open span, got " .. on2)
  local sk, su, st0, st1, sn = U.spans()
  ok(sn >= 60, "the replay leaves a stream of spans, got " .. sn)
  local covered, longest = 0, 0
  for i = 1, sn do
    ok(st1[i] >= st0[i], "spans close after they open")
    if sk[i] == bk then
      covered = covered + (st1[i] - st0[i])
      if st1[i] - st0[i] > longest then longest = st1[i] - st0[i] end
    end
  end
  ok(longest >= 12000 and longest <= 17000, "a Blockade span lasts about its fifteen seconds, longest " .. longest)

  local DESC = Vermilion.SessionStore.DESC
  ok(DESC.spans and DESC.press, "the session descriptor knows the two uptime streams")
  local vsf = Vermilion.lib.vsf
  local span_recs, press_recs = {}, {}
  for i = 1, sn do span_recs[i] = { t0 = st0[i] - base, t1 = st1[i] - base, key = sk[i], unit = su[i] } end
  for i = 1, pn do press_recs[i] = { t = pt[i] - base, key = pk[i], unit = pu[i], e = pe[i] + U.E_LIMIT(), kind = pkind[i] } end
  local packed_s = vsf.pack(span_recs, DESC.spans)
  local packed_p = vsf.pack(press_recs, DESC.press)
  local meta = { names = {}, slotted = {} }
  for k = 1, nk do meta.names[k] = names[k]; meta.slotted[k] = slotted[k] end
  U.load_session(vsf.unpack(packed_s, DESC.spans), vsf.unpack(packed_p, DESC.press), meta)
  local names2, slotted2, nk2 = U.keys()
  local _, _, _, _, sn2 = U.spans()
  local pk2, _, _, pe2, pkind2, pn2 = U.presses()
  ok(nk2 == nk and sn2 == sn and pn2 == pn, "the streams survive the pack and unpack round trip")
  ok(names2[kt] == "Traumatic Burns" and slotted2[kb] == true, "names and the skill flag come back with the session")
  local early2 = 0
  for i = 1, pn2 do if pk2[i] == kt and pe2[i] > 500 then early2 = early2 + 1 end end
  ok(early2 == early, "signed refresh errors round trip through the unsigned field, got " .. early2 .. " vs " .. early)

  U.reset()
  U.start_session(H.now())
  fire({ ch = EFFECT_RESULT_GAINED, name = "Barbed Trap", tag = "", b = H.now() - base, e = H.now() - base + 20000, unit = 777, aid = 40385 })
  H.advance(100)
  fire({ ch = EFFECT_RESULT_UPDATED, name = "Barbed Trap", tag = "", b = H.now() - base, e = H.now() - base + 20000, unit = 777, aid = 40385 })
  local _, _, _, _, _, pn3 = U.presses()
  ok(pn3 == 1, "an update within 150 ms of a gain is an echo, not a press, got " .. pn3)
  H.advance(5000)
  local bytes = H.addon_alloc(function()
    for _ = 1, 50 do
      fire({ ch = EFFECT_RESULT_UPDATED, name = "Barbed Trap", tag = "", b = H.now() - base, e = H.now() - base + 20000, unit = 777, aid = 40385 })
    end
  end)
  ok(bytes < (HARNESS_DEBUG and 8000 or 600), string.format("fifty refreshes allocate %.0f addon-side bytes beyond the press stream (budget %d)", bytes, HARNESS_DEBUG and 8000 or 600))
  U.on_unit_dead(777, H.now())
  local _, _, _, _, on3 = U.open_spans()
  ok(on3 == 0, "a dead target closes its spans")
  fire({ ch = EFFECT_RESULT_GAINED, name = "Barbed Trap", tag = "group1", b = H.now() - base, e = H.now() - base + 20000, unit = 778, aid = 40385 })
  local _, _, _, _, on4 = U.open_spans()
  ok(on4 == 0, "effects on friendly tags are ignored")
  U.reset()
  H.slotted = nil
end
