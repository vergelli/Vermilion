return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local SS = Vermilion.SessionStore
  local TB = Vermilion.TemporalBuffer
  local sv = Vermilion.SavedVars
  local L  = Vermilion.Library

  sv.settings = sv.settings or {}
  sv.library = { version = 1, sessions = {} }
  sv.settings.session_autosave = true
  H.state.grouped = true
  H.state.group_size = 3
  H.state.player_group_tag = "group1"
  H.state.zone = "Direfrost Keep"
  H.fire(EVENT_GROUP_UPDATE)
  Vermilion.Metrics.reset()
  Vermilion.Graph.on_flush_click()

  Vermilion.Graph.on_record_click()
  H.damage_out({ hit = 900, ability_id = 31 })
  H.damage_out({ hit = 500, ability_id = 32, result = ACTION_RESULT_CRITICAL_DAMAGE, damage_type = DAMAGE_TYPE_FIRE })
  H.advance(1200)
  H.shield_out({ hit = 300 })
  H.advance(400)
  H.damage_out({ hit = 3000, ability_id = 31 })
  H.advance(2600)
  H.damage_out({ hit = 100, ability_id = 33, damage_type = DAMAGE_TYPE_POISON })
  H.advance(1500)

  H.state.grouped = false
  H.state.group_size = 0
  H.state.zone = "Elsweyr"
  H.fire(EVENT_GROUP_MEMBER_LEFT)
  H.advance(500)

  Vermilion.Graph.on_stop_click()
  H.advance(400)
  ok(SS.count() == 1, "session must autosave")
  local saved = SS.get(1)
  ok(saved.head.zone == "Direfrost Keep", "zone must be captured at session start, got " .. tostring(saved.head.zone))
  ok(saved.head.group_size == 3, "group size must be captured at session start")

  local live_n = TB.count()
  local live_peak, live_sum = 0, 0
  local live_shares, live_abilities, live_dtypes = 0, 0, 0
  TB.iterate(function(_, s)
    local eos = s.eDPS + s.ShDPS
    live_sum = live_sum + eos
    if eos > live_peak then live_peak = eos end
    live_shares = live_shares + (s.eos_groups.count or 0)
    live_abilities = live_abilities + (s.eos_abilities.count or 0)
    live_dtypes = live_dtypes + (s.dtype_groups.count or 0)
  end)

  Vermilion.Graph.on_flush_click()
  ok(TB.count() == 0, "flush must empty the buffer")

  L.show()
  ok(VermilionLibrary._hidden == false, "library window must show")
  ok(VermilionLibraryRow1Name._text == "Direfrost Keep", "row must show the zone, got " .. tostring(VermilionLibraryRow1Name._text))
  ok(VermilionLibraryRow1Stats._text:find("%", 1, true) ~= nil, "the row carries the crit share")
  ok(VermilionLibraryRow1Vet._hidden == ((saved.head.difficulty or 0) ~= 2), "the veteran badge follows the difficulty")
  L.on_row_click(1)
  VermilionLibraryLabelBoxEdit:SetText("  Sunday HM run  ")
  L.on_label_save()
  ok(SS.get(1).head.label == "Sunday HM run", "the label is trimmed and persisted on the session head")
  ok(VermilionLibraryRow1Name._text == "Sunday HM run", "the row shows the name instead of the zone")
  VermilionLibraryLabelBoxEdit:SetText("")
  L.on_label_save()
  ok(SS.get(1).head.label == nil and VermilionLibraryRow1Name._text == "Direfrost Keep", "an empty name goes back to the zone")
  ok(type(VermilionLibraryRow1._onOnMouseDoubleClick) == "function", "rows open on double click")
  VermilionLibraryRow1._onOnMouseDoubleClick(VermilionLibraryRow1)
  ok(VermilionLibrary._hidden == true, "library must hide after open")

  ok(TB.count() == live_n, "reloaded sample count differs: " .. TB.count() .. " vs " .. live_n)
  local peak2, sum2 = 0, 0
  local shares2, abilities2, dtypes2, dtype_ability_keys = 0, 0, 0, 0
  local ability_id_ok, ability_color_ok = false, false
  TB.iterate(function(_, s)
    local eos = s.eDPS + s.ShDPS
    sum2 = sum2 + eos
    if eos > peak2 then peak2 = eos end
    shares2 = shares2 + (s.eos_groups.count or 0)
    abilities2 = abilities2 + (s.eos_abilities.count or 0)
    dtypes2 = dtypes2 + (s.dtype_groups.count or 0)
    local ea = s.eos_abilities
    if ea.count > 0 and ea[1].id and ea[1].id > 0 then ability_id_ok = true end
    if ea.count > 0 and ea[1].r ~= nil and ea[1].key ~= nil then ability_color_ok = true end
    local da = s.dtype_abilities
    for k = 1, da.count or 0 do
      if type(da[k].key) == "number" then dtype_ability_keys = dtype_ability_keys + 1 end
    end
  end)
  ok(math.abs(sum2 - live_sum) < live_n, "reloaded eos sum differs: " .. sum2 .. " vs " .. live_sum)
  ok(math.abs(peak2 - live_peak) < 1, "reloaded peak differs: " .. peak2 .. " vs " .. live_peak)
  ok(shares2 == live_shares, "reloaded skill-line shares differ: " .. shares2 .. " vs " .. live_shares)
  ok(abilities2 == live_abilities, "reloaded ability shares differ: " .. abilities2 .. " vs " .. live_abilities)
  ok(dtypes2 == live_dtypes, "reloaded damage-type shares differ: " .. dtypes2 .. " vs " .. live_dtypes)
  ok(ability_id_ok and ability_color_ok, "reloaded ability entries keep ids, keys and colors")
  ok(dtype_ability_keys > 0, "reloaded damage-type abilities keep their damage type")
  ok(VermilionGraphWindowStatusLabel._text:find("Direfrost", 1, true), "status banner must show the loaded zone")
  ok(VermilionGraphWindowSaveBtn._enabled == false, "a library session cannot be saved again")
  ok(Vermilion.Graph.on_save_click() == false and SS.count() == 1, "pressing save on a loaded session never duplicates")

  Vermilion.Graph.on_record_click()
  ok(Vermilion.Graph.load_session(SS.get(1)) == false, "loading while recording must be refused")
  Vermilion.Graph.on_stop_click()
  H.advance(400)

  L.show()
  L.on_row_enter(1)
  ok(H.last_tooltip and H.last_tooltip:find("2026-09-03", 1, true) and H.last_tooltip:find("Direfrost Keep", 1, true)
     and H.last_tooltip:find("players", 1, true), "the row tooltip leads with date, place and group: " .. tostring(H.last_tooltip))
  ok(H.last_tooltip and H.last_tooltip:find("damage", 1, true) and H.last_tooltip:find("crit", 1, true),
     "row tooltip must explain the damage totals")
  L.on_row_exit(1)
  L.on_row_click(1)
  L.on_lock_click()
  ok(SS.get(SS.count()).head.locked == true, "lock must persist on the session")
  local before = SS.count()
  L.on_delete_click()
  L.on_delete_click()
  ok(SS.count() == before, "locked sessions must refuse deletion")
  ok(VermilionLibraryDeleteBtn._enabled == false, "delete button must disable on locked rows")
  ok(VermilionLibraryLockBtnIcon._tex == "EsoUI/Art/Miscellaneous/unlocked_up.dds", "a locked row offers the unlock icon")
  L.on_lock_click()
  ok(VermilionLibraryLockBtnIcon._tex == "EsoUI/Art/Miscellaneous/locked_up.dds", "an unlocked row offers the lock icon")
  L.on_delete_click()
  ok(SS.count() == before and VermilionLibraryDeleteBtn._text == "Delete?", "the first Delete click only arms")
  L.on_delete_click()
  ok(SS.count() == before - 1, "the second Delete click deletes after unlock")
  ok(VermilionLibraryOpenBtnIcon and VermilionLibraryLockBtnIcon and VermilionLibraryDeleteBtnIcon, "the action buttons carry icons")

  for i = 1, 14 do
    SS.store({ head = { locked = false, zone = "Scroll" .. i, ts = 1755900000,
                        dur_ms = 1000, group_size = 0,
                        sum = { avg = 0, peak = 0 } },
               streams = {} })
  end
  L.show()
  ok(VermilionLibraryRow1Name._text == "Scroll14", "top row must be newest")
  ok(VermilionLibraryRow1Kind._hidden == true, "a session without a kind shows no icon")
  ok(VermilionLibraryScrollDown._hidden == false and VermilionLibraryScrollUp._hidden == true,
     "with newer rows on top only the down chevron shows")
  L.on_scroll(-1)
  L.on_scroll(-1)
  ok(VermilionLibraryRow1Name._text == "Scroll12",
     "scrolling down must reveal older sessions, got " .. tostring(VermilionLibraryRow1Name._text))
  ok(VermilionLibraryScrollUp._hidden == false and VermilionLibraryScrollDown._hidden == false,
     "mid-list both chevrons show")
  L.on_scroll(-1)
  L.on_scroll(-1)
  ok(VermilionLibraryScrollDown._hidden == true, "at the oldest row the down chevron hides")

  local track = VermilionLibraryScrollTrack
  local thumb = VermilionLibraryScrollTrackThumb
  ok(track._hidden == false, "the scrollbar shows when rows overflow")
  ok((thumb._h or 0) >= 16 and (thumb._h or 0) < track:GetHeight(), "the thumb is proportional")
  H.state.mouse_x = track:GetLeft() + 4
  H.state.mouse_y = track:GetTop() + 1
  L.on_track_click()
  ok(VermilionLibraryRow1Name._text == "Scroll14", "clicking the top of the track jumps to the newest, got " .. tostring(VermilionLibraryRow1Name._text))
  H.state.mouse_y = track:GetTop() + track:GetHeight() - 1
  L.on_track_click()
  ok(VermilionLibraryRow1Name._text == "Scroll10", "clicking the bottom of the track jumps to the oldest, got " .. tostring(VermilionLibraryRow1Name._text))
  L.on_thumb_down()
  ok(VermilionLibrary._onOnUpdate ~= nil, "dragging arms the update handler")
  H.state.mouse_y = track:GetTop() + 1
  VermilionLibrary._onOnUpdate(VermilionLibrary)
  ok(VermilionLibraryRow1Name._text == "Scroll14", "dragging the thumb to the top reaches the newest, got " .. tostring(VermilionLibraryRow1Name._text))
  L.on_thumb_up()
  ok(VermilionLibrary._onOnUpdate == nil, "releasing the thumb disarms the update handler")
  L.on_scroll(-1)
  ok(VermilionLibraryRow1Name._text == "Scroll13", "the chevron path still steps one row")
  L.on_label_focus(true)
  L.on_label_focus(false)
  L.hide()

  ok(L.on_key == nil, "the library never takes the keyboard")
  for _, name in ipairs({ "ui/library.xml", "ui/graph.xml", "ui/settings.xml", "ui/assign.xml", "ui/logo.xml" }) do
    local f = io.open(HARNESS_ROOT .. "/" .. name)
    if f then
      local body = f:read("*a"); f:close()
      ok(not body:find("keyboardEnabled", 1, true) and not body:find("OnKeyDown", 1, true), name .. " must not capture the keyboard")
    end
  end

  sv.settings.session_autosave = false
  sv.library = { version = 1, sessions = {} }
  H.state.grouped = false
  H.state.group_size = 1
  H.state.player_group_tag = nil
  H.state.zone = nil
  Vermilion.Graph.on_flush_click()
  Vermilion.Metrics.reset()
end
