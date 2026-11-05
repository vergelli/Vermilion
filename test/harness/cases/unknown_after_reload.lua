return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G = Vermilion.Graph
  local ID = 987654

  local function listed(SC)
    for _, u in ipairs(SC.get_unknowns()) do
      if u.id == ID then return true end
    end
    return false
  end

  Vermilion.Metrics.reset()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  G.on_record_click()
  for _ = 1, 8 do
    H.damage_out({ hit = 1000, ability_id = ID })
    H.advance(1000)
  end
  H.advance(6000)
  G.on_stop_click()

  local before = Vermilion.SkillColors
  ok(listed(before), "a skill with no group is listed while recording")
  local saved = Vermilion.SessionStore.capture()
  G.on_flush_click()

  dofile(HARNESS_ROOT .. "/core/skill_colors.lua")
  local fresh = Vermilion.SkillColors
  ok(fresh ~= before and fresh.unknown_count() == 0, "a reload starts with an empty list")

  ok(G.load_session(saved), "the session loads after the reload")
  ok(listed(fresh), "opening the session lists its grey skill again")

  ok(fresh.set_override(ID, "status"), "the skill can be assigned from there")
  ok(not listed(fresh), "an assigned skill leaves the list")
  G.on_flush_click()
  ok(G.load_session(saved), "the session loads again")
  ok(not listed(fresh), "and an assigned skill does not come back")

  Vermilion.SkillColors = before
  G.on_flush_click()
  Vermilion.Visibility.set("graph", false)
  Vermilion.Metrics.reset()
end
