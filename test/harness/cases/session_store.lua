return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local SS = Vermilion.SessionStore
  local V = Vermilion.lib.vsf
  local sv = Vermilion.SavedVars
  local G = Vermilion.Graph

  sv.settings = sv.settings or {}
  sv.library = { version = 1, sessions = {} }
  H.state.grouped = true
  H.state.group_size = 4
  H.state.player_group_tag = "group1"
  H.state.zone = "Fungal Grotto"
  H.fire(EVENT_GROUP_UPDATE)
  Vermilion.Metrics.reset()
  G.on_flush_click()

  sv.settings.session_autosave = false
  G.on_record_click()
  H.damage_out({ hit = 700 })
  H.advance(1500)
  G.on_stop_click()
  H.advance(400)
  ok(SS.count() == 0, "autosave off must not store sessions")

  sv.settings.session_autosave = true
  G.on_record_click()
  H.damage_out({ hit = 900, ability_id = 31 })
  H.damage_out({ hit = 500, ability_id = 32, result = ACTION_RESULT_CRITICAL_DAMAGE, damage_type = DAMAGE_TYPE_FIRE })
  H.advance(1200)
  H.shield_out({ hit = 300 })
  H.advance(400)
  H.damage_out({ hit = 3000, ability_id = 31 })
  H.advance(2500)
  H.damage_out({ hit = 100, ability_id = 33, damage_type = DAMAGE_TYPE_POISON })
  H.advance(1500)
  G.on_stop_click()
  H.advance(400)

  ok(SS.count() == 1, "autosave on must store the session, got " .. SS.count())
  ok(not SS.autosave_pending(), "the deferred autosave must have finished within a few frames")
  ok(H.chat_contains("saved to the library"), "the player is told the recording was saved")

  G.on_record_click()
  for _ = 1, 30 do
    H.damage_out({ hit = 1000 })
    H.advance(1000)
  end
  G.on_stop_click()
  ok(SS.count() == 1 and SS.autosave_pending(), "right after stop the autosave is still pending, nothing stored yet")
  G.on_record_click()
  ok(SS.count() == 2 and not SS.autosave_pending(), "starting a new recording finishes the pending autosave first, got " .. SS.count())
  local last = SS.get(2)
  ok(last and last.streams.series.n == 30, "the finished session kept its 30 samples, got " .. tostring(last and last.streams.series.n))
  for _ = 1, 5 do
    H.damage_out({ hit = 1000 })
    H.advance(1000)
  end
  G.on_stop_click()
  H.advance(400)
  ok(SS.count() == 3, "the recording that interrupted the autosave autosaves too")

  local s = SS.get(1)
  ok(s.head.zone == "Fungal Grotto", "zone wrong: " .. tostring(s.head.zone))
  ok(s.head.dur_ms >= 5500 and s.head.dur_ms <= 6200, "duration wrong: " .. tostring(s.head.dur_ms))
  ok(s.head.group_size == 4, "group size wrong: " .. tostring(s.head.group_size))
  ok(s.head.sum.total_damage == 4500, "total damage must add every hit, got " .. tostring(s.head.sum.total_damage))
  ok(s.head.sum.total_shield == 300, "total shield must add every absorb, got " .. tostring(s.head.sum.total_shield))
  ok(s.head.sum.total_crit == 500, "crit total wrong: " .. tostring(s.head.sum.total_crit))
  ok(s.head.sum.hits == 4, "hit count wrong: " .. tostring(s.head.sum.hits))
  ok(s.head.sum.peak > 0 and s.head.sum.avg > 0 and s.head.sum.peak >= s.head.sum.avg, "avg and peak eos come from the samples")
  ok(s.head.sum.peak_edps <= s.head.sum.peak, "peak eDPS never exceeds peak eos")
  ok(s.head.sum.crit_pct > 0 and s.head.sum.crit_pct < 1, "crit share is a fraction, got " .. tostring(s.head.sum.crit_pct))
  ok(s.head.sum.active_pct > 0 and s.head.sum.active_pct <= 1, "active share is a fraction")
  ok(s.head.cfg.window_ms == 5000 and s.head.cfg.shield_window_ms == 30000, "the head remembers the metric windows")
  ok(s.head.cfg.sample_rate_ms == Vermilion.Constants.TEMPORAL.SAMPLE_RATE_DEFAULT, "the head remembers the sample rate")
  ok(s.head.build == Vermilion.Constants.VERSION, "the head carries the build")
  ok(s.head.locked == false and s.head.manual == nil, "an autosave is neither locked nor manual")

  local series = V.unpack(s.streams.series, s.desc.series)
  ok(series and #series == s.streams.series.n and #series > 3,
     "series must decode, n=" .. tostring(series and #series))
  ok(series[1].t == 0 or series[1].t <= 1000, "the first sample sits at the session start")
  local peak = 0
  for i = 1, #series do
    ok(series[i].eDPS >= 0 and series[i].ShDPS >= 0, "rates never go negative")
    if series[i].eDPS + series[i].ShDPS > peak then peak = series[i].eDPS + series[i].ShDPS end
  end
  ok(math.abs(peak - s.head.sum.peak) < 1, "the decoded peak matches the head, " .. peak .. " vs " .. s.head.sum.peak)

  local shares = V.unpack(s.streams.shares, s.desc.shares)
  ok(shares and #shares > 0, "group shares must decode")
  local by_sample = {}
  local seen_ch = {}
  for _, r in ipairs(shares) do
    seen_ch[r.ch] = true
    ok(s.gkeys[r.key + 1] ~= nil, "every share key resolves through gkeys")
    local k = r.si .. ":" .. r.ch
    by_sample[k] = (by_sample[k] or 0) + r.sh
  end
  ok(seen_ch[SS.CH_SKILL] and seen_ch[SS.CH_DTYPE], "both the skill-line and damage-type channels are stored")
  for k, total in pairs(by_sample) do
    ok(math.abs(total - 1) < 0.01, "shares of " .. k .. " must sum to one, got " .. total)
  end
  local has_fire = false
  for _, k in ipairs(s.gkeys) do if k == DAMAGE_TYPE_FIRE then has_fire = true end end
  ok(has_fire, "damage-type keys travel as numbers in gkeys")

  local abilities = V.unpack(s.streams.abilities, s.desc.abilities)
  ok(abilities and #abilities > 0, "ability shares must decode")
  local ids = {}
  for _, r in ipairs(abilities) do
    ids[r.id] = true
    ok(r.ch == SS.CH_SKILL or r.ch == SS.CH_DTYPE or r.ch == SS.CH_SHIELD, "ability rows carry a channel")
  end
  ok(ids[31] and ids[32] and ids[33], "every ability that hit is in the stream")
  ok(ids[41], "the enemy shield rides the shield channel")

  for _, st in pairs(s.streams) do
    for i, c in ipairs(st.data) do
      ok(#c <= 1800, "stream chunk " .. i .. " over savedvars limit")
    end
  end

  G.on_record_click()
  H.damage_out({ hit = 1000 })
  H.advance(1000)
  ok(SS.save_now(), "a manual save works while still recording")
  SS.finish_autosave()
  ok(SS.count() == 4, "the manual save lands in the library, got " .. SS.count())
  ok(SS.get(4).head.manual == true, "a manual save is flagged manual")
  H.advance(1000)
  G.on_stop_click()
  H.advance(400)
  ok(SS.count() == 5, "stopping after a manual save still autosaves")
  ok(SS.get(5).head.dur_ms > SS.get(4).head.dur_ms, "the autosave covers the whole recording")

  ok(SS.set_label(5, "  boss pull  "), "labels can be set")
  ok(SS.get(5).head.label == "boss pull", "labels are trimmed")
  ok(SS.set_label(5, " "), "labels can be cleared")
  ok(SS.get(5).head.label == nil, "a blank label clears")

  for i = 1, 30 do
    SS.store({ head = { locked = false, zone = "Filler" .. i, dur_ms = 1,
                        group_size = 0, sum = { avg = 0, peak = 0 } },
               streams = {} })
  end
  ok(SS.count() == 24, "ring must cap at 24, got " .. SS.count())

  SS.set_locked(1, true)
  local locked_zone = SS.get(1).head.zone
  for i = 1, 30 do
    SS.store({ head = { locked = false, zone = "More" .. i, dur_ms = 1,
                        group_size = 0, sum = { avg = 0, peak = 0 } },
               streams = {} })
  end
  ok(SS.count() == 24, "ring must stay capped, got " .. SS.count())
  ok(SS.get(1).head.zone == locked_zone, "locked session must survive eviction")

  ok(SS.delete(2), "delete must work")
  ok(SS.count() == 23, "delete must shrink the ring")
  ok(#SS.report_lines() >= 2, "the report lists the library")

  sv.settings.session_autosave = false
  sv.library = { version = 1, sessions = {} }
  H.state.grouped = false
  H.state.group_size = 1
  H.state.player_group_tag = nil
  G.on_flush_click()
  Vermilion.Metrics.reset()
end
