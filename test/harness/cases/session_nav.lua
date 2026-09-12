return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G  = Vermilion.Graph
  local SS = Vermilion.SessionStore
  local sv = Vermilion.SavedVars
  sv.settings = sv.settings or {}
  sv.settings.session_autosave = true

  Vermilion.Metrics.reset()
  G.on_flush_click()
  Vermilion.Visibility.set("graph", true)
  local base = SS.count()

  for i = 1, 3 do
    G.on_record_click()
    for _ = 1, 3 do
      H.damage_out({ hit = 500 * i, ability_id = 31, target_unit_id = 900, damage_type = DAMAGE_TYPE_MAGIC })
      H.advance(1000)
    end
    G.on_stop_click()
    H.advance(400)
    H.advance(6000)
  end
  local n = SS.count()
  ok(n == base + 3, "three sessions must be in the library, got " .. n)
  ok(G.loaded_session_index() == nil, "a fresh recording is not a loaded session")

  ok(VermilionGraphWindowPrevSessBtn._hidden ~= true and VermilionGraphWindowNextSessBtn._hidden ~= true, "the session arrows sit in the header")

  ok(G.step_session(-1) == true, "the older arrow with nothing loaded opens the newest session")
  ok(G.loaded_session_index() == n, "the newest session is the last in the store, got " .. tostring(G.loaded_session_index()))
  ok((VermilionGraphWindowStatusLabel._text or ""):find(n .. "/" .. n, 1, true) ~= nil, "the status shows the position in the library, got " .. tostring(VermilionGraphWindowStatusLabel._text))

  ok(G.step_session(-1) == true and G.loaded_session_index() == n - 1, "older steps down the store")
  ok(G.step_session(1) == true and G.loaded_session_index() == n, "newer steps back up")
  ok(G.step_session(1) == false and G.loaded_session_index() == n, "the newest session has no newer neighbour")
  for _ = 1, n - 1 do G.step_session(-1) end
  ok(G.loaded_session_index() == 1, "older walks all the way to the first session")
  ok(G.step_session(-1) == false and G.loaded_session_index() == 1, "the oldest session has no older neighbour")

  G.on_record_click()
  ok(G.loaded_session_index() == nil, "starting a recording drops the loaded session")
  ok(G.step_session(1) == false, "no session steps while a recording runs")
  H.damage_out({ hit = 700, ability_id = 31, target_unit_id = 900, damage_type = DAMAGE_TYPE_MAGIC })
  H.advance(1000)
  G.on_stop_click()
  H.advance(400)
  ok(SS.count() == n + 1, "the new recording autosaves as a fourth session")
  ok(G.step_session(1) == true and G.loaded_session_index() == n + 1, "after a recording either arrow opens the newest session")

  ok(SS.delete(n + 1), "deleting the loaded session")
  ok(G.step_session(1) == true and G.loaded_session_index() == n, "a stale index past the store end counts as nothing loaded, so either arrow opens the newest remaining session")

  G.on_flush_click()
  Vermilion.Visibility.set("graph", false)
  Vermilion.Metrics.reset()
end
