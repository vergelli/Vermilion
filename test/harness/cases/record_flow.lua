return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local TB = Vermilion.TemporalBuffer
  local G  = Vermilion.Graph

  Vermilion.Metrics.reset()
  G.on_flush_click()
  ok(TB.count() == 0, "flush empties the buffer")

  G.on_record_click()
  ok(TB.is_recording(), "record starts a recording")
  ok(H.update_registered(Vermilion.Constants.TEMPORAL.UPDATE_NAME), "the sample tick is registered while recording")
  ok(VermilionGraphWindowStatusLabel._text == "0:00", "the status starts at 0:00")

  for _ = 1, 5 do
    H.damage_out({ hit = 1000, ability_id = 31 })
    H.damage_out({ hit = 500, ability_id = 32, result = ACTION_RESULT_CRITICAL_DAMAGE, damage_type = DAMAGE_TYPE_FIRE })
    H.shield_out({ hit = 300 })
    H.advance(1000)
  end
  ok(TB.count() >= 4, "samples accumulate at the sample rate, got " .. TB.count())
  local last = TB.at(TB.count())
  ok(last.eDPS > 0, "damage out registers as eDPS, got " .. tostring(last.eDPS))
  ok(last.ShDPS > 0, "the player's shield absorbs register as ShDPS, got " .. tostring(last.ShDPS))
  ok(last.crit > 0 and last.noncrit > 0, "crit and non-crit split")
  ok((last.eos_abilities.count or 0) >= 2, "per-tick ability shares carry both abilities, got " .. tostring(last.eos_abilities.count))
  local sum = 0
  for i = 1, last.eos_abilities.count do sum = sum + last.eos_abilities[i].share end
  ok(math.abs(sum - 1) < 1e-6, "ability shares sum to one")
  ok((last.dtype_groups.count or 0) >= 2, "damage-type groups carry physical and fire")
  ok(VermilionGraphWindowStatusLabel._text ~= "0:00", "the status advances")

  local before = TB.count()
  H.damage({ hit = 4000 })
  H.advance(1000)
  local last2 = TB.at(TB.count())
  ok(last2.eDPS <= last.eDPS + 1, "damage from someone else is not the player's damage")

  G.on_stop_click()
  ok(not TB.is_recording(), "stop ends the recording")
  ok(not H.update_registered(Vermilion.Constants.TEMPORAL.UPDATE_NAME), "the sample tick unregisters on stop")
  ok(TB.count() >= before, "the recording stays frozen for review")

  G.on_record_click()
  ok(TB.count() == 0, "a new recording starts from an empty buffer")
  G.on_stop_click()
  G.on_flush_click()
  Vermilion.Metrics.reset()
end
