return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G, P, MT = Vermilion.Graph, Vermilion.Pipeline, Vermilion.Metrics
  local view_label = VermilionGraphWindowViewLabel

  Vermilion.Metrics.reset()
  Vermilion.TemporalBuffer.clear()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  while view_label._text ~= "SKILL" do G.next_view() end
  H.ability_names = { [31] = "Puncturing Sweep", [41] = "Hardened Ward", [42] = "Reviving Barrier" }

  G.on_record_click()
  H.shield_out({ hit = 400, ability_id = 41, target_name = "Sorc", target_type = COMBAT_UNIT_TYPE_OTHER, target_unit_id = 900 })
  ok(P.pending_count() == 1, "a shield event waits for its attack")
  H.damage_out({ hit = 0, ability_id = 31, target_unit_id = 900, damage_type = DAMAGE_TYPE_MAGIC })
  ok(P.pending_count() == 0, "the attack that follows claims the shield")
  H.damage_out({ hit = 600, ability_id = 31, target_unit_id = 900, damage_type = DAMAGE_TYPE_MAGIC })
  H.advance(1000)

  local groups, abilities, dgroups, dabilities = { count = 0 }, { count = 0 }, { count = 0 }, { count = 0 }
  local now = H.now()
  MT.eos_groups_into(groups, now)
  MT.eos_abilities_into(abilities, now)
  MT.dtype_groups_into(dgroups, now)
  MT.dtype_abilities_into(dabilities, now)
  ok(groups.count == 1 and groups[1].key == Vermilion.SkillColors.group_of(31), "the absorbed damage joins the attack's skill group, got " .. tostring(groups[1] and groups[1].key))
  ok(abilities.count == 1 and abilities[1].id == 31, "SKILL lists the attack, never the enemy ward")
  ok(abilities[1].abs > 0 and abilities[1].abs < abilities[1].share, "the attack carries its absorbed share")
  ok(dgroups.count == 1 and dgroups[1].key == DAMAGE_TYPE_MAGIC, "TYPE types the absorbed damage by the attack, got " .. tostring(dgroups[1] and dgroups[1].key))
  ok(dabilities.count == 1 and dabilities[1].id == 31 and dabilities[1].abs > 0, "the typed ability carries its absorbed share too")
  local eos = MT.eDPS(now) + MT.ShDPS(now)
  ok(MT.ShDPS(now) > 0, "the absorbed amount still counts as ShDPS")
  local sum = 0
  for i = 1, dgroups.count do sum = sum + dgroups[i].share end
  ok(math.abs(sum - 1) < 1e-9 and eos > 0, "TYPE shares cover the whole EOS")

  local hits = select(4, MT.totals())
  ok(hits == 1, "a fully absorbed attack is not a hit, got " .. tostring(hits))

  H.shield_out({ hit = 300, ability_id = 42, target_name = "Templar", target_type = COMBAT_UNIT_TYPE_OTHER, target_unit_id = 901 })
  H.advance(1000)
  ok(P.pending_count() == 0, "a shield with no attack within the window is flushed by the sample tick")
  MT.eos_groups_into(groups, H.now())
  local shield_group = nil
  for i = 1, groups.count do if groups[i].key == "shield" then shield_group = groups[i] end end
  ok(shield_group ~= nil, "an unpaired shield lands in the Shields cracked group")
  MT.eos_abilities_into(abilities, H.now())
  local zero = nil
  for i = 1, abilities.count do if abilities[i].id == 0 then zero = abilities[i] end end
  ok(zero ~= nil and zero.key == "shield" and zero.abs == zero.share, "the unpaired shield is a single id-0 row, fully absorbed")
  MT.dtype_groups_into(dgroups, H.now())
  local dshield = nil
  for i = 1, dgroups.count do if dgroups[i].key == Vermilion.DamageTypeColors.SHIELD then dshield = dgroups[i] end end
  ok(dshield ~= nil, "TYPE keeps a Shield bucket for the unpaired part")

  local shields = { count = 0 }
  MT.shield_abilities_into(shields, H.now())
  ok(shields.count == 2, "the enemy shields are kept by name for the outcome card, got " .. tostring(shields.count))
  local ids = {}
  for i = 1, shields.count do ids[shields[i].id] = true end
  ok(ids[41] and ids[42], "both enemy wards are listed")

  for _ = 1, 3 do
    H.shield_out({ hit = 200, ability_id = 41, target_unit_id = 900 })
    H.damage_out({ hit = 0, ability_id = 31, target_unit_id = 900, damage_type = DAMAGE_TYPE_MAGIC })
    H.advance(1000)
  end
  G.on_stop_click()
  ok(P.pending_count() == 0, "stopping flushes whatever was pending")

  while view_label._text ~= "CONTRIB" do G.next_view() end
  local rows, n = Vermilion.ContribView.rows()
  ok(n == 2, "CONTRIB shows the attack and the unpaired bucket, got " .. tostring(n))
  ok(rows[1].name == "Puncturing Sweep" and rows[1].abs > 0 and rows[1].abs < rows[1].v, "the attack row carries its absorbed part")
  ok(rows[2].name == "Shields cracked" and rows[2].ch == -1, "the unpaired part is the Shields cracked row")
  local tails = 0
  for _, c in ipairs(H.controls) do
    local name = c._name or ""
    if c._hidden == false and name:find("^VermilionContribSeg") and c._h == 5 and c._r and math.abs(c._r - 0.85) < 1e-6 and math.abs(c._b - 0.75) < 1e-6 then tails = tails + 1 end
  end
  ok(tails >= 1, "the absorbed part is drawn as an orchid tail on the bar, got " .. tails)
  local texts = {}
  for _, c in ipairs(H.controls) do
    if c._hidden == false and (c._name or ""):find("^VermilionContribLbl") and c._text then texts[c._text] = true end
  end
  ok(texts["Hardened Ward"] == nil and texts["Reviving Barrier"] == nil, "no enemy ward is ever a CONTRIB row")

  local sess = Vermilion.SessionStore.capture()
  ok(sess.desc.abilities[6].name == "ab", "the session codec carries the absorbed share")
  G.on_flush_click()
  ok(G.load_session(sess), "the session reloads")
  while view_label._text ~= "CONTRIB" do G.next_view() end
  local lrows, ln = Vermilion.ContribView.rows()
  ok(ln == 2 and lrows[1].abs > 0, "the absorbed share survives the round trip, got " .. tostring(lrows[1] and lrows[1].abs))
  local s = Vermilion.TemporalBuffer.at(Vermilion.TemporalBuffer.count())
  ok(s.shield_abilities and s.shield_abilities.count >= 1 and s.shield_abilities[1].key == "shield", "the enemy shields travel with the session")

  while view_label._text ~= "SKILL" do G.next_view() end
  G.on_flush_click()
  H.ability_names = nil
  Vermilion.Visibility.set("graph", false)
  Vermilion.Metrics.reset()
end
