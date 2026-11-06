SIMLAB_ROOT = arg[1] or "."
HARNESS_ROOT = SIMLAB_ROOT
HARNESS_DEBUG = (arg[4] == "1")
local seed, steps = tonumber(arg[2]) or 1, tonumber(arg[3]) or 400

dofile(SIMLAB_ROOT .. "/test/harness/mock_eso.lua")
dofile(SIMLAB_ROOT .. "/test/harness/loader.lua")
HARNESS.fire(EVENT_ADD_ON_LOADED, "Vermilion")

local H = HARNESS
local rng = dofile(SIMLAB_ROOT .. "/test/simlab/prng.lua").new(seed * 7919 + 17)
local G, M, TB, SS = Vermilion.Graph, Vermilion.Metrics, Vermilion.TemporalBuffer, Vermilion.SessionStore
local S, W, O = Vermilion.Settings, Vermilion.FilmWindow, Vermilion.FilmOverview

local step = 0
local trail, counts = {}, {}

local function fail(rule, detail)
  print(string.format("MONKEY FAIL seed=%d step=%d rule=%s", seed, step, rule))
  print("  " .. tostring(detail))
  local first = math.max(1, #trail - 30)
  print("  last actions: " .. table.concat(trail, " ", first))
  os.exit(1)
end

local function check(rule, cond, detail)
  counts[rule] = (counts[rule] or 0) + 1
  if not cond then fail(rule, detail) end
end

local ABILITIES = {
  { 31, DAMAGE_TYPE_PHYSICAL }, { 32, DAMAGE_TYPE_BLEED }, { 33, DAMAGE_TYPE_BLEED },
  { 34, DAMAGE_TYPE_MAGIC }, { 35, DAMAGE_TYPE_FIRE }, { 36, DAMAGE_TYPE_DISEASE },
}
H.ability_names = H.ability_names or {}
H.ability_names[32], H.ability_names[33] = "Twin Bleed", "Twin Bleed"
local RESULTS = { ACTION_RESULT_DAMAGE, ACTION_RESULT_CRITICAL_DAMAGE, ACTION_RESULT_DOT_TICK, ACTION_RESULT_DOT_TICK_CRITICAL }
local EFFECTS = { 61, 62, 63, 64 }
H.ability_icons = H.ability_icons or {}
for _, id in ipairs(EFFECTS) do
  H.ability_names[id] = "Effect " .. id
  H.ability_icons[id] = "effect" .. id .. ".dds"
end
for _, a in ipairs(ABILITIES) do
  H.ability_icons[a[1]] = "skill" .. a[1] .. ".dds"
end
local MAGF, STAF = COMBAT_MECHANIC_FLAGS_MAGICKA, COMBAT_MECHANIC_FLAGS_STAMINA
H.slotted = { [HOTBAR_CATEGORY_PRIMARY] = { [3] = 61, [4] = 62, [5] = 63, [6] = 64 } }
H.ability_costs = {
  [61] = { base = 2700, flags = MAGF, cost = { [MAGF] = 2500 } },
  [62] = { base = 2200, flags = STAF, cost = { [STAF] = 2200 } },
  [63] = { base = 2700, flags = MAGF, cost = { [MAGF] = 2500 } },
  [64] = { base = 2200, flags = STAF, cost = { [STAF] = 2200 } },
}
H.state.active_bar = HOTBAR_CATEGORY_PRIMARY
H.state.power = { [POWERTYPE_MAGICKA] = { value = 30000, max = 30000 }, [POWERTYPE_STAMINA] = { value = 20000, max = 20000 } }
local profile = { ult = true, power = true, effects = true, shields = true }
local function new_profile()
  profile.ult = rng:chance(0.5)
  profile.power = rng:chance(0.7)
  profile.effects = rng:chance(0.7)
  profile.shields = rng:chance(0.5)
end
local function allowed(flag, weight)
  return function()
    if TB.is_recording() and not profile[flag] then return 0 end
    return weight
  end
end
local BAR_VIEWS = { "SKILL", "TYPE", "CRIT" }
local ALL_VIEWS = { "SKILL", "TYPE", "PRESSURE", "CRIT", "CONTRIB", "DEBUFFS", "RESOURCES", "UPTIME" }
local IGNORED = {
  "^VermilionLibrary", "^VermilionSettings", "^VermilionExport", "^VermilionAssign", "^VermilionAbout",
  "^VermilionDev", "^VermilionLogo", "^VermilionHoverCard", "StatusLabel", "RecModeLabel", "Btn", "Pulse", "Tab%d",
}

local function new_ledger()
  return { damage = 0, shield = 0, hits = 0, first = nil, last = nil, skills = {}, targets = {} }
end
local ledger, ledger_valid, closed_ledger = new_ledger(), false, nil
local was_recording, loaded, stored_fight = false, false, nil
local chip_at_stop, count_at_stop
local sessions_seen, frozen, screens = 0, {}, {}
local looks = {}

local function chip_text() return VermilionGraphSummaryLabel._text or "" end

local function show_view(view)
  local guard = 0
  while VermilionGraphWindowViewLabel._text ~= view do
    G.next_view()
    guard = guard + 1
    if guard > 20 then fail("views", "could not reach " .. view) end
  end
end

local function ignored(name)
  for i = 1, #IGNORED do
    if name:find(IGNORED[i]) then return true end
  end
  return false
end

local function n2(v) return v and string.format("%.2f", v) or "" end

local function screen()
  local lines = {}
  local strip_hidden = VermilionFilmStrip._hidden == true
  for _, c in ipairs(H.controls) do
    local name = c._name
    if c._hidden == false and type(name) == "string" and name:find("^Vermilion") and not ignored(name)
       and not (strip_hidden and name:find("^VermilionFilmStrip")) then
      local a = c._anchor_list and c._anchor_list[1]
      lines[#lines + 1] = table.concat({
        (name:gsub("%d+$", "")), a and n2(a.ox) or "0", a and n2(a.oy) or "0",
        tostring(c._text or ""), tostring(c._tex or ""), n2(c._w), n2(c._h),
        n2(c._r), n2(c._g), n2(c._b), n2(c._a),
      }, "|")
    end
  end
  table.sort(lines, function(x, y)
    local nx, ax, bx = x:match("^(.-)|(.-)|(.-)|")
    local ny, ay, by = y:match("^(.-)|(.-)|(.-)|")
    if nx ~= ny then return nx < ny end
    local a1, a2 = tonumber(ax) or 0, tonumber(ay) or 0
    if a1 ~= a2 then return a1 < a2 end
    local b1, b2 = tonumber(bx) or 0, tonumber(by) or 0
    if b1 ~= b2 then return b1 < b2 end
    return x < y
  end)
  return lines
