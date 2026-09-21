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
  T.set_auto(SV, false)
  T.clear(SV)
  Vermilion.Graph.on_flush_click()
  Vermilion.Metrics.reset()
end
