return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local K  = Vermilion.ContentKind
  local SS = Vermilion.SessionStore
  local sv = Vermilion.SavedVars
  local st = H.state

  local function reset()
    st.in_bg, st.bg_id, st.bg_team_size = nil, nil, nil
    st.in_raid, st.in_archive, st.in_cyrodiil, st.in_ic = nil, nil, nil, nil
    st.house_id, st.map_content, st.zone_id, st.difficulty = nil, nil, nil, nil
  end

  reset()
  ok(K.detect() == "world", "nothing special is overland, got " .. tostring(K.detect()))
  st.map_content = MAP_CONTENT_DUNGEON
  ok(K.detect() == "dungeon", "a dungeon map is a dungeon")
  st.zone_id = 677
  ok(K.detect() == "arena", "Maelstrom Arena is an arena")
  st.zone_id = 1082
  ok(K.detect() == "arena", "Blackrose Prison is an arena")
  st.zone_id = 12
  ok(K.detect() == "dungeon", "an unknown dungeon zone stays a dungeon")
  reset()
  st.in_raid = true
  ok(K.detect() == "trial", "a raid is a trial")
  reset()
  st.in_archive = true
  ok(K.detect() == "archive", "the endless dungeon is the Infinite Archive")
  reset()
  st.in_bg = true
  st.bg_id = 7
  st.bg_team_size = 8
  ok(K.detect() == "bg", "an eight-player battleground is casual")
  st.bg_team_size = 4
  ok(K.detect() == "bgc", "a four-player battleground is competitive")
  reset()
  st.in_cyrodiil = true
  ok(K.detect() == "ava", "Cyrodiil is Alliance War")
  reset()
  st.map_content = MAP_CONTENT_AVA
  ok(K.detect() == "ava", "an AvA map is Alliance War too")
  reset()
  st.house_id = 42
  ok(K.detect() == "house", "a house is a home")
  reset()

  for _, kind in ipairs({ "dungeon", "trial", "arena", "archive", "bg", "bgc", "ava", "house", "world" }) do
    ok(type(K.icon(kind)) == "string" and K.icon(kind):find("^EsoUI/Art/"), kind .. " has a game icon")
    ok(type(K.label(kind)) == "string" and #K.label(kind) > 2, kind .. " has a label")
  end
  ok(K.icon(nil) == nil and K.label(nil) == nil and K.icon("nope") == nil, "unknown kinds have no icon or label")

  sv.settings = sv.settings or {}
  local before_lib, before_auto = sv.library, sv.settings.session_autosave
  sv.library = { version = 1, sessions = {} }
  sv.settings.session_autosave = true
  Vermilion.Metrics.reset()
  Vermilion.Graph.on_flush_click()

  st.in_raid = true
  st.difficulty = DUNGEON_DIFFICULTY_VETERAN
  Vermilion.Graph.on_record_click()
  H.damage_out({ hit = 900 })
  H.advance(1000)
  Vermilion.Graph.on_stop_click()
  H.advance(400)
  reset()
  ok(SS.count() == 1 and SS.get(1).head.kind == "trial", "the session head remembers the kind it started in")
  ok(SS.get(1).head.difficulty == DUNGEON_DIFFICULTY_VETERAN, "the session head remembers the difficulty")

  st.in_bg = true
  st.bg_id = 3
  st.bg_team_size = 4
  Vermilion.Graph.on_flush_click()
  Vermilion.Graph.on_record_click()
  H.damage_out({ hit = 900 })
  H.advance(1000)
  Vermilion.Graph.on_stop_click()
  H.advance(400)
  reset()
  ok(SS.count() == 2 and SS.get(2).head.kind == "bgc", "a competitive battleground is remembered as such")

  Vermilion.Graph.on_flush_click()
  sv.library, sv.settings.session_autosave = before_lib, before_auto
  Vermilion.Metrics.reset()
end
