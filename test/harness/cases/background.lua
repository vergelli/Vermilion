return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local Skin, S = Vermilion.Skin, Vermilion.Settings
  local sv = Vermilion.SavedVars
  local top, left = VermilionGraphWindowChromeTop, VermilionGraphWindowChromeLeft

  ok(#Skin.backgrounds() == 11, "eleven backgrounds, got " .. #Skin.backgrounds())
  ok(Skin.background() == "piano", "Piano is the default, got " .. tostring(Skin.background()))
  ok(top._tex == Skin.background_path("piano"), "the window shows the background in use")
  ok(VermilionAboutBg._center_tex == top._tex, "the other windows show the same one")
  for _, frame in ipairs({ VermilionSettingsPanelBg, VermilionAssignPanelBg, VermilionAssignConfirmBg, VermilionAboutBg, VermilionLibraryBg, VermilionExportBg }) do
    ok(frame._er == 1 and frame._eg == 1 and frame._eb == 1, "every window keeps the gold of its frame untinted")
  end
  ok(VermilionAboutBg._center_interval == 512 and VermilionAboutBg._center_mode == TEX_MODE_WRAP, "they repeat it at real scale instead of squeezing it")

  Skin.load_background("no_such_background")
  ok(Skin.background() == "piano", "an unknown saved value falls back to Piano")
  Skin.load_background("ruby")
  ok(Skin.background() == "ruby", "a saved value is honoured")
  Skin.set_background(nil)
  ok(Skin.background() == "piano" and top._tex == Skin.background_path("piano"), "no value means Piano")

  local shown = VermilionSettingsPanel:IsHidden()
  if shown then S.toggle() end
  local btn = VermilionSettingsPanelBackgroundBtn
  ok(btn._text == "Background: Piano", "the button names the background, got " .. tostring(btn._text))
  ok(btn._normal == Skin.PLAIN.up, "the button wears the skin")

  S.on_background_click()
  local list = S.background_list()
  ok(list.is_open(), "a click opens the list")
  ok(#list.rows == 11, "one row per background")
  ok(list.rows[1].label._text == "Piano" and list.rows[11].label._text == "Veins", "named in order")
  ok(list.rows[1].label._r == Skin.GOLD.r, "the one in use is marked")
  ok(list.root._draw_layer == DL_OVERLAY, "the list draws over the window")
  ok(VermilionSettingsPanelBackgroundListBg._center_tex == top._tex, "the list wears the background too")

  local row = list.rows[7]
  ok(row.key == "goldstone", "row seven is Goldstone")
  row.hit._onOnMouseEnter(row.hit)
  ok(row.hot._hidden == false, "hover lights the row")
  row.hit._onOnMouseExit(row.hit)
  ok(row.hot._hidden == true, "and it goes off")
  row.hit._onOnMouseUp(row.hit, 1, true)
  ok(not list.is_open(), "picking closes the list")
  ok(Skin.background() == "goldstone", "picking applies it")
  ok(sv.settings.background == "goldstone", "and saves it")
  ok(btn._text == "Background: Goldstone", "the button follows, got " .. tostring(btn._text))
  ok(top._tex == Skin.background_path("goldstone") and left._tex == top._tex, "all the strips change")
  ok(VermilionAboutBg._center_tex == top._tex and VermilionLibraryBg._center_tex == top._tex and VermilionSettingsPanelBg._center_tex == top._tex, "all the windows change")
  ok(top._vtop > top._r, "the top strip keeps its light")
  ok(top._r == left._r, "and the strips one tone")

  S.on_background_click()
  ok(list.rows[1].label._r == Skin.TEXT.r and list.rows[7].label._r == Skin.GOLD.r, "the mark moves")
  local real_mouse = GetUIMousePosition
  GetUIMousePosition = function() return btn:GetLeft() + 2, btn:GetTop() + 2 end
  Vermilion.zenimax.api.GetUIMousePosition = GetUIMousePosition
  list.away()
  ok(list.is_open(), "a click on the button is not a click away")
  GetUIMousePosition = function() return -500, -500 end
  Vermilion.zenimax.api.GetUIMousePosition = GetUIMousePosition
  list.away()
  ok(not list.is_open(), "a click elsewhere closes it")
  GetUIMousePosition = real_mouse
  Vermilion.zenimax.api.GetUIMousePosition = real_mouse

  S.on_background_click()
  ok(list.is_open(), "it opens again")
  S.toggle()
  ok(not list.is_open(), "closing Settings closes the list")
  S.toggle()

  S.on_reset_click()
  ok(sv.settings.background == nil and Skin.background() == "piano", "reset goes back to Piano")
  ok(btn._text == "Background: Piano", "and the button says so")

  local Cost = Vermilion.BackgroundCost
  if Vermilion.Constants.DEBUG then
    Cost.run()
    ok(Cost.running(), "the measurement starts")
    VermilionBackgroundProbe.IsTextureLoaded = function() return true end
    for _ = 1, 5000 do
      if not Cost.running() then break end
      Cost.step()
    end
    ok(not Cost.running(), "the measurement ends")
    local report = table.concat(sv.debug.background_cost, "\n")
    ok(report:find("baseline frame", 1, true) and report:find("piano", 1, true) and report:find("veins", 1, true), "it reports every background")
    ok(not report:find("never", 1, true), "all of them load")
    sv.debug.background_cost = nil
  else
    Cost.run()
    ok(not Cost.running() and rawget(_G, "VermilionBackgroundProbe") == nil, "a release build measures nothing")
  end

  if shown then S.toggle() end
end
