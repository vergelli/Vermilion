Vermilion = Vermilion or {}
Vermilion.TargetsView = {}
local M = Vermilion.TargetsView

local math_floor    = math.floor
local math_max      = math.max
local math_sqrt     = math.sqrt
local string_format = string.format
local table_sort    = table.sort

local MAX_ROW_H = 30
local MIN_ROW   = 10
local ROW_GAP   = 3
local GUTTER_W  = 168
local VAL_W     = 48
local C_NAME    = { r = 0.94, g = 0.88, b = 0.86, a = 1.0 }
local C_VAL     = { r = 0.87, g = 0.85, b = 0.83, a = 1.0 }
local C_MORE    = { r = 0.70, g = 0.64, b = 0.62, a = 0.90 }
local C_LANE    = { r = 1.00, g = 0.62, b = 0.58, a = 0.05 }
local C_ORCHID  = { r = 0.85, g = 0.40, b = 0.75 }
local C_HEAT    = { r = 0.98, g = 0.55, b = 0.20 }
local DIM       = 0.30
local LUT_N     = 128
local RAMP = {
  { 0.05, 0.03, 0.53 },
  { 0.49, 0.01, 0.66 },
  { 0.80, 0.23, 0.48 },
  { 0.97, 0.53, 0.19 },
  { 0.94, 0.98, 0.13 },
}
local FADE_IN = 0.22

