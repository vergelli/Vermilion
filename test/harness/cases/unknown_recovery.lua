return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G, RV, SC = Vermilion.Graph, Vermilion.ResourcesView, Vermilion.SkillColors
  local sv = Vermilion.SavedVars
  sv.settings = sv.settings or {}
  local before_auto = sv.settings.session_autosave
  local RECOVERY, DAMAGE = 880010, 880011

  local function listed(id)
    for _, u in ipairs(SC.get_unknowns()) do
      if u.id == id then return true end
    end
    return false
  end

  Vermilion.Metrics.reset()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  local view_label = VermilionGraphWindowViewLabel
  while view_label._text ~= "SKILL" do G.next_view() end
  RV.set_pick(3)

  H.ability_names = H.ability_names or {}
  H.ability_names[RECOVERY], H.ability_names[DAMAGE] = "Meridia's Favor", "Unnamed Strike"
  H.state.power = { [POWERTYPE_MAGICKA] = { value = 30000, max = 30000 }, [POWERTYPE_STAMINA] = { value = 20000, max = 20000 } }
  H.state.stats = { [STAT_MAGICKA_REGEN_COMBAT] = 953, [STAT_STAMINA_REGEN_COMBAT] = 1210 }
  sv.settings.session_autosave = false

  G.on_record_click()
  for _ = 1, 6 do
    H.energize({ ability_id = RECOVERY, amount = 1200, pool = COMBAT_MECHANIC_FLAGS_MAGICKA })
    H.damage_out({ hit = 1000, ability_id = DAMAGE })
    H.advance(1000)
  end
  G.on_stop_click()
  H.advance(500)

  while view_label._text ~= "RESOURCES" do G.next_view() end
  local recovered, n = RV.recovered()
  local row
  for i = 1, n do
    if recovered[i].id == RECOVERY then row = recovered[i] end
  end
  ok(row ~= nil and row.name == "Meridia's Favor", "the recovery is still measured and named in RECOVERED BY")
  ok(row.mag == 6 * 1200, "with its full amount, got " .. tostring(row.mag))
  ok(not listed(RECOVERY), "a skill that only recovers does not ask for a category in Unknown Contributions")
  ok(listed(DAMAGE), "a damage skill with no category still does")

  while view_label._text ~= "SKILL" do G.next_view() end
  G.on_flush_click()
  SC.set_override(DAMAGE, "other")
  H.state.power, H.state.stats = nil, nil
  H.ability_names[RECOVERY], H.ability_names[DAMAGE] = nil, nil
  sv.settings.session_autosave = before_auto
end
