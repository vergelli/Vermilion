return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end

  local AR = Vermilion.AutoRecord
  local TB = Vermilion.TemporalBuffer

  Vermilion.Metrics.reset()
  Vermilion.Graph.on_flush_click()
  H.combat_state(false)
  H.set_bosses({})
  AR.set_mode("off")

  AR.set_mode("boss")
  ok(H.update_registered("VermilionAutoRecTick"), "tick must register when enabled")

  H.set_bosses({ { name = "Lord Falgravn" } })
  ok(not TB.is_recording(), "boss without combat must not start")

  H.combat_state(true)
  ok(TB.is_recording(), "boss + combat must auto-start")
  ok(AR.is_auto_active(), "auto flag must be set")

  H.advance(2000)
  ok(VermilionGraphWindowStatusLabel._text:find("AUTO") == 1,
     "status must show AUTO marker: " .. tostring(VermilionGraphWindowStatusLabel._text))

  H.combat_state(false)
  H.advance(2000)
  ok(TB.is_recording(), "grace must hold the recording for a wipe-check window")
  H.combat_state(true)
  H.advance(1000)
  ok(TB.is_recording(), "re-entering combat must cancel the grace stop")

  H.combat_state(false)
  H.advance(7000)
  ok(not TB.is_recording(), "grace timeout must stop the recording")
  ok(TB.count() > 0, "auto session must stay frozen for review")
  ok(AR.is_auto_session(), "session must be marked as auto")

  H.combat_state(true)
  ok(TB.is_recording(), "next pull must replace the previous auto session")
  H.combat_state(false)
  H.advance(7000)
  ok(not TB.is_recording(), "second auto session must stop")

  Vermilion.Graph.on_record_click()
  H.advance(1000)
  Vermilion.Graph.on_stop_click()
  ok(not AR.is_auto_session(), "manual recording must clear auto provenance")
  local frozen = TB.count()
  H.combat_state(true)
  ok(not TB.is_recording(), "auto-start must never clobber a manual frozen session")
  ok(TB.count() == frozen, "manual session must stay intact")
  H.combat_state(false)

  if Vermilion.Constants.DEBUG then
    ok(Vermilion.Diagnostics.get("autorec.blocked_manual_session") >= 1, "blocked counter missing")
  end

  Vermilion.Graph.on_flush_click()
  AR.set_mode("combat")
  H.set_bosses({})
  H.combat_state(true)
  ok(TB.is_recording(), "combat mode must start on any combat")
  H.fire(EVENT_PLAYER_ACTIVATED)
  ok(not TB.is_recording(), "zone change must stop an auto recording")

  AR.set_mode("off")
  ok(not H.update_registered("VermilionAutoRecTick"), "tick must unregister when disabled")

  local lines = AR.report_lines()
  ok(#lines >= 2, "report_lines must include transition history")

  Vermilion.Graph.on_flush_click()
  Vermilion.Metrics.reset()
end
