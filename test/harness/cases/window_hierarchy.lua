return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local S, L = Vermilion.Settings, Vermilion.Library
  local host, panel, lib = VermilionGraphWindow, VermilionSettingsPanel, VermilionLibrary
  local sv = Vermilion.SavedVars

  local function tier_of(file, name)
    local xml = assert(io.open(HARNESS_ROOT .. "/ui/" .. file)):read("*a")
    local tag = xml:match('<TopLevelControl name="' .. name .. '"(.-)>')
    ok(tag ~= nil, name .. " is declared in " .. file)
    return tag:match('tier="(%u+)"')
  end
  ok(tier_of("graph.xml", "VermilionGraphWindow") == nil, "the main window stays on the lowest tier")
  ok(tier_of("settings.xml", "VermilionSettingsPanel") == "MEDIUM", "Settings always draws over the main window")
  ok(tier_of("library.xml", "VermilionLibrary") == "MEDIUM", "the Library too")
  ok(tier_of("assign.xml", "VermilionAssignPanel") == "MEDIUM", "and Unknown Contributions")
  ok(tier_of("assign.xml", "VermilionAssignConfirm") == "HIGH", "its confirmation draws over Unknown Contributions")
  ok(tier_of("about.xml", "VermilionAbout") == "HIGH", "About opens from Settings and stays over it")
  ok(tier_of("export.xml", "VermilionExport") == "HIGH", "Export stays over the rest")

  local function drop(win, x, y)
    win:ClearAnchors()
    win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
  end
  local function moves_with_host(win)
    local before = win:GetLeft()
    local hx, hy = host:GetLeft(), host:GetTop()
    host:ClearAnchors()
    host:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, hx + 40, hy)
    local moved = win:GetLeft() ~= before
    host:ClearAnchors()
    host:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, hx, hy)
    return moved
  end

  Vermilion.Visibility.set("graph", true)
  host:ClearAnchors()
  host:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 200, 100)
  host:SetDimensions(640, 400)
  if not panel:IsHidden() then S.toggle() end
  S.forget_dock()

  S.toggle()
  ok(panel:GetLeft() == host:GetRight() + 8 and panel:GetTop() == host:GetTop(), "Settings opens stuck to the main window")
  ok(moves_with_host(panel), "and follows it while docked")

  drop(panel, 60, 620)
  S.on_move_stop()
  ok(S.is_detached(), "dragging it away detaches it")
  ok(panel:GetLeft() == 60 and panel:GetTop() == 620, "it stays exactly where it was dropped")
  ok(not moves_with_host(panel), "and no longer follows the main window")
  ok(sv.settings.x == 60 and sv.settings.y == 620, "the place is remembered")

  S.toggle()
  S.toggle()
  ok(panel:GetLeft() == 60 and panel:GetTop() == 620, "a detached window opens where it was left")

  drop(panel, host:GetRight() + 8 + 9, host:GetTop() + 20)
  S.on_move_stop()
  ok(not S.is_detached(), "dropped right next to the edge it sticks again")
  ok(panel:GetLeft() == host:GetRight() + 8 and panel:GetTop() == host:GetTop(), "lined up with the main window")

  drop(panel, host:GetRight() + 8 + 40, host:GetTop())
  S.on_move_stop()
  ok(S.is_detached(), "a little further away it stays free, the magnet is short")

  S.forget_dock()
  ok(not S.is_detached() and panel:GetLeft() == host:GetRight() + 8, "forgetting the place docks it again")
  S.toggle()

  host:ClearAnchors()
  host:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, GuiRoot:GetWidth() - 660, 100)
  S.toggle()
  ok(panel:GetRight() == host:GetLeft() - 8, "with no room on the right it docks on the left")
  S.toggle()
  host:ClearAnchors()
  host:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 200, 100)

  L.forget_dock()
  L.show()
  ok(lib:GetTop() == host:GetBottom() + 8 and lib:GetLeft() == host:GetLeft(), "the Library opens under the main window")
  drop(lib, 900, 30)
  L.on_move_stop()
  ok(L.is_detached() and lib:GetLeft() == 900, "it can be separated too")
  L.hide()
  L.show()
  ok(lib:GetLeft() == 900 and lib:GetTop() == 30, "and opens where it was left")
  L.forget_dock()
  L.hide()

  host:SetDimensions(440, 312)
end
