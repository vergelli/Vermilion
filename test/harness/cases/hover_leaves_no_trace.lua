return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G = Vermilion.Graph

  Vermilion.Metrics.reset()
  Vermilion.Visibility.set("graph", true)
  G.on_flush_click()
  local MAGF = COMBAT_MECHANIC_FLAGS_MAGICKA
  H.slotted = { [HOTBAR_CATEGORY_PRIMARY] = { [3] = 501 } }
  H.ability_costs = { [501] = { base = 2700, flags = MAGF, cost = { [MAGF] = 2500 } } }
  H.state.active_bar = HOTBAR_CATEGORY_PRIMARY
  H.state.power = { [POWERTYPE_MAGICKA] = { value = 30000, max = 30000 }, [POWERTYPE_STAMINA] = { value = 20000, max = 20000 } }
  Vermilion.ResourcesView.set_pick(3)
  G.on_record_click()
  H.effect(EFFECT_RESULT_GAINED, 61, 900, (H.now() + 40000) / 1000, COMBAT_UNIT_TYPE_PLAYER, "boss1", BUFF_EFFECT_TYPE_DEBUFF)
  H.effect(EFFECT_RESULT_GAINED, 62, 900, (H.now() + 40000) / 1000, COMBAT_UNIT_TYPE_PLAYER, "boss1", BUFF_EFFECT_TYPE_DEBUFF)
  local mag = 30000
  for _ = 1, 30 do
    H.skill_used(3)
    mag = mag - 2500
    H.res_power(POWERTYPE_MAGICKA, mag, 30000)
    H.energize({ amount = 2500, pool = MAGF, ability_id = 701 })
    mag = mag + 2500
    H.res_power(POWERTYPE_MAGICKA, mag, 30000)
    H.damage_out({ hit = 1000, ability_id = 501, target_unit_id = 900 })
    H.damage_out({ hit = 500, ability_id = 32, target_unit_id = 900 })
    H.advance(1000)
  end
  G.on_stop_click()

  local canvas, hit = VermilionGraphWindowViewportCanvas, VermilionGraphHit
  local lists = {
    { "PRESSURE", Vermilion.TargetsView },
    { "CONTRIB", Vermilion.ContribView },
    { "DEBUFFS", Vermilion.DebuffsView },
    { "RESOURCES", Vermilion.ResourcesView },
    { "UPTIME", Vermilion.UptimeView },
  }
  for _, item in ipairs(lists) do
    local name, view = item[1], item[2]
    while VermilionGraphWindowViewLabel._text ~= name do G.next_view() end
    local found = false
    H.state.mouse_x = canvas:GetLeft() + canvas:GetWidth() * 0.5
    hit._onOnMouseEnter(hit)
    for y = 2, canvas:GetHeight() - 2, 4 do
      H.state.mouse_y = canvas:GetTop() + y
      H.advance(60)
      if view.hovered() ~= nil then
        found = true
        break
      end
    end
    ok(found, name .. " has a row to hover")
    hit._onOnMouseExit(hit)
    ok(view.hovered() == nil, "leaving the chart clears the hovered row in " .. name)
  end

  H.state.mouse_x, H.state.mouse_y = 400, 300
  H.slotted, H.ability_costs = nil, nil
  G.on_flush_click()
  Vermilion.Visibility.set("graph", false)
  Vermilion.Metrics.reset()
end
