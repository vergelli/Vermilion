return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local T, G = Vermilion.Trace, Vermilion.Graph
  local SV = Vermilion.SavedVars

  ok(Vermilion.Constants.RESEARCH == true, "the research flag is on in this branch")
  ok(VermilionGraphWindowFlagBtn ~= nil and VermilionGraphWindowFlagBtn._hidden == false, "the flag button shows on the research build")
  ok(type(VermilionGraphWindowFlagBtn._onOnMouseEnter) == "function", "the flag button explains itself on hover")
  local xml = assert(io.open(HARNESS_ROOT .. "/bindings.xml")):read("*a")
  ok(xml:find('name="VERMILION_FLAG"', 1, true) ~= nil, "a keybind flags too")

  T.clear(SV)
  SV.evidence = nil
  T.set_auto(SV, true)
  Vermilion.Metrics.reset()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  while VermilionGraphWindowViewLabel._text ~= "CONTRIB" do G.next_view() end

  H.effect(EFFECT_RESULT_GAINED, 5, 777, 0, COMBAT_UNIT_TYPE_PLAYER, "player")
  ok(T.own_uid() == 777, "the player's own unit id is learned from an effect on the player tag")

  H.ability_names = { [31] = "Crystal Frags", [41] = "Hardened Ward" }
  G.on_record_click()
  H.damage_out({ hit = 1000, ability_id = 31 })
  H.shield_out({ hit = 400, ability_id = 41, target_name = "Enemy", target_type = COMBAT_UNIT_TYPE_OTHER, target_unit_id = 900 })
  H.advance(1000)
  H.chat = {}
  H.sounds = {}
  ok(G.on_flag_click() == true, "flagging while recording lands in the trace")
  ok(H.sounds[#H.sounds] == ("sound:" .. Vermilion.Sound.name("confirm")), "a flag confirms with a sound")
  ok(H.chat_contains("evidence flag #1") ~= nil, "the chat says which flag it was")
  H.advance(1000)
  G.on_stop_click()

  ok(SV.trace ~= nil and SV.trace.count > 0, "the recording staged a trace on its own")
  ok(SV.trace.research == true and SV.trace.flags == 1, "the trace is marked as research and counts its flags")
  ok(SV.trace.player and SV.trace.player.uid == 777, "the trace carries the player's unit id")

  local codec = dofile(HARNESS_ROOT .. "/test/simlab/tracecodec.lua")
  local events = codec.decode_chunks(SV.trace.chunks)
  local fl, ids, shielded = nil, 0, 0
  for _, e in ipairs(events) do
    if e.tag == "FL" then fl = e.args[1] end
    if e.tag == "ID" then ids = ids + 1; ok(e.args[4] == 777, "the identity line carries the uid") end
    if e.tag == "CE" and e.args[1] == ACTION_RESULT_DAMAGE_SHIELDED then shielded = shielded + 1 end
  end
  ok(fl ~= nil, "the flag is a line in the trace")
  ok(fl:find("view=CONTRIB", 1, true) and fl:find("mode=live", 1, true), "the flag freezes the view and the mode: " .. tostring(fl))
  ok(fl:find("Hardened Ward", 1, true) ~= nil and fl:find("Crystal Frags", 1, true) ~= nil, "the flag lists the rows the user was looking at: " .. tostring(fl))
  ok(ids >= 1, "the trace records who the player is")
  ok(shielded == 1, "the shield event travels unfiltered in the trace")

  H.chat = {}
  ok(G.on_flag_click() == true, "flagging a stopped graph stages evidence")
  ok(SV.evidence and #SV.evidence.flags == 1 and SV.evidence.flags[1].text:find("mode=stopped", 1, true) ~= nil, "the staged flag says the graph was stopped")

  local sess = Vermilion.SessionStore.capture()
  ok(G.load_session(sess), "the captured session reloads")
  ok(G.on_flag_click() == true, "flagging a library session stages evidence")
  ok(#SV.evidence.flags == 2 and SV.evidence.flags[2].text:find("mode=lib:", 1, true) ~= nil, "the staged flag names the library session")

  H.chat = {}
  SLASH_COMMANDS["/vermilion"]("evidence")
  ok(H.chat_contains("flags=2") ~= nil and H.chat_contains("staged traces=1") ~= nil, "the evidence command reports what is staged")

  T.clear(SV)
  SV.evidence = nil
  H.ability_names = nil
  G.on_flush_click()
  Vermilion.Metrics.reset()
  Vermilion.Visibility.set("graph", false)
end
