return function(H)
  local function ok(cond, msg) if not cond then error(msg, 2) end end
  local G = Vermilion.Graph

  Vermilion.Metrics.reset()
  Vermilion.Visibility.set("graph", false)
  G.on_record_click()
  for _ = 1, 10 do
    H.damage_out({ hit = 1000, ability_id = 31 })
    H.damage_out({ hit = 300, ability_id = 32, result = ACTION_RESULT_CRITICAL_DAMAGE, damage_type = DAMAGE_TYPE_FIRE })
    H.shield_out({ hit = 200 })
    H.advance(1000)
  end

  local TICKS = 50
  local per_tick = H.addon_alloc(function()
    for _ = 1, TICKS do H.advance(1000) end
  end) / TICKS
  local budget = HARNESS_DEBUG and 9000 or 600
  ok(per_tick < budget, string.format("sample tick allocates %.0f addon-side bytes (interim budget %d until the header text caching of M9; Verdant holds 200)", per_tick, budget))

  local function ticks()
    for _ = 1, 10 do
      H.damage_out({ hit = 1000, ability_id = 31 })
      H.damage_out({ hit = 300, ability_id = 32, result = ACTION_RESULT_CRITICAL_DAMAGE, damage_type = DAMAGE_TYPE_FIRE })
      H.advance(1000)
    end
  end
  local baseline = H.addon_alloc(ticks) / 10
  Vermilion.Visibility.set("graph", true)
  local label = VermilionGraphWindowViewLabel
  for _, view in ipairs({ "SKILL", "TYPE", "OUTCOME", "CRIT" }) do
    local guard = 0
    while label._text ~= view and guard < 6 do G.next_view(); guard = guard + 1 end
    H.advance(1000)
    local bytes = H.addon_alloc(ticks) / 10 - baseline
    ok(bytes < 3000, string.format("%s render tick allocates %.0f addon-side bytes over the hidden baseline (interim budget 3000 until the render pass of M9; Verdant holds 400)", view, bytes))
  end
  Vermilion.Visibility.set("graph", false)

  G.on_stop_click()
  G.on_flush_click()
  Vermilion.Metrics.reset()
end
