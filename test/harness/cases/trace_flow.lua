return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local T = Vermilion.Trace

  if not (Vermilion.Constants.DEBUG or Vermilion.Constants.RESEARCH) then
    T.start()
    T.stop()
    local sv = {}
    T.save(sv)
    ok(sv.trace == nil, "the trace stub must not write savedvars in a release build")
    ok(T.status_line():find("disabled"), "the stub status says disabled")
    return
  end

  local sv = {}
  T.clear(sv)
  T.start()
  H.combat_state(true)
  for i = 1, 120 do
    H.damage_out({ hit = 1000 + i, ability_id = 31 + (i % 3) })
  end
  H.shield_out({ hit = 250 })
  H.combat_state(false)
  T.stop()
  T.save(sv)

  ok(sv.trace ~= nil, "trace not saved")
  ok(sv.trace.constants and sv.trace.constants.ACTION_RESULT_DAMAGE == ACTION_RESULT_DAMAGE, "constants snapshot reads live globals")
  ok(sv.trace.constants.DAMAGE_TYPE_FIRE == DAMAGE_TYPE_FIRE, "damage type constants travel with the trace")
  ok(sv.trace.count >= 123, "expected at least 123 events, got " .. tostring(sv.trace.count))
  ok(#sv.trace.chunks >= 2, "a big capture splits into several chunks")
  for i, c in ipairs(sv.trace.chunks) do
    ok(#c <= 2000, "chunk " .. i .. " exceeds the SavedVars 2000-char limit: " .. #c)
  end
  ok(sv.trace.settings and sv.trace.settings.time_window_s and sv.trace.settings.sample_rate_ms, "an entry carries the window and rate")
  ok(sv.traces and #sv.traces == 1 and sv.traces[1] == sv.trace, "a save lands in the ring and mirrors sv.trace")

  local codec = dofile(HARNESS_ROOT .. "/test/simlab/tracecodec.lua")
  local events = codec.decode_chunks(sv.trace.chunks)
  ok(#events == sv.trace.count, "decode count mismatch: " .. #events .. " vs " .. sv.trace.count)
  local ce = 0
  for _, e in ipairs(events) do if e.tag == "CE" then ce = ce + 1 end end
  ok(ce == 121, "every combat event is a CE line, got " .. ce)

  local SV = Vermilion.SavedVars
  T.clear(SV)
  ok(T.auto_enabled(SV) == (Vermilion.Constants.RESEARCH == true), "auto-trace defaults to the research flag")
  ok(sv.trace.player and sv.trace.player.name ~= nil, "a trace carries the player's identity")
  T.set_auto(SV, false)
  Vermilion.Graph.on_flush_click()
  Vermilion.Graph.on_record_click()
  H.damage_out({ hit = 100 })
  H.advance(1000)
  Vermilion.Graph.on_stop_click()
  ok(SV.traces == nil, "with auto-trace off a recording stages nothing")

  T.set_auto(SV, true)
  local counts = {}
  for round = 1, 4 do
    Vermilion.Graph.on_flush_click()
    Vermilion.Graph.on_record_click()
    for _ = 1, 10 * round do H.damage_out({ hit = 500 }) end
    H.advance(1000)
    Vermilion.Graph.on_stop_click()
    counts[round] = SV.trace.count
  end
  local RING = Vermilion.Constants.RESEARCH and 6 or 3
  local kept = math.min(4, RING)
  ok(#SV.traces == kept, "the ring keeps " .. kept .. " traces, got " .. tostring(#SV.traces))
  ok(SV.traces[#SV.traces] == SV.trace, "the newest trace mirrors sv.trace")
  if RING < 4 then
    ok(SV.traces[1].count == counts[2] and SV.traces[3].count == counts[4], "the oldest trace is evicted first")
  else
    ok(SV.traces[1].count == counts[1] and SV.traces[4].count == counts[4], "a research ring keeps every recording of the night")
  end
  ok(counts[4] > counts[1], "each recording stages only its own events")

  H.reloads = 0
  SLASH_COMMANDS["/vermilion"]("flush")
  ok(H.reloads == 1, "flush reloads the UI so SavedVariables reach the disk")
  SLASH_COMMANDS["/vermilion"]("trace auto")
  ok(not T.auto_enabled(SV), "the auto subcommand toggles auto-trace off")
  T.clear(SV)
  ok(SV.trace == nil and SV.traces == nil, "clear empties the ring too")
  Vermilion.Graph.on_flush_click()
  Vermilion.Metrics.reset()
end
