return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local SC, U = Vermilion.SkillColors, Vermilion.Uptime
  local SKILL, EFFECT, PROC, OTHER_BUILD = 926869, 926880, 926881, 926882

  local function listed(id)
    for _, u in ipairs(SC.get_unknowns()) do
      if u.id == id then return true end
    end
    return false
  end

  H.ability_names = H.ability_names or {}
  H.ability_names[SKILL], H.ability_names[EFFECT], H.ability_names[PROC] = "Blazing Spear", "Blazing Spear", "Some Proc"
  H.ability_names[OTHER_BUILD] = "Not On The Bar"
  local real_keys = H.skill_keys
  H.skill_keys = { [SKILL] = { 1, 1, 1 } }
  H.skill_line_id = 22
  H.slotted = { [HOTBAR_CATEGORY_PRIMARY] = { [3] = SKILL } }

  ok(SC.group_of(SKILL) == "templar", "the slotted skill is classified from the skill tree")
  ok(SC.group_of(EFFECT) == "templar", "another id of the same slotted skill takes its colour")
  ok(not listed(EFFECT), "and does not ask for a category")
  ok(SC.group_of(PROC) == "other" and listed(PROC), "an effect with another name still does")
  ok(SC.group_of(OTHER_BUILD) == "other" and listed(OTHER_BUILD), "and so does a name that is not on the bars")

  U.start_session(H.now())
  local t = H.now()
  U.on_effect(EFFECT_RESULT_GAINED, EFFECT, 9001, t / 1000, (t + 20000) / 1000, t, "", BUFF_EFFECT_TYPE_DEBUFF, "Blazing Spear")
  local names, slots, nk, ids = U.keys()
  local found
  for k = 1, nk do
    if names[k] == "Blazing Spear" then found = k end
  end
  ok(found ~= nil, "the effect opened a row")
  ok(slots[found] == true, "the row is known as a slotted skill")
  ok(ids[found] == SKILL, "and a new session stores the skill's own id, not the effect's, got " .. tostring(ids[found]))
  U.reset()

  SC.set_override(PROC, "other")
  SC.set_override(OTHER_BUILD, "other")
  H.slotted, H.skill_line_id = nil, nil
  H.skill_keys = real_keys
  H.ability_names[SKILL], H.ability_names[EFFECT], H.ability_names[PROC], H.ability_names[OTHER_BUILD] = nil, nil, nil, nil
end