local LUT = {}
for i = 0, LUT_N - 1 do
  local t = i / (LUT_N - 1) * (#RAMP - 1)
  local k = math_floor(t)
  if k >= #RAMP - 1 then k = #RAMP - 2 end
  local f = t - k
  local a, b = RAMP[k + 1], RAMP[k + 2]
  LUT[i] = { a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f }
end

local PCT_TEXT = {}
for i = 0, 100 do PCT_TEXT[i] = i .. "%" end

local ctx = nil
local by_id = {}
local order = { n = 0 }
local hit = { n = 0, y0 = {}, y1 = {}, lane = {}, lane_x = 0, lane_w = 0, t0 = 0, span = 0 }
local totals = { damage = 0, cell_max = 0, t0 = 0, t_hi = 0 }
local hover_id = nil
local scroll = 0
local max_scroll = 0
local gen = 0
local ROWS = { {}, {}, {}, {}, {}, {}, {}, {}, {} }
local str = nil

local function strings()
  if str then return str end
  str = {
    damage   = GetString(VERMILION_TARGETH_DAMAGE),
    absorbed = GetString(VERMILION_TARGETH_ABSORBED),
    share    = GetString(VERMILION_TARGETH_SHARE),
    scrolled = GetString(VERMILION_TARGETS_SCROLLED),
    shield   = GetString(VERMILION_REPORT_SHIELDED),
  }
  return str
end

local function by_total_desc(a, b) return a.total > b.total end

local function entry_in(list, id)
  for k = 1, (list and list.count or 0) do
    local e = list[k]
    if e.id == id then return e end
  end
  return nil
end

local function aggregate()
  local TB = Vermilion.TemporalBuffer
  local n = TB.count()
  gen = gen + 1
  order.n = 0
  totals.damage = 0
  totals.cell_max = 0
  local prev_t = nil
  for i = 1, n do
    local s = TB.at(i)
    local eos = (s.eDPS or 0) + (s.ShDPS or 0)
    local dt = prev_t and (s.t - prev_t) / 1000 or 0
    local list = s.targets
    for k = 1, (list and list.count or 0) do
      local e = list[k]
      local id = e.id or 0
      local rec = by_id[id]
      if not rec then rec = { id = id, name = "", raw = nil, ttype = 0, total = 0, abs = 0, gen = -1, disp = -1, text = "" }; by_id[id] = rec end
      if rec.gen ~= gen then
        rec.gen = gen
        rec.total = 0
        rec.abs = 0
        order.n = order.n + 1
        order[order.n] = rec
      end
      if e.name and e.name ~= rec.raw then
        rec.raw = e.name
        rec.name = (e.name:gsub("%^%a+$", ""))
      end
      rec.ttype = e.ttype or rec.ttype
      local v = (e.share or 0) * eos
      if v > totals.cell_max then totals.cell_max = v end
      if dt > 0 then
        rec.total = rec.total + v * dt
        rec.abs = rec.abs + (e.abs or 0) * eos * dt
        totals.damage = totals.damage + v * dt
      end
    end
    if i == 1 then totals.t0 = s.t end
    totals.t_hi = s.t
    prev_t = s.t
  end
  for k = order.n + 1, #order do order[k] = nil end
  if order.n > 1 then table_sort(order, by_total_desc) end
end

local function cell(c, canvas, x0, x1, y, row_h, level, dim)
  local seg = c.seg:AcquireObject()
  seg:ClearAnchors()
  seg:SetAnchor(TOPLEFT, canvas, TOPLEFT, x0, y)
  seg:SetWidth(math_max(1, x1 - x0))
  seg:SetHeight(row_h)
  seg:SetDrawLevel(4)
  local col = LUT[level]
  local a = level / ((LUT_N - 1) * FADE_IN)
  if a > 1 then a = 1 end
  a = 0.30 + 0.70 * a
  if dim then
    seg:SetColor(col[1] * DIM, col[2] * DIM, col[3] * DIM, 0.35 * a)
  else
    seg:SetColor(col[1], col[2], col[3], a)
  end
  seg:SetHidden(false)
end

local function pressure_at(TB, k, id)
  local s = TB.at(k)
  if not s then return 0 end
  local e = entry_in(s.targets, id)
  if not e then return 0 end
  return (e.share or 0) * ((s.eDPS or 0) + (s.ShDPS or 0))
end

function M.attach(t) ctx = t end

function M.render()
  local c = ctx
  if not c then return end
  c.seg:ReleaseAllObjects()
  c.rim:ReleaseAllObjects()
  c.lbl:ReleaseAllObjects()
  c.hit_reset()
  hit.n = 0
  aggregate()
  local n = order.n
  if n == 0 then
    c.no_data:SetHidden(false)
    c.hide_grid(c.grid)
    return
  end
  c.no_data:SetHidden(true)

  local canvas = c.canvas
  local cw, ch = canvas:GetWidth(), canvas:GetHeight()
  if cw <= GUTTER_W + 40 or ch <= 4 then return end
  local TB = Vermilion.TemporalBuffer
  local recording = TB.is_recording()
  local t0   = totals.t0
  local t_hi = recording and c.now() or totals.t_hi
  local span = t_hi - t0
  if span <= 0 then span = 1 end
  Vermilion.Diagnostics.bump("graph.view_targets.renders")
  c.draw_grid(c.grid, canvas, 0, span)

  local top = (c.layout.H or 0) + (c.ult_inset and c.ult_inset() or 0)
  local ch_plot = math_max(4, ch - c.time_strip - top)
  local rows  = n
  local extra = 0
  local row_h = math_floor(ch_plot / rows) - ROW_GAP
  if row_h < MIN_ROW then
    rows = math_max(1, math_floor(ch_plot / (MIN_ROW + ROW_GAP)) - 1)
    if rows > n then rows = n end
    extra = (n > rows) and 1 or 0
    row_h = math_floor(ch_plot / (rows + extra)) - ROW_GAP
    if row_h < 6 then return end
  elseif row_h > MAX_ROW_H then
    row_h = MAX_ROW_H
  end
  max_scroll = (n > rows) and (n - rows) or 0
  if scroll > max_scroll then scroll = max_scroll end
  if scroll < 0 then scroll = 0 end
  local off = scroll

  local lane_x = GUTTER_W
  local lane_w = cw - GUTTER_W
  local capture = not recording
  hit.n = capture and rows or 0
  hit.lane_x, hit.lane_w, hit.t0, hit.span = lane_x, lane_w, t0, span
  local hk = hover_id
  local ns = TB.count()
  local cell_max = totals.cell_max

  for i = 1, rows do
    local rec = order[i + off]
    local y = top + (i - 1) * (row_h + ROW_GAP)
    local dim = (hk ~= nil and rec.id ~= hk)
    if capture then
      hit.y0[i] = y
      hit.y1[i] = y + row_h
      hit.lane[i] = rec
    end

    local lane = c.seg:AcquireObject()
    lane:ClearAnchors()
    lane:SetAnchor(TOPLEFT, canvas, TOPLEFT, lane_x, y)
    lane:SetWidth(lane_w)
    lane:SetHeight(row_h)
    lane:SetColor(C_LANE.r, C_LANE.g, C_LANE.b, C_LANE.a)
    lane:SetHidden(false)

    local lbl = c.lbl:AcquireObject()
    lbl:ClearAnchors()
    lbl:SetText(rec.name ~= "" and rec.name or tostring(rec.id))
    lbl:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    lbl:SetMaxLineCount(1)
    lbl:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    if dim then
      lbl:SetColor(C_NAME.r * 0.45, C_NAME.g * 0.45, C_NAME.b * 0.45, 0.6)
    else
      lbl:SetColor(C_NAME.r, C_NAME.g, C_NAME.b, C_NAME.a)
    end
    local name_w = GUTTER_W - VAL_W - 14
    local bar_room = row_h >= 18 and order[1].total > 0
    lbl:SetDimensions(name_w, bar_room and (row_h - 6) or row_h)
    lbl:SetAnchor(TOPLEFT, canvas, TOPLEFT, 6, y)
    lbl:SetHidden(false)

    if bar_room then
      local by = y + row_h - 5
      local track = c.seg:AcquireObject()
      track:ClearAnchors()
      track:SetAnchor(TOPLEFT, canvas, TOPLEFT, 6, by)
      track:SetWidth(name_w)
      track:SetHeight(3)
      track:SetDrawLevel(3)
      track:SetColor(1, 1, 1, dim and 0.03 or 0.07)
      track:SetHidden(false)
      local bw = math_max(1, math_floor(name_w * rec.total / order[1].total + 0.5))
      local fill = c.seg:AcquireObject()
      fill:ClearAnchors()
      fill:SetAnchor(TOPLEFT, canvas, TOPLEFT, 6, by)
      fill:SetWidth(bw)
      fill:SetHeight(3)
      fill:SetDrawLevel(4)
      fill:SetColor(C_HEAT.r, C_HEAT.g, C_HEAT.b, dim and 0.25 or 0.85)
      fill:SetHidden(false)
      if rec.abs > 0 and rec.total > 0 then
        local aw = math_floor(bw * rec.abs / rec.total + 0.5)
        if aw >= 1 and aw < bw then
          local tail = c.seg:AcquireObject()
          tail:ClearAnchors()
          tail:SetAnchor(TOPLEFT, canvas, TOPLEFT, 6 + bw - aw, by)
          tail:SetWidth(aw)
          tail:SetHeight(3)
          tail:SetDrawLevel(5)
          tail:SetColor(C_ORCHID.r, C_ORCHID.g, C_ORCHID.b, dim and 0.25 or 0.92)
          tail:SetHidden(false)
        end
      end
    end

    local disp = math_floor(rec.total)
    if rec.disp ~= disp then
      rec.disp = disp
      rec.text = c.fmt_val(rec.total)
    end
    local val = c.lbl:AcquireObject()
    val:ClearAnchors()
    val:SetText(rec.text)
    val:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    val:SetMaxLineCount(1)
    if dim then
      val:SetColor(C_VAL.r * 0.45, C_VAL.g * 0.45, C_VAL.b * 0.45, 0.6)
    else
      val:SetColor(C_VAL.r, C_VAL.g, C_VAL.b, C_VAL.a)
    end
    val:SetDimensions(VAL_W, row_h)
    val:SetAnchor(TOPLEFT, canvas, TOPLEFT, GUTTER_W - VAL_W - 6, y)
    val:SetHidden(false)

    local run_x0, run_x1, run_lv = nil, nil, -1
    local v_prev, v_here, v_next = 0, pressure_at(TB, 1, rec.id), pressure_at(TB, 2, rec.id)
    for k = 1, ns do
      local s = TB.at(k)
      local level = 0
      if cell_max > 0 and (v_here > 0 or v_prev > 0 or v_next > 0) then
        local v = 0.25 * v_prev + 0.5 * v_here + 0.25 * v_next
        if v_here <= 0 then v = v * 0.5 end
        level = math_floor(math_sqrt(v / cell_max) * (LUT_N - 1) + 0.5)
        if level < 1 then level = 1 end
        if level > LUT_N - 1 then level = LUT_N - 1 end
      end
      local x0 = lane_x + math_floor((s.t - t0) / span * lane_w + 0.5)
      local nxt = TB.at(k + 1)
      local x1 = nxt and (lane_x + math_floor((nxt.t - t0) / span * lane_w + 0.5)) or (lane_x + lane_w)
      if x1 <= x0 then x1 = x0 + 1 end
      if level > 0 and run_x0 and level == run_lv and x0 <= run_x1 then
        run_x1 = x1
      else
        if run_x0 then cell(c, canvas, run_x0, run_x1, y, row_h, run_lv, dim) end
        if level > 0 then run_x0, run_x1, run_lv = x0, x1, level
        else run_x0 = nil end
      end
      v_prev, v_here, v_next = v_here, v_next, pressure_at(TB, k + 2, rec.id)
    end
    if run_x0 then cell(c, canvas, run_x0, run_x1, y, row_h, run_lv, dim) end
  end

  if c.ult_band then c.ult_band(t0, span, lane_x, lane_w, totals.t_hi) end

  if n > rows then
    local more = c.lbl:AcquireObject()
    more:ClearAnchors()
    more:SetText(string_format(strings().scrolled, off, n - rows - off))
    more:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    more:SetColor(C_MORE.r, C_MORE.g, C_MORE.b, C_MORE.a)
    more:SetDimensions(cw, row_h)
    more:SetAnchor(TOPLEFT, canvas, TOPLEFT, 6, top + rows * (row_h + ROW_GAP))
    more:SetHidden(false)
  end
end

local function sample_at(t_abs)
  local TB = Vermilion.TemporalBuffer
  local n = TB.count()
  local best = nil
  for i = 1, n do
    local s = TB.at(i)
    if s.t <= t_abs then best = s else break end
  end
  return best or TB.at(1)
end

function M.hover(mx, my)
  local c = ctx
  if not c then return end
  local canvas = c.canvas
  local rel_x = mx - canvas:GetLeft()
  local rel_y = my - canvas:GetTop()
  local cw, ch = canvas:GetWidth(), canvas:GetHeight()
  local inside = rel_x >= 0 and rel_x <= cw and rel_y >= 0 and rel_y <= ch
  local rec = nil
  if inside then
    for i = 1, hit.n do
      if rel_y >= hit.y0[i] and rel_y <= hit.y1[i] then rec = hit.lane[i] break end
    end
  end
  local new = rec and rec.id or nil
  if new ~= hover_id then hover_id = new; c.rerender() end
  if not rec or hit.span <= 0 then
    c.hide_card()
    return
  end
  local frac = (rel_x - hit.lane_x) / hit.lane_w
  if frac < 0 then frac = 0 end
  if frac > 1 then frac = 1 end
  local t_abs = hit.t0 + frac * hit.span
  local s = sample_at(t_abs)
  local e = s and entry_in(s.targets, rec.id) or nil
  local eos = s and ((s.eDPS or 0) + (s.ShDPS or 0)) or 0
  local v = e and (e.share or 0) * eos or 0
  local av = e and (e.abs or 0) * eos or 0
  local S = strings()
  local stat
  if av > 0 then
    stat = string_format("%s DPS  ·  |c%02x%02x%02x%s %s|r", c.fmt_val(v),
      math_floor(C_ORCHID.r * 255 + 0.5), math_floor(C_ORCHID.g * 255 + 0.5), math_floor(C_ORCHID.b * 255 + 0.5),
      c.fmt_val(av), S.absorbed)
  else
    stat = string_format("%s DPS", c.fmt_val(v))
  end
  local n_rows = 0
  n_rows = n_rows + 1
  ROWS[n_rows][1], ROWS[n_rows][2] = S.damage, c.fmt_val(rec.total)
  if rec.abs > 0 then
    n_rows = n_rows + 1
    ROWS[n_rows][1] = S.absorbed
    ROWS[n_rows][2] = string_format("%s  ·  %s", c.fmt_val(rec.abs), PCT_TEXT[math_floor(rec.abs / math_max(rec.total, 1) * 100 + 0.5)] or "")
  end
  n_rows = n_rows + 1
  ROWS[n_rows][1] = S.share
  ROWS[n_rows][2] = PCT_TEXT[math_floor(rec.total / math_max(totals.damage, 1) * 100 + 0.5)] or ""
  if av > 0 and s and s.shield_abilities and (s.shield_abilities.count or 0) > 0 then
    local SC = Vermilion.SkillColors
    local sa = s.shield_abilities
    for k = 1, sa.count do
      if n_rows >= #ROWS then break end
      n_rows = n_rows + 1
      ROWS[n_rows][1] = S.shield
      ROWS[n_rows][2] = SC.ability_name(sa[k].id)
    end
  end
  c.crosshair(math_floor(rel_x))
  local col = (av > 0) and C_ORCHID or C_HEAT
  c.show_card(col, rec.name ~= "" and rec.name or tostring(rec.id), stat,
    "t  " .. c.fmt_secs(t_abs - hit.t0), ROWS, n_rows, nil, mx, my)
end

function M.scroll(dir)
  local next_off = scroll + ((dir or 1) < 0 and -1 or 1)
  if next_off < 0 then next_off = 0 end
  if next_off > max_scroll then next_off = max_scroll end
  if next_off == scroll then return false end
  scroll = next_off
  return true
end

function M.reset_scroll() scroll = 0 end
function M.scroll_state() return scroll, max_scroll end
function M.hovered() return hover_id end
function M.clear_hover() hover_id = nil end
function M.rows() return order, order.n end
function M.totals() return totals end
function M.lut(i) return LUT[i] end
