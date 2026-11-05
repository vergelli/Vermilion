return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G, SS = Vermilion.Graph, Vermilion.SessionStore
  local sv = Vermilion.SavedVars
  sv.settings = sv.settings or {}
  local before_lib, before_auto = sv.library, sv.settings.session_autosave

  sv.library = { version = 1, sessions = {} }
  sv.settings.session_autosave = true
  SS.init()
  Vermilion.Metrics.reset()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()

  G.on_record_click()
  H.advance(45000)
  G.on_stop_click()
  H.advance(400)
  ok(SS.count() == 0, "a long recording with no damage is not saved")
  ok(H.chat_contains("not saved"), "and the chat says so")
  ok(not G.save_available(), "and the save button has nothing to keep")
  ok(not SS.save_now(), "not even by hand")
  H.advance(400)
  ok(SS.count() == 0, "so the library stays empty")

  G.on_flush_click()
  G.on_record_click()
  H.damage_out({ hit = 1000, ability_id = 31 })
  H.advance(1000)
  G.on_stop_click()
  H.advance(400)
  ok(SS.count() == 1, "one hit is a contribution, however short")

  G.on_flush_click()
  G.on_record_click()
  H.shield_out({ hit = 500, ability_id = 8801 })
  H.advance(2000)
  G.on_stop_click()
  H.advance(400)
  ok(SS.count() == 2, "a cracked shield is too")

  sv.library, sv.settings.session_autosave = before_lib, before_auto
  SS.init()
  G.on_flush_click()
  Vermilion.Visibility.set("graph", false)
  Vermilion.Metrics.reset()
end