end

local function by_kind(lines)
  local kinds = {}
  for _, line in ipairs(lines) do
    local kind = line:match("^(.-)|") or line
    kinds[kind] = (kinds[kind] or 0) + 1
  end
  return kinds
end

local function kind_changes(a, b)
  local ka, kb, out = by_kind(a), by_kind(b), {}
  for kind, n in pairs(ka) do
    if kb[kind] ~= n then out[#out + 1] = string.format("%s %d->%d", kind, n, kb[kind] or 0) end
  end
  for kind, n in pairs(kb) do
    if not ka[kind] then out[#out + 1] = string.format("%s 0->%d", kind, n) end
  end
  table.sort(out)
  return table.concat(out, ", ")
end

local function first_difference(a, b)
  for i = 1, math.max(#a, #b) do
    if a[i] ~= b[i] then
      return string.format("line %d of %d/%d:\n    was %s\n    now %s\n    kinds: %s", i, #a, #b, tostring(a[i]), tostring(b[i]), kind_changes(a, b))
    end
  end
  return nil
end

local function split(line)
  local parts = {}
  for field in (line .. "|"):gmatch("(.-)|") do parts[#parts + 1] = field end
  return parts
end

local function near_difference(a, b)
  if #a ~= #b then return string.format("%d controls were %d", #b, #a) end
  for i = 1, #a do
    if a[i] ~= b[i] then
      local pa, pb = split(a[i]), split(b[i])
      if #pa ~= #pb then return a[i] .. "\n    now " .. b[i] end
      for f = 1, #pa do
        if pa[f] ~= pb[f] then
          local na, nb = tonumber(pa[f]), tonumber(pb[f])
          if not (na and nb and math.abs(na - nb) <= 1.01) then
            return string.format("line %d field %d:\n    was %s\n    now %s", i, f, a[i], b[i])
          end
        end
      end
    end
  end
  return nil
end

local function serialize(v, out)
  local tv = type(v)
  if tv == "table" then
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(x, y)
      if type(x) ~= type(y) then return type(x) < type(y) end
      return x < y
    end)
    out[#out + 1] = "{"
    for _, k in ipairs(keys) do
      out[#out + 1] = tostring(k) .. "="
      serialize(v[k], out)
      out[#out + 1] = ","
    end
    out[#out + 1] = "}"
  else
    out[#out + 1] = tostring(v)
  end
end

local function frozen_text(sess)
  local out = {}
  serialize(sess, out)
  return table.concat(out)
end

local function fight_of(l)
  if l.first and l.last and l.last > l.first then return l.last - l.first end
  return 0
end

local function copy_ledger(l)
  return { damage = l.damage, shield = l.shield, hits = l.hits, first = l.first, last = l.last }
end

local function settings_key()
  local w, h = VermilionGraphWindow:GetDimensions()
  return table.concat({
    tostring(S.average_line()), tostring(S.median_line()), tostring(S.zoom_local_scale()),
    tostring(S.kill_markers()), n2(w), n2(h),
  }, "/")
end

local function report_rows()
  local hit = VermilionGraphSummaryHit
  hit._onOnMouseEnter(hit)
  local rows = {}
  for i = 1, 19 do
    local name, val = rawget(_G, "VermilionHoverCardRowName" .. i), rawget(_G, "VermilionHoverCardRowVal" .. i)
    if name and name._hidden == false then rows[#rows + 1] = tostring(name._text) .. " = " .. tostring(val._text) end
  end
  hit._onOnMouseExit(hit)
  return rows
end

local function export_lines()
  local lines = {}
  for _, section in ipairs(Vermilion.ExportReport.SECTIONS) do
    local part = section()
    for line in (part or ""):gmatch("[^\n]+") do lines[#lines + 1] = line end
  end
  return lines
end

local function check_saved(sess)
  local sum = sess.head.sum
  if closed_ledger then
    check("saved_matches_recorded", sum.total_damage == closed_ledger.damage and sum.hits == closed_ledger.hits,
      string.format("saved %s in %s hits, recorded %s in %s", tostring(sum.total_damage), tostring(sum.hits), closed_ledger.damage, closed_ledger.hits))
    check("saved_shield_matches", sum.total_shield == closed_ledger.shield,
      string.format("saved %s, recorded %s", tostring(sum.total_shield), closed_ledger.shield))
    check("saved_fight_matches", sum.fight_ms == fight_of(closed_ledger),
      string.format("saved %s, recorded %s", tostring(sum.fight_ms), fight_of(closed_ledger)))
  end
  if sum.fight_t0 and sum.fight_ms and sum.fight_ms > 0 then
    check("fight_inside_recording", sum.fight_t0 + sum.fight_ms <= sess.head.dur_ms + 50,
      string.format("fight ends at %s, recording at %s", sum.fight_t0 + sum.fight_ms, tostring(sess.head.dur_ms)))
  end
end

local function sync_phase()
  local now = TB.is_recording()
  if was_recording and not now then
    closed_ledger = copy_ledger(ledger)
    chip_at_stop, count_at_stop = chip_text(), TB.count()
    looks = {}
    if ledger_valid then
      local first = ledger.first or math.huge
      for i = 1, TB.count() do
        local sample = TB.at(i)
        if sample.t < first then
          check("no_damage_before_the_fight", sample.eDPS + sample.ShDPS == 0,
            string.format("sample at %s reads %s, the first hit is at %s", tostring(sample.t), tostring(sample.eDPS + sample.ShDPS), tostring(first)))
        end
      end
    end
  end
  local count = SS.count()
  if count > sessions_seen then
    for i = sessions_seen + 1, count do
      local sess = SS.get(i)
      check_saved(sess)
      frozen[sess] = frozen_text(sess)
    end
    if not loaded then stored_fight = SS.get(count) end
  end
  sessions_seen = count
  if stored_fight then
    local present = false
    for i = 1, count do
      if SS.get(i) == stored_fight then present = true end
    end
    if not present then stored_fight = nil end
  end
  if now and not was_recording then
    new_profile()
    ledger, ledger_valid = new_ledger(), true
    loaded, stored_fight, chip_at_stop = false, nil, nil
    looks = {}
  end
  was_recording = now
end

local function check_state()
  if ledger_valid then
    local dmg, shd, _, hits = M.totals()
    check("totals_match_ledger", dmg == ledger.damage and hits == ledger.hits,
      string.format("addon %s in %s hits, ledger %s in %s", tostring(dmg), tostring(hits), ledger.damage, ledger.hits))
    if not TB.is_recording() then
      check("shields_match_ledger", shd == ledger.shield, string.format("addon %s, ledger %s", tostring(shd), ledger.shield))
    end
    if not loaded and Vermilion.Pipeline.pending_count() == 0 then
      check("fight_matches_ledger", M.fight_ms() == fight_of(ledger),
        string.format("addon %s, ledger %s", tostring(M.fight_ms()), fight_of(ledger)))
      local counted = 0
      for _, v in pairs(M.exact().skills) do counted = counted + v end
      if not TB.is_recording() then
        check("skills_add_up", counted == ledger.damage + ledger.shield,
          string.format("skills %s, ledger %s", counted, ledger.damage + ledger.shield))
      end
    end
  end
  if TB.is_recording() then
    check("no_median_while_recording", VermilionGraphMedianLine._hidden == true, "the median line is up while recording")
  elseif chip_at_stop and not loaded then
    check("stopped_stays_still", chip_text() == chip_at_stop and TB.count() == count_at_stop,
      string.format("chip %q was %q, samples %d were %d", chip_text(), chip_at_stop, TB.count(), count_at_stop))
  end
end

local function check_hover_card()
  local stat = VermilionHoverCardStat._text or ""
  if not stat:find("DPS over 5 s", 1, true) then return end
  if VermilionHoverCardName._text == GetString(VERMILION_REPORT_SHIELDED) then return end
  local header = tonumber(stat:match("(%d+)%%%s*$"))
  local sum, shown, more = 0, 0, false
  for i = 1, 19 do
    local name, val = rawget(_G, "VermilionHoverCardRowName" .. i), rawget(_G, "VermilionHoverCardRowVal" .. i)
    if name and name._hidden == false then
      if tostring(name._text):find("^%+%d+ more") then
        more = true
      else
        shown = shown + 1
        check("hover_rows_named", name._text ~= nil and name._text ~= "" and not tostring(name._text):find("nil"), "row " .. i .. " has no name")
        local pct = tonumber(tostring(val._text):match("(%d+)%%"))
        check("hover_rows_have_share", pct ~= nil, "row " .. i .. " reads " .. tostring(val._text))
        sum = sum + pct
        local shield = name._text == GetString(VERMILION_REPORT_SHIELDED)
        check("hover_value_colour", shield and val._r == 0.85 or (not shield and val._r == 1.00 and val._g == 0.42),
          string.format("row %d %s reads %s,%s,%s", i, tostring(name._text), tostring(val._r), tostring(val._g), tostring(val._b)))
      end
    end
  end
  if shown > 0 and not more and header then
    check("hover_rows_add_up", math.abs(sum - header) <= shown * 0.5 + 1,
      string.format("rows add to %d, the header says %d, %d rows", sum, header, shown))
  end
end

local function check_lines_agree()
  if TB.is_recording() or TB.count() < 2 or W.is_zoomed() then return end
  if not (S.average_line() or S.median_line()) then return end
  local view = VermilionGraphWindowViewLabel._text
  show_view("SKILL")
  local avg, med = VermilionGraphAvgLine, VermilionGraphMedianLine
  local a1 = not avg._hidden and avg._anchor_list[1].oy
  local m1 = not med._hidden and med._anchor_list[1].oy
  show_view("TYPE")
  if a1 then
    check("lines_agree_across_views", avg._hidden == false and avg._anchor_list[1].oy == a1,
      string.format("average %s in SKILL, %s in TYPE", tostring(a1), tostring(avg._anchor_list[1] and avg._anchor_list[1].oy)))
  end
  if m1 then
    check("lines_agree_across_views", med._hidden == false and med._anchor_list[1].oy == m1,
      string.format("median %s in SKILL, %s in TYPE", tostring(m1), tostring(med._anchor_list[1] and med._anchor_list[1].oy)))
  end
  show_view(view)
end

local function check_new_is_empty()
  for _, c in ipairs(H.controls) do
    local name = c._name
    if c._hidden == false and type(name) == "string"
       and (name:find("^VermilionEosSeg") or name:find("^VermilionEdpsFill") or name:find("^VermilionShdpsFill")) then
      fail("new_is_empty", "New leaves " .. name .. " on screen")
    end
  end
  check("new_is_empty", VermilionGraphAvgLine._hidden == true and VermilionGraphMedianLine._hidden == true, "New leaves a line on screen")
end

local function fire_hit()
  local a = ABILITIES[rng:range(1, #ABILITIES)]
  local amount = rng:range(100, 6000)
  local target = rng:range(900, 903)
  local recording = TB.is_recording()
  H.damage_out({
    hit = amount, ability_id = a[1], damage_type = a[2], target_unit_id = target,
    result = RESULTS[rng:range(1, #RESULTS)], overflow = rng:chance(0.05) and rng:range(1, 500) or 0,
  })
  if recording then
    local t = H.now()
    ledger.damage, ledger.hits = ledger.damage + amount, ledger.hits + 1
    ledger.first = ledger.first or t
    ledger.last = t
  end
end

local function hover_at(x_frac, y_frac)
  local canvas, hit = VermilionGraphWindowViewportCanvas, VermilionGraphHit
  H.state.mouse_x = canvas:GetLeft() + canvas:GetWidth() * x_frac
  H.state.mouse_y = canvas:GetTop() + canvas:GetHeight() * y_frac
  VermilionHoverCardStat._text = nil
  hit._onOnMouseEnter(hit)
  H.advance(120)
  check_hover_card()
  hit._onOnMouseExit(hit)
  H.state.mouse_x, H.state.mouse_y = 400, 300
end

local function check_uptime_icons()
  if VermilionGraphWindowViewLabel._text ~= "UPTIME" then return end
  local labels = {}
  for _, c in ipairs(H.controls) do
    if c._hidden == false and type(c._text) == "string" then labels[c._text] = true end
  end
  for _, c in ipairs(H.controls) do
    if c._hidden == false and type(c._tex) == "string" then
      local id = c._tex:match("^effect(%d+)%.dds$")
      if id then
        check("uptime_icon_matches_name", labels["Effect " .. id] == true,
          "the icon of effect " .. id .. " is on screen without its name, in " .. tostring(c._name))
      end
    end
  end
end

local function look_again()
  if TB.is_recording() or TB.count() < 1 then return false end
  H.advance(60)
  check_uptime_icons()
  local cols = Vermilion.FilmColumns.cols
  local key = table.concat({ VermilionGraphWindowViewLabel._text, settings_key(), cols.first, cols.last }, "#")
  local now = screen()
  local before = looks[key]
  if before then
    local diff = first_difference(before, now)
    check("nothing_moves_after_the_end", diff == nil, key .. " " .. tostring(diff))
  else
    looks[key] = now
  end
  local rows = report_rows()
  if looks.rows then
    local diff = first_difference(looks.rows, rows)
    check("report_stays_after_the_end", diff == nil, tostring(diff))
  else
    looks.rows = rows
  end
  local text = export_lines()
  if looks.text then
    local diff = first_difference(looks.text, text)
    check("export_stays_after_the_end", diff == nil, tostring(diff))
  else
    looks.text = text
  end
  return true
end

local function revisit(sess, index)
  if not G.load_session(sess) then fail("sessions_open", "session " .. index .. " would not open") end
  loaded = true
  looks = {}
  if chip_at_stop then chip_at_stop = nil end
  check("opening_changes_nothing", frozen[sess] == frozen_text(sess), "opening session " .. index .. " changed what is stored")
  local view = ALL_VIEWS[rng:range(1, #ALL_VIEWS)]
  show_view(view)
  H.advance(60)
  check_uptime_icons()
  local key = table.concat({ tostring(sess), view, settings_key() }, "#")
  local now = screen()
  local before = screens[key]
  if before then
    local diff = first_difference(before, now)
    check("same_session_same_screen", diff == nil, key .. " first seen at step " .. tostring(before.step) .. " after " .. tostring(before.after) .. "\n  " .. tostring(diff))
  else
    now.step = step
    now.after = table.concat(trail, " ", math.max(1, #trail - 8))
    screens[key] = now
  end
end

local function reopen_saved()
  local sess = stored_fight
  if not sess or loaded or TB.is_recording() or TB.count() < 2 then return false end
  W.reset()
  G.rerender()
  local chip = chip_text()
  local rows = report_rows()
  local before = {}
  for _, view in ipairs(BAR_VIEWS) do
    show_view(view)
    before[view] = screen()
  end
  local text = export_lines()
  if not G.load_session(sess) then fail("sessions_open", "the saved fight would not open") end
  loaded, chip_at_stop = true, nil
  looks = {}
  check("round_trip_chip", chip_text() == chip, string.format("before %q, after %q", chip, chip_text()))
  local after = report_rows()
  local diff = first_difference(rows, after)
  check("round_trip_report", diff == nil, tostring(diff) .. " BEFORE " .. table.concat(rows, " ; ") .. " AFTER " .. table.concat(after, " ; "))
  local text2 = export_lines()
  diff = first_difference(text, text2)
  check("round_trip_export", diff == nil, tostring(diff))
  for _, view in ipairs(BAR_VIEWS) do
    show_view(view)
    diff = near_difference(before[view], screen())
    check("round_trip_screen", diff == nil, view .. " " .. tostring(diff))
  end
  return true
end

local ACTIONS = {
  { "hit", function() return TB.is_recording() and 34 or 6 end, fire_hit },
  { "burst", function() return TB.is_recording() and 8 or 1 end, function()
    for _ = 1, rng:range(2, 10) do
      fire_hit()
      H.advance(rng:range(0, 120))
    end
  end },
  { "wait", function() return TB.is_recording() and 28 or 8 end, function() H.advance(rng:range(50, 2500)) end },
  { "shield", allowed("shields", 3), function()
    local amount = rng:range(100, 3000)
    local recording = TB.is_recording()
    H.shield_out({ hit = amount, target_unit_id = rng:range(900, 903), ability_id = 41 })
    if recording then
      ledger.shield = ledger.shield + amount
      local t = H.now()
      ledger.first = ledger.first or t
      ledger.last = t
    end
    H.advance(60)
  end },
  { "record", function() return TB.is_recording() and 0 or 14 end, function() G.on_record_click() end },
  { "stop", function() return TB.is_recording() and 4 or 0 end, function()
    G.on_stop_click()
  end },
  { "snap", function() return (TB.is_recording() and ledger.hits == 0) and 4 or 0 end, function()
    fire_hit()
    H.advance(rng:range(0, 200))
    G.on_stop_click()
  end },
  { "new", function() return 1 end, function()
    G.on_flush_click()
    sync_phase()
    ledger_valid, closed_ledger, loaded, stored_fight, chip_at_stop = false, nil, false, nil, nil
    looks = {}
    check_new_is_empty()
  end },
  { "save", function() return TB.is_recording() and 1 or 16 end, function()
    G.on_save_click()
    H.advance(400)
  end },
  { "autosave", function() return 1 end, function()
    local st = Vermilion.SavedVars.settings
    st.session_autosave = not st.session_autosave
  end },
  { "autostop", function() return 1 end, function()
    Vermilion.AutoRecord.set_auto_stop(not Vermilion.AutoRecord.get_auto_stop())
  end },
  { "combat", function() return 3 end, function() H.combat_state(rng:chance(0.5)) end },
  { "view", function() return 8 end, function() if rng:chance(0.5) then G.next_view() else G.prev_view() end end },
  { "wheel", function() return TB.is_recording() and 1 or 8 end, function()
    local canvas, hit = VermilionGraphWindowViewportCanvas, VermilionGraphHit
    H.state.mouse_x = canvas:GetLeft() + canvas:GetWidth() * rng:next()
    H.state.mouse_y = canvas:GetTop() + 40
    H.state.shift = rng:chance(0.25)
    hit._onOnMouseWheel(hit, rng:chance(0.7) and 1 or -1)
    H.state.shift = false
    H.state.mouse_x, H.state.mouse_y = 400, 300
  end },
  { "strip", function() return TB.is_recording() and 0 or 3 end, function()
    if rng:chance(0.3) then O.mouse_down(MOUSE_BUTTON_INDEX_RIGHT or 2) else O.wheel(rng:chance(0.5) and 1 or -1) end
  end },
  { "hover", function() return TB.is_recording() and 1 or 12 end, function() hover_at(rng:next(), rng:next()) end },
  { "chip", function() return TB.is_recording() and 0 or 3 end, function() report_rows() end },
  { "line", function() return 2 end, function()
    if rng:chance(0.5) then S.on_avg_click() else S.on_median_click() end
  end },
  { "zoomscale", function() return 1 end, function() S.on_zoom_scale_click() end },
  { "kills", function() return 1 end, function() S.on_kills_click() end },
  { "resize", function() return 2 end, function()
    VermilionGraphWindow:SetDimensions(rng:range(500, 1000), rng:range(240, 700))
    G.on_resize_stop()
  end },
  { "double", function() return 1 end, function()
    H.state.mouse_x, H.state.mouse_y = VermilionGraphWindow:GetLeft() + 20, VermilionGraphWindow:GetTop() + 10
    G.on_title_double_click()
    H.state.mouse_x, H.state.mouse_y = 400, 300
  end },
  { "open", function() return (not TB.is_recording() and SS.count() > 0) and 8 or 0 end, function()
    local i = rng:range(1, SS.count())
    revisit(SS.get(i), i)
  end },
  { "delete", function() return SS.count() > 3 and 0.2 or 0 end, function()
    SS.delete(rng:range(1, SS.count()))
    if not TB.is_recording() then G.rerender() end
  end },
  { "rename", function() return SS.count() > 0 and 0.3 or 0 end, function()
    local i = rng:range(1, SS.count())
    SS.set_label(i, "run " .. rng:range(1, 9))
    frozen[SS.get(i)] = frozen_text(SS.get(i))
    looks = {}
    if SS.get(i) == stored_fight then stored_fight = nil end
  end },
  { "lock", function() return SS.count() > 0 and 0.3 or 0 end, function()
    local i = rng:range(1, SS.count())
    SS.set_locked(i, rng:chance(0.5))
    frozen[SS.get(i)] = frozen_text(SS.get(i))
  end },
  { "step", function() return (not TB.is_recording() and SS.count() > 0) and 3 or 0 end, function()
    if G.step_session(rng:chance(0.5) and 1 or -1) then
      loaded, chip_at_stop = true, nil
      looks = {}
    end
  end },
  { "reopen", function() return (stored_fight and not loaded) and 10 or 0 end, reopen_saved },
  { "look", function() return TB.is_recording() and 0 or 14 end, look_again },
  { "agree", function() return TB.is_recording() and 0 or 4 end, check_lines_agree },
  { "export", function() return 1 end, function()
    if G.export_available() then export_lines() end
  end },
  { "effect", allowed("effects", 5), function()
    local id = EFFECTS[rng:range(1, #EFFECTS)]
    H.fire(EVENT_EFFECT_CHANGED, EFFECT_RESULT_GAINED, 1, H.ability_names[id], "boss1", 0, (H.now() + rng:range(2000, 12000)) / 1000,
      1, H.ability_icons[id], 0, BUFF_EFFECT_TYPE_DEBUFF, 0, 0, "Enemy", rng:range(900, 903), id, COMBAT_UNIT_TYPE_PLAYER)
  end },
  { "power", allowed("power", 3), function()
    H.res_power(rng:chance(0.5) and COMBAT_MECHANIC_FLAGS_MAGICKA or COMBAT_MECHANIC_FLAGS_STAMINA, rng:range(0, 30000), 30000)
  end },
  { "ultimate", allowed("ult", 3), function()
    H.ult_power(rng:range(0, 500))
    if rng:chance(0.3) then H.ult_used() end
  end },
  { "cast", function() return 2 end, function() H.skill_used(rng:range(3, 8)) end },
  { "restore", function() return 1 end, function()
    H.energize({ amount = rng:range(100, 2000), pool = rng:chance(0.5) and COMBAT_MECHANIC_FLAGS_MAGICKA or COMBAT_MECHANIC_FLAGS_STAMINA, ability_id = 701 })
  end },
  { "death", function() return 1 end, function()
    H.death(not H.state.player_dead)
  end },
  { "kill", function() return 1 end, function() H.kill({ target_unit_id = rng:range(900, 903) }) end },
}

local function pick_action()
  local total = 0
  for _, a in ipairs(ACTIONS) do total = total + a[2]() end
  local at = rng:next() * total
  for _, a in ipairs(ACTIONS) do
    at = at - a[2]()
    if at < 0 then return a end
  end
  return ACTIONS[1]
end

Vermilion.Visibility.set("graph", true)
O.sync(true)
O.sync(false)
sync_phase()
for i = 1, steps do
  step = i
  local a = pick_action()
  trail[#trail + 1] = a[1]
  local ok, err = pcall(a[3])
  if not ok then fail("no_lua_errors", err) end
  local ok2, err2 = pcall(function()
    sync_phase()
    check_state()
  end)
  if not ok2 then fail("no_lua_errors", err2) end
end

local names = {}
for k in pairs(counts) do names[#names + 1] = k end
table.sort(names)
local parts = {}
for _, k in ipairs(names) do parts[#parts + 1] = k .. "=" .. counts[k] end
print(string.format("MONKEY ok seed=%d steps=%d sessions=%d", seed, steps, SS.count()))
print("RULES " .. table.concat(parts, " "))
os.exit(0)
