return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local T = Vermilion.Trace
  if not Vermilion.Constants.DEBUG then
    ok(T.set_cap == nil, "the release stub has no cap to set")
    return
  end
  local SV = Vermilion.SavedVars
  Vermilion.Metrics.reset()
  Vermilion.Graph.on_flush_click()
  T.clear(SV)
  T.set_cap(50)
  T.set_auto(SV, true)

  Vermilion.Graph.on_record_click()
  H.clear_chat()
  for i = 1, 80 do H.damage_out({ hit = 100 + i }) end
  ok(H.chat_contains("capacity reached"), "hitting the cap is announced")
  ok(T.status_line():find("capped", 1, true), "the status line says the capture is capped: " .. T.status_line())
  H.advance(1000)
  Vermilion.Graph.on_stop_click()
  ok(SV.trace ~= nil, "a capped trace is still saved when the recording stops")
  ok(SV.trace.count == 50, "the saved trace holds exactly the events up to the cap, got " .. tostring(SV.trace and SV.trace.count))
  ok(SV.traces and #SV.traces == 1, "the capped trace lands in the ring")

  Vermilion.Graph.on_flush_click()
  Vermilion.Graph.on_record_click()
  H.damage_out({ hit = 300 })
  T.stop()
  H.advance(1000)
  Vermilion.Graph.on_stop_click()
  ok(#SV.traces == 1, "a trace stopped by hand before the recording ends is still not saved")

  Vermilion.Graph.on_flush_click()
  Vermilion.Graph.on_record_click()
  H.damage_out({ hit = 300 })
  H.advance(1000)
  Vermilion.Graph.on_stop_click()
  ok(#SV.traces == 2 and not T.status_line():find("capped", 1, true), "a new recording starts uncapped and saves normally")

  T.set_cap(40000)
  T.clear(SV)
  Vermilion.Graph.on_flush_click()
  Vermilion.Graph.on_record_click()
  H.skill_used(3)
  H.fire(EVENT_POWER_UPDATE, "player", 1, COMBAT_MECHANIC_FLAGS_MAGICKA, 900, 1000, 1000)
  H.damage_out({ hit = 300 })
  H.advance(1000)
  Vermilion.Graph.on_stop_click()
  local joined = table.concat(SV.trace.chunks, "\n")
  ok(joined:find("SU\t", 1, true), "the trace records the button presses")
  ok(joined:find("PU\t", 1, true), "the trace records the power changes")
  local codec = dofile(HARNESS_ROOT .. "/test/simlab/tracecodec.lua")
  local su, pu
  for _, e in ipairs(codec.decode_chunks(SV.trace.chunks)) do
    if e.tag == "SU" then su = e elseif e.tag == "PU" then pu = e end
  end
  ok(su and su.args[1] == 3, "the codec reads the pressed slot back")
  ok(pu and pu.args[4] == 900, "the codec reads the power value back")
  ok(SV.trace.constants.COMBAT_MECHANIC_FLAGS_MAGICKA == COMBAT_MECHANIC_FLAGS_MAGICKA, "the trace carries the pool constants")

  T.set_auto(SV, false)
  T.clear(SV)
  Vermilion.Graph.on_flush_click()
  Vermilion.Metrics.reset()
end
