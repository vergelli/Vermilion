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

  local function hit(name, uid, amount, ttype)
    H.damage_out({ hit = amount, ability_id = 31, target_name = name, target_unit_id = uid, target_type = ttype or COMBAT_UNIT_TYPE_NONE })
  end
  local function stop()
    H.advance(1000)
    G.on_stop_click()
    H.advance(400)
    local s = SS.get(SS.count())
    return s, s.head
  end

  H.set_bosses({})
  G.on_record_click()
  hit("Corrupted Infantry^M", 801, 1000)
  hit("Corrupted Infantry^F", 802, 1000)
  hit("Spider^n", 803, 1500)
  local _, head = stop()
  ok(head.boss == nil, "a pull with no boss has no boss name")
  ok(head.top == "Corrupted Infantry", "it takes the enemy that took the most damage, merged by name, got " .. tostring(head.top))
  ok(SS.title(head) == "Corrupted Infantry", "and is titled after it")
  ok(head.sum.exact.pool, "an automatic save keeps the pool totals")

  G.on_flush_click()
  G.on_record_click()
  H.set_bosses({ { name = "Uulgarg the Risen" } })
  hit("Uulgarg the Risen^M", 900, 500)
  hit("Skeleton^n", 901, 9000)
  H.set_bosses({})
  local sess
  sess, head = stop()
  ok(head.boss == "Uulgarg the Risen", "a boss hit during the recording names it, even dead by the end, got " .. tostring(head.boss))
  ok(SS.title(head) == "Uulgarg the Risen", "the boss wins over an add that took more")
  ok(G.load_session(sess), "the session loads")
  ok(VermilionGraphWindowStatusLabel._text:find("Uulgarg the Risen", 1, true), "the status names it, got " .. tostring(VermilionGraphWindowStatusLabel._text))
  ok(VermilionGraphWindowStatusLabel._text:find(head.zone, 1, true), "next to the zone")
  ok(Vermilion.ExportReport.SECTIONS[1]():find("Fight: Uulgarg the Risen", 1, true), "the export names the fight")

  head.label = "My pull"
  ok(SS.title(head) == "My pull", "a name given by hand wins over everything")
  head.label = nil

  G.on_flush_click()
  H.set_bosses({ { name = "Far Away Boss" } })
  G.on_record_click()
  hit("Skeleton^n", 901, 1000)
  _, head = stop()
  ok(head.boss == nil, "a boss on the bar that was never hit does not name the fight")
  ok(head.top == "Skeleton", "the enemy that was hit does")
  H.set_bosses({})

  G.on_flush_click()
  G.on_record_click()
  hit("Some Player^Mx", 950, 1000, COMBAT_UNIT_TYPE_OTHER)
  _, head = stop()
  ok(head.top == nil and head.boss == nil, "a fight against players does not take a player's name")
  ok(SS.title(head) == head.zone, "it stays with the zone")

  ok(SS.title({ zone = "Old Zone" }) == "Old Zone", "an older session keeps its zone")

  sv.library, sv.settings.session_autosave = before_lib, before_auto
  SS.init()
  G.on_flush_click()
  Vermilion.Visibility.set("graph", false)
  Vermilion.Metrics.reset()
end
