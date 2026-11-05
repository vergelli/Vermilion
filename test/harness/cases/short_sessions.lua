return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G, SS = Vermilion.Graph, Vermilion.SessionStore
  local sv = Vermilion.SavedVars
  sv.settings = sv.settings or {}
  local before_lib, before_auto, before_min = sv.library, sv.settings.session_autosave, sv.settings.session_min_fight_ms

  sv.library = { version = 1, sessions = {} }
  sv.settings.session_autosave = true
  sv.settings.session_min_fight_ms = nil
  SS.init()
  Vermilion.Metrics.reset()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()

  local function fight(seconds)
    G.on_record_click()
    for i = 0, seconds do
      H.damage_out({ hit = 1000, ability_id = 31 })
      if i < seconds then H.advance(1000) end
    end
    H.advance(1000)
    G.on_stop_click()
    H.advance(400)
  end

  fight(0)
  ok(SS.count() == 0, "one hit is not saved")
  ok(H.chat_contains("not saved"), "and the chat says so")

  G.on_flush_click()
  fight(9)
  ok(SS.count() == 0, "a fight of nine seconds is not saved")

  G.on_flush_click()
  G.on_record_click()
  H.advance(30000)
  G.on_stop_click()
  H.advance(400)
  ok(SS.count() == 0, "a long recording with no damage is not saved")

  G.on_flush_click()
  fight(10)
  ok(SS.count() == 1, "a fight of ten seconds is saved")

  G.on_flush_click()
  fight(1)
  ok(SS.count() == 1, "the short one after it is not")
  ok(SS.save_now(), "the save button still takes it")
  H.advance(400)
  ok(SS.count() == 2, "and it reaches the library")

  sv.library, sv.settings.session_autosave, sv.settings.session_min_fight_ms = before_lib, before_auto, before_min
  SS.init()
  G.on_flush_click()
  Vermilion.Visibility.set("graph", false)
  Vermilion.Metrics.reset()
end
