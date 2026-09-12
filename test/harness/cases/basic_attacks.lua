return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local SC = Vermilion.SkillColors
  H.ability_names = H.ability_names or {}
  H.ability_icons = H.ability_icons or {}
  local names, icons = H.ability_names, H.ability_icons

  names[16165] = "Light Attack (Inferno)"
  icons[16165] = "/esoui/art/icons/death_recap_fire_ranged.dds"
  names[990001] = "Heavy Attack"
  names[990003] = "Lightning Flood"
  icons[990002] = "/esoui/art/icons/death_recap_ranged_heavy.dds"
  icons[990007] = "/esoui/art/icons/death_recap_melee_heavy.dds"
  icons[990009] = "/esoui/art/icons/death_recap_melee_dagger_basic.dds"
  SC.relearn_basic_names()
  ok(SC.group_of(16165) == "basic", "a staff light attack is basic by name even with an ambiguous icon")
  ok(SC.group_of(990001) == "basic", "a bare Heavy Attack name is basic")
  ok(SC.group_of(990003) ~= "basic", "a name that merely starts with Light is not basic")
  ok(SC.group_of(990002) == "basic", "the ranged heavy death-recap icon is basic")
  ok(SC.group_of(990007) == "basic", "the melee heavy death-recap icon is basic")
  ok(SC.group_of(990009) == "basic", "the per-weapon melee death-recap icons are basic")
  ok(SC.group_of(990006) == "other", "the mock naming scheme never leaks into basic")
  ok(SC.group_of(19277) == "basic", "the id list still catches a known channel tick")

  names[15435] = "Leichter Angriff (Einhändig)"
  names[16037] = "Leichter Angriff (Zweihändig)"
  names[17162] = "Schwerer Angriff (Zweihändig)"
  names[15279] = "Schwerer Angriff (Einhändig)"
  names[990004] = "Leichter Angriff (Zwei Waffen)"
  names[990005] = "Schwerer Angriff (Bogen)"
  names[990008] = "Leichte Brise"
  SC.relearn_basic_names()
  ok(SC.group_of(990004) == "basic", "a localized light attack is learned from the probe ids")
  ok(SC.group_of(990005) == "basic", "a localized heavy attack is learned from the probe ids")
  ok(SC.group_of(990008) == "other", "a localized name sharing only the first word stays out")

  for _, id in ipairs({ 16165, 990001, 990003, 15435, 16037, 17162, 15279, 990004, 990005, 990008 }) do names[id] = nil end
  for _, id in ipairs({ 16165, 990002, 990007, 990009 }) do icons[id] = nil end
  SC.relearn_basic_names()
end
