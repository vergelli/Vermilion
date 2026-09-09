return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G = Vermilion.Graph
  local CV = Vermilion.ContribView

  Vermilion.Metrics.reset()
  Vermilion.TemporalBuffer.clear()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  local view_label = VermilionGraphWindowViewLabel
  while view_label._text ~= "SKILL" do G.next_view() end

  H.ability_names = { [7701] = "Big Hit", [7702] = "Small Hit", [7703] = "Big Hit", [8801] = "Ward" }
  G.on_record_click()
  for _ = 1, 6 do
    H.damage_out({ hit = 3000, ability_id = 7701, damage_type = DAMAGE_TYPE_FIRE })
    H.damage_out({ hit = 500, ability_id = 7703, damage_type = DAMAGE_TYPE_FIRE })
    H.damage_out({ hit = 1000, ability_id = 7702, damage_type = DAMAGE_TYPE_POISON })
    H.shield_out({ hit = 500, ability_id = 8801 })
    H.advance(1000)
  end
  G.on_stop_click()

  while view_label._text ~= "CONTRIB" do G.next_view() end
  ok(VermilionGraphWindowViewportNoDataLabel._hidden == true, "no-data must hide when there are contributions")

  local rows, n = CV.rows()
  ok(n == 3, "three rows expected (two damage names, one shield), got " .. tostring(n))
  ok(rows[1].name == "Big Hit" and rows[1].ch == DAMAGE_TYPE_FIRE, "Big Hit must rank first as fire")
  ok(rows[1].n == 2, "the two Big Hit ability ids merge into one row, got " .. tostring(rows[1].n))
  ok(rows[2].name == "Small Hit" and rows[2].ch == DAMAGE_TYPE_POISON and rows[2].n == 1, "Small Hit must rank second as poison")
  ok(rows[3].name == "Ward" and rows[3].ch == -1, "Ward must rank last as a shield")
  ok(rows[1].v > rows[2].v and rows[2].v > rows[3].v, "rows must be sorted by value")
  local ratio = rows[1].v / rows[2].v
  ok(ratio > 3.0 and ratio < 4.0, "Big Hit must weigh about three and a half Small Hits, got " .. tostring(ratio))
  local t = CV.totals()
  local TB = Vermilion.TemporalBuffer
  local expect, prev = 0, nil
  for i = 1, TB.count() do
    local s = TB.at(i)
    if prev then expect = expect + math.floor(s.eDPS * 10 + 0.5) / 10 * (s.t - prev) / 1000 end
    prev = s.t
  end
  ok(math.abs(t.damage - expect) < 1e-6, "the damage total is the integral of the sampled rate, got " .. tostring(t.damage) .. " vs " .. tostring(expect))
  ok(math.abs(rows[1].v + rows[2].v - t.damage) < 1e-6, "the damage rows add up to the damage total")

  local texts = {}
  for _, c in ipairs(H.controls) do
    local name = c._name or ""
    if c._hidden == false and name:find("^VermilionContribLbl") and c._text then texts[c._text] = true end
  end
  ok(texts["CONTRIBUTION"] and texts["TYPE"] and texts["VALUE"], "column headers must render")
  ok(texts["Big Hit"] and texts["Small Hit"] and texts["Ward"], "every ability name must render")
  local big_rows = 0
  for _, c in ipairs(H.controls) do
    local name = c._name or ""
    if c._hidden == false and name:find("^VermilionContribLbl") and c._text == "Big Hit" then big_rows = big_rows + 1 end
  end
  ok(big_rows == 1, "a skill with two ability ids renders as one row, got " .. big_rows)
  ok(texts["Shield"] == nil and texts[Vermilion.DamageTypeColors.name(DAMAGE_TYPE_FIRE)] == nil, "the type column carries icons, not words")

  local icons, type_icons = 0, {}
  for _, c in ipairs(H.controls) do
    local name = c._name or ""
    if c._hidden == false and name:find("^VermilionContribIcon") then
      icons = icons + 1
      if (c._tex or ""):find("dtype/", 1, true) or (c._tex or ""):find("tabIcon_shield", 1, true) then type_icons[c._tex] = true end
    end
  end
  ok(icons == 6, "an ability icon and a type icon per row, got " .. icons)
  ok(type_icons["Vermilion/assets/dtype/fire.dds"] and type_icons["Vermilion/assets/dtype/poison.dds"], "damage rows wear their damage-type icon")
  ok(type_icons["EsoUI/Art/Inventory/inventory_tabIcon_shield_up.dds"], "the shield row wears the shield icon")
  local zebra = 0
  for _, c in ipairs(H.controls) do
    local name = c._name or ""
    if c._hidden == false and name:find("^VermilionContribSeg") and c._h == 26 and c._a and math.abs(c._a - 0.025) < 1e-6 then zebra = zebra + 1 end
  end
  ok(zebra == 1, "every second row wears a faint band, got " .. zebra)

  local widths, rims = {}, 0
  for _, c in ipairs(H.controls) do
    local name = c._name or ""
    if c._hidden == false and name:find("^VermilionContribSeg") and c._h == 5 and (c._a or 0) > 0.5 then
      widths[#widths + 1] = c._w
    end
    if c._hidden == false and name:find("^VermilionContribRim") and c._h == 7 then rims = rims + 1 end
  end
  table.sort(widths, function(a, b) return a > b end)
  ok(#widths == 3, "one coloured bar per row, got " .. #widths)
  ok(rims == 3, "every bar wears a rim, got " .. rims)
  ok(widths[1] > widths[2] and widths[2] > widths[3], "bars must shrink with the value")
  ok(math.abs(widths[1] / widths[2] - ratio) < 0.35, "bar widths must follow the value ratio")

  local canvas = VermilionGraphWindowViewportCanvas
  local hit    = VermilionGraphHit
  local chip_h = (VermilionGraphSummaryBg._hidden == false) and (VermilionGraphSummaryBg._h + 8) or 0
  local function band_count()
    local k = 0
    for _, c in ipairs(H.controls) do
      local name = c._name or ""
      if c._hidden == false and name:find("^VermilionContribSeg") and c._h == 26 and c._a and math.abs(c._a - 0.10) < 1e-6 then k = k + 1 end
    end
    return k
  end
  ok(band_count() == 0, "no hover band before hovering")
  H.state.mouse_x = canvas:GetLeft() + 60
  H.state.mouse_y = canvas:GetTop() + chip_h + 20 + 12
  hit._onOnMouseEnter(hit)
  H.advance(200)
  ok(VermilionHoverCardName._text == "Big Hit", "hovering the first row must name the skill, got " .. tostring(VermilionHoverCardName._text))
  ok(VermilionHoverCardStat._text and VermilionHoverCardStat._text:find("%d+%%") and VermilionHoverCardStat._text:find("estimated", 1, true),
     "row hover must show share and the estimate note, got " .. tostring(VermilionHoverCardStat._text))
  ok(VermilionHoverCardStat._text:find(Vermilion.DamageTypeColors.name(DAMAGE_TYPE_FIRE), 1, true), "row hover names the damage type, got " .. tostring(VermilionHoverCardStat._text))
  ok(VermilionHoverCardSwatch._tex == "Vermilion/assets/dtype/fire.dds", "the card swatch is the damage-type icon, got " .. tostring(VermilionHoverCardSwatch._tex))
  ok(VermilionHoverCardStat._text:find("2 parts", 1, true), "row hover must count the merged ability ids, got " .. tostring(VermilionHoverCardStat._text))
  ok(CV.hovered() ~= nil and CV.hovered().name == "Big Hit" and band_count() == 1, "the hovered row wears a band")
  H.state.mouse_y = canvas:GetTop() + canvas:GetHeight() + 40
  H.advance(200)
  ok(CV.hovered() == nil and band_count() == 0, "leaving the rows clears the band")
  hit._onOnMouseExit(hit)
  H.state.mouse_x, H.state.mouse_y = 400, 300

  local SS = Vermilion.SessionStore
  local sv = Vermilion.SavedVars
  sv.settings = sv.settings or {}
  local before_lib, before_auto = sv.library, sv.settings.session_autosave
  sv.library = { version = 1, sessions = {} }
  sv.settings.session_autosave = true
  SS.init()
  G.on_record_click()
  H.damage_out({ hit = 2000, ability_id = 7701, damage_type = DAMAGE_TYPE_FIRE })
  H.advance(1000)
  H.damage_out({ hit = 2000, ability_id = 7701, damage_type = DAMAGE_TYPE_FIRE })
  H.shield_out({ hit = 300, ability_id = 8801 })
  H.advance(1000)
  G.on_stop_click()
  H.advance(400)
  ok(SS.count() == 1, "autosave must have stored the session")
  local live_rows, live_n = CV.rows()
  local live_v = live_rows[1].v
  G.on_flush_click()
  ok(G.load_session(SS.get(1)) ~= false, "the saved session must load")
  while view_label._text ~= "CONTRIB" do G.next_view() end
  local lrows, ln = CV.rows()
  ok(ln == live_n and lrows[1].name == "Big Hit", "a library session must render the view from its saved shares")
  ok(math.abs(lrows[1].v - live_v) < 1, "the library row equals the live row, " .. tostring(lrows[1].v) .. " vs " .. tostring(live_v))
  ok(lrows[ln].ch == -1 and lrows[ln].name == "Ward", "the shield row survives the round trip")
  sv.library, sv.settings.session_autosave = before_lib, before_auto
  SS.init()

  G.on_flush_click()
  H.ability_names = nil
  while view_label._text ~= "SKILL" do G.next_view() end
  Vermilion.Visibility.set("graph", false)
  Vermilion.Metrics.reset()
end
