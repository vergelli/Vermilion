Vermilion = Vermilion or {}
Vermilion.ResourcesView = {}
local M = Vermilion.ResourcesView

local math_floor    = math.floor
local math_max      = math.max
local string_format = string.format
local table_sort    = table.sort

local PICK_MAG, PICK_STA, PICK_BOTH = 1, 2, 3
local MAG, STA  = 1, 2
local PICK_H    = 20
local RIGHT_W   = 160
local NAME_W    = 72
local VAL_W     = 40
local ROW_H     = 16
local ROW_GAP   = 2
local LANE_X    = 6
local GAP_X     = 12
local LOW       = 0.30
local STARVE    = 0.15
local STARVE_MS = 2000
local TICK_H    = 3
local WINDOW_MS = 10000
local C_DIM     = { r = 0.62, g = 0.58, b = 0.56 }
local C_TEXT    = { r = 0.94, g = 0.88, b = 0.86 }
local C_OUT     = { r = 0.86, g = 0.50, b = 0.44 }
local C_MID     = { r = 1.00, g = 1.00, b = 1.00 }

local PCT_TEXT = {}
for i = 0, 100 do PCT_TEXT[i] = i .. "%" end

local ctx = nil
local pick = PICK_BOTH
local scroll, max_scroll = 0, 0
local hover_row = nil
local by_id = {}
local order = { n = 0 }
local gen = 0
local totals = { spend = 0, casts = 0 }
local lane = { x = 0, w = 0, y = 0, h = 0, t0 = 0, span = 0, mid = 0 }
local pick_hit = { { x0 = 0, x1 = 0 }, { x0 = 0, x1 = 0 }, { x0 = 0, x1 = 0 }, y0 = 0, y1 = 0 }
local row_hit = { n = 0, y0 = {}, y1 = {}, rec = {} }
local ROWS = { {}, {}, {}, {} }
local str = nil

local function strings()
  if str then return str end
  str = {
    pick    = { GetString(VERMILION_RES_PICK_MAG), GetString(VERMILION_RES_PICK_STA), GetString(VERMILION_RES_PICK_BOTH) },
    pools   = { GetString(VERMILION_RES_MAGICKA), GetString(VERMILION_RES_STAMINA) },
    spent   = GetString(VERMILION_RESH_SPENT),
    casts   = GetString(VERMILION_RESH_CASTS),
    total   = GetString(VERMILION_RESH_TOTAL),
    share   = GetString(VERMILION_RESH_SHARE),
    pool    = GetString(VERMILION_RESH_POOL),
    top     = GetString(VERMILION_RESH_TOP),
    starved = GetString(VERMILION_RESH_STARVED),
    more    = GetString(VERMILION_RESH_MORE),
    flows   = GetString(VERMILION_RES_CARD_FLOWS),
    sigma   = GetString(VERMILION_RES_CARD_SIGMA),
  }
  return str
end

local function sv_graph()
  local sv = Vermilion.SavedVars
  if not sv then return nil end
  sv.graph = sv.graph or {}
  return sv.graph
end

function M.pick() return pick end

function M.set_pick(p)
  if p ~= PICK_MAG and p ~= PICK_STA and p ~= PICK_BOTH then p = PICK_BOTH end
  pick = p
  local g = sv_graph()
  if g then g.res_pick = p end
end

local function pool_col(c, p) return (p == MAG) and c.mag or c.sta end
local function wants(p) return pick == PICK_BOTH or (pick == PICK_MAG and p == MAG) or (pick == PICK_STA and p == STA) end
local function by_total_desc(a, b) return a.total > b.total end

local function aggregate()
  local ct, cid, cpool, ccost, n = Vermilion.Casts.records()
  gen = gen + 1
  order.n = 0
  totals.spend, totals.casts = 0, 0
  for i = 1, n do
    local p = cpool[i]
    local cost = ccost[i]
    if p > 0 and cost > 0 and wants(p) then
      local id = cid[i]
      local rec = by_id[id]
      if not rec then
        rec = { id = id, name = nil, casts = 0, mag = 0, sta = 0, total = 0, gen = -1, disp = -1, text = "" }
        by_id[id] = rec
      end
      if rec.gen ~= gen then
        rec.gen = gen
        rec.casts, rec.mag, rec.sta, rec.total = 0, 0, 0, 0
        order.n = order.n + 1
        order[order.n] = rec
      end
      rec.casts = rec.casts + 1
      if p == MAG then rec.mag = rec.mag + cost else rec.sta = rec.sta + cost end
      rec.total = rec.total + cost
      totals.spend = totals.spend + cost
      totals.casts = totals.casts + 1
    end
  end
  for k = order.n + 1, #order do order[k] = nil end
  if order.n > 1 then table_sort(order, by_total_desc) end
end

local function box(c, canvas, x0, x1, y, h, col, a, lvl)
  local seg = c.seg:AcquireObject()
  seg:ClearAnchors()
  seg:SetAnchor(TOPLEFT, canvas, TOPLEFT, x0, y)
  seg:SetWidth(math_max(1, x1 - x0))
  seg:SetHeight(math_max(1, h))
  seg:SetDrawLevel(lvl)
  seg:SetColor(col.r, col.g, col.b, a)
  seg:SetHidden(false)
end

local function x_of(t) return lane.x + math_floor((t - lane.t0) / lane.span * lane.w + 0.5) end

local function x_next(TB, k)
  local nx = TB.at(k + 1)
  if nx then return x_of(nx.t) end
  return lane.x + lane.w
end

local function level_of(s, p) return (p == MAG) and (s.mag or 0) or (s.sta or 0) end
local function in_of(s, p)    return (p == MAG) and (s.mag_in or 0) or (s.sta_in or 0) end
local function out_of(s, p)   return (p == MAG) and (s.mag_out or 0) or (s.sta_out or 0) end

local function draw_levels(c, canvas, TB, n, p, y_base, H, up, alpha, low_alpha, lvl)
  local col = pool_col(c, p)
  local run_x0, run_x1, run_h, run_low = nil, nil, -1, false
  for k = 1, n do
    local s = TB.at(k)
    local level = level_of(s, p)
    local h = math_floor(level * H + 0.5)
    local low = level > 0 and level < LOW
    local x0, x1 = x_of(s.t), x_next(TB, k)
    if x1 <= x0 then x1 = x0 + 1 end
    if h > 0 and run_x0 and h == run_h and low == run_low and x0 <= run_x1 then
      run_x1 = x1
    else
      if run_x0 then
        box(c, canvas, run_x0, run_x1, up and (y_base - run_h) or y_base, run_h, run_low and c.low or col, run_low and low_alpha or alpha, lvl)
      end
      if h > 0 then run_x0, run_x1, run_h, run_low = x0, x1, h, low else run_x0 = nil end
    end
  end
  if run_x0 then
    box(c, canvas, run_x0, run_x1, up and (y_base - run_h) or y_base, run_h, run_low and c.low or col, run_low and low_alpha or alpha, lvl)
  end
end

local function draw_starved(c, canvas, TB, n, p, y)
  local sx0, st0 = nil, 0
  for k = 1, n + 1 do
    local s = TB.at(k)
    local level = s and level_of(s, p) or 1
    if s and level > 0 and level < STARVE then
      if not sx0 then sx0, st0 = x_of(s.t), s.t end
    elseif sx0 then
      local t_end = s and s.t or (lane.t0 + lane.span)
      if t_end - st0 >= STARVE_MS then box(c, canvas, sx0, x_of(t_end), y, TICK_H, c.low, 1, 5) end
      sx0 = nil
    end
  end
end

local function draw_mirrored(c, canvas, TB, n)
  local half = math_floor(lane.h / 2) - TICK_H - 2
  if half < 4 then return end
  draw_levels(c, canvas, TB, n, MAG, lane.mid - 1, half, true,  0.85, 0.85, 3)
  draw_levels(c, canvas, TB, n, STA, lane.mid + 1, half, false, 0.85, 0.85, 3)
  box(c, canvas, lane.x, lane.x + lane.w, lane.mid, 1, C_MID, 0.18, 4)
  draw_starved(c, canvas, TB, n, MAG, lane.y)
  draw_starved(c, canvas, TB, n, STA, lane.y + lane.h - TICK_H)
end

local function draw_single(c, canvas, TB, n, p)
  local col = pool_col(c, p)
  local H = lane.h - TICK_H - 2
  if H < 8 then return end
  draw_levels(c, canvas, TB, n, p, lane.y + lane.h, H, true, 0.16, 0.22, 1)
  local max_f = 0
  for k = 1, n do
    local s = TB.at(k)
    local a, b = in_of(s, p), out_of(s, p)
    if a > max_f then max_f = a end
    if b > max_f then max_f = b end
  end
  if max_f > 0 then
    local half = math_floor(H / 2) - 2
    for k = 1, n do
      local s = TB.at(k)
      local x0, x1 = x_of(s.t), x_next(TB, k)
      if x1 <= x0 then x1 = x0 + 1 end
      if x1 - x0 > 2 then x1 = x1 - 1 end
      local hi = math_floor(in_of(s, p) / max_f * half + 0.5)
      local ho = math_floor(out_of(s, p) / max_f * half + 0.5)
      if hi > 0 then box(c, canvas, x0, x1, lane.mid - hi, hi, col, 0.9, 3) end
      if ho > 0 then box(c, canvas, x0, x1, lane.mid + 1, ho, C_OUT, 0.9, 3) end
    end
  end
  box(c, canvas, lane.x, lane.x + lane.w, lane.mid, 1, C_MID, 0.18, 4)
  draw_starved(c, canvas, TB, n, p, lane.y)
end

local function label(c, canvas, text, x, y, w, h, align, col, a)
  local lbl = c.lbl:AcquireObject()
  lbl:ClearAnchors()
  lbl:SetText(text)
  lbl:SetHorizontalAlignment(align)
  lbl:SetMaxLineCount(1)
  lbl:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
  lbl:SetColor(col.r, col.g, col.b, a)
  lbl:SetDimensions(w, h)
  lbl:SetAnchor(TOPLEFT, canvas, TOPLEFT, x, y)
  lbl:SetHidden(false)
  return lbl
end

local function draw_picker(c, canvas, top, S)
  local x = LANE_X
  pick_hit.y0, pick_hit.y1 = top, top + PICK_H
  for i = 1, 3 do
    local on = (pick == i)
    local col = (i == PICK_MAG) and c.mag or (i == PICK_STA) and c.sta or C_TEXT
    local lbl = c.lbl:AcquireObject()
    local w = lbl:GetStringWidth(S.pick[i]) + 12
    lbl:ClearAnchors()
    lbl:SetText(S.pick[i])
    lbl:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    lbl:SetMaxLineCount(1)
    lbl:SetDimensions(w, PICK_H)
    lbl:SetAnchor(TOPLEFT, canvas, TOPLEFT, x, top)
    if on then lbl:SetColor(col.r, col.g, col.b, 1) else lbl:SetColor(C_DIM.r, C_DIM.g, C_DIM.b, 0.8) end
    lbl:SetHidden(false)
    if on then box(c, canvas, x + 4, x + w - 4, top + PICK_H - 2, 1, col, 0.9, 4) end
    pick_hit[i].x0, pick_hit[i].x1 = x, x + w
    x = x + w + 6
  end
end

local function draw_time(c, canvas)
  local y = lane.y + lane.h + 1
  local h = c.time_strip - 2
  label(c, canvas, "0s", lane.x, y, 40, h, TEXT_ALIGN_LEFT, C_DIM, 0.9)
  label(c, canvas, c.fmt_secs(lane.span / 2), lane.x + math_floor(lane.w / 2) - 25, y, 50, h, TEXT_ALIGN_CENTER, C_DIM, 0.9)
  label(c, canvas, c.fmt_secs(lane.span), lane.x + lane.w - 50, y, 50, h, TEXT_ALIGN_RIGHT, C_DIM, 0.9)
end

local function draw_histogram(c, canvas, cw, y, h, S)
  local x = cw - RIGHT_W
  label(c, canvas, S.spent, x, y, RIGHT_W, ROW_H, TEXT_ALIGN_LEFT, C_DIM, 0.9)
  local n = order.n
  local y_rows = y + ROW_H + 4
  local rows = math_floor((h - ROW_H - 4) / (ROW_H + ROW_GAP))
  if rows > n then rows = n end
  if rows < 0 then rows = 0 end
  max_scroll = (n > rows) and (n - rows) or 0
  if scroll > max_scroll then scroll = max_scroll end
  if scroll < 0 then scroll = 0 end
  local top_total = (n > 0) and order[1].total or 0
  local bar_x = x + NAME_W + 4
  local bar_w = RIGHT_W - NAME_W - VAL_W - 8
  row_hit.n = rows
  for i = 1, rows do
    local rec = order[i + scroll]
    local ry = y_rows + (i - 1) * (ROW_H + ROW_GAP)
    row_hit.y0[i], row_hit.y1[i], row_hit.rec[i] = ry, ry + ROW_H, rec
    local dim = (hover_row ~= nil and rec ~= hover_row)
    if not rec.name then rec.name = Vermilion.SkillColors.ability_name(rec.id) end
    local a = dim and 0.45 or 1
    label(c, canvas, rec.name, x, ry, NAME_W, ROW_H, TEXT_ALIGN_LEFT, C_TEXT, a)
    if top_total > 0 then
      local bh = 8
      local by = ry + math_floor((ROW_H - bh) / 2)
      box(c, canvas, bar_x, bar_x + bar_w, by, bh, C_MID, dim and 0.03 or 0.06, 2)
      local wm = math_floor(bar_w * rec.mag / top_total + 0.5)
      local ws = math_floor(bar_w * rec.sta / top_total + 0.5)
      if wm > 0 then box(c, canvas, bar_x, bar_x + wm, by, bh, c.mag, dim and 0.25 or 0.9, 3) end
      if ws > 0 then box(c, canvas, bar_x + wm, bar_x + wm + ws, by, bh, c.sta, dim and 0.25 or 0.9, 3) end
    end
    if rec.disp ~= rec.total then
      rec.disp = rec.total
      rec.text = c.fmt_val(rec.total)
    end
    label(c, canvas, rec.text, x + RIGHT_W - VAL_W, ry, VAL_W, ROW_H, TEXT_ALIGN_RIGHT, C_TEXT, a)
  end
  if n > rows then
    label(c, canvas, string_format(S.more, n - rows - scroll), x, y_rows + rows * (ROW_H + ROW_GAP), RIGHT_W, ROW_H, TEXT_ALIGN_LEFT, C_DIM, 0.9)
  end
end

function M.attach(t)
  ctx = t
  local g = sv_graph()
  if g and g.res_pick then M.set_pick(g.res_pick) end
end

function M.render()
  local c = ctx
  if not c then return end
  c.seg:ReleaseAllObjects()
  c.sub:ReleaseAllObjects()
  c.rim:ReleaseAllObjects()
  c.lbl:ReleaseAllObjects()
  c.hit_reset()
  row_hit.n = 0
  lane.span = 0
  c.hide_grid(c.grid)
  local TB = Vermilion.TemporalBuffer
  local n = TB.count()
  if n == 0 then
    c.no_data:SetHidden(false)
    return
  end
  local rs = Vermilion.Resources.summary(TB)
  if not rs.has then
    c.no_data:SetText(GetString(VERMILION_GRAPH_NO_RES))
    c.no_data:SetHidden(false)
    return
  end
  c.no_data:SetHidden(true)
  aggregate()
  local canvas = c.canvas
  local cw, ch = canvas:GetWidth(), canvas:GetHeight()
  if cw <= RIGHT_W + 80 or ch <= 40 then return end
  local recording = TB.is_recording()
  local t0 = TB.at(1).t
  local t_hi = recording and c.now() or TB.at(n).t
  local span = t_hi - t0
  if span <= 0 then span = 1 end
  Vermilion.Diagnostics.bump("graph.view_res.renders")
  local S = strings()
  local top = (c.layout.H or 0) + 2
  draw_picker(c, canvas, top, S)
  local y = top + PICK_H + 4
  local h = math_max(8, ch - c.time_strip - y - 2)
  lane.x, lane.w, lane.y, lane.h, lane.t0, lane.span = LANE_X, cw - RIGHT_W - LANE_X - GAP_X, y, h, t0, span
  lane.mid = y + math_floor(h / 2)
  if pick == PICK_BOTH then
    draw_mirrored(c, canvas, TB, n)
  else
    draw_single(c, canvas, TB, n, (pick == PICK_MAG) and MAG or STA)
  end
  draw_time(c, canvas)
  draw_histogram(c, canvas, cw, y, h, S)
end

local function sample_index_at(TB, t)
  local lo, hi = 1, TB.count()
  while lo < hi do
    local mid = math_floor((lo + hi + 1) / 2)
    if TB.at(mid).t <= t then lo = mid else hi = mid - 1 end
  end
  return lo
end

local function starved_span(TB, k, p)
  local s = TB.at(k)
  if not s then return 0 end
  local level = level_of(s, p)
  if not (level > 0 and level < STARVE) then return 0 end
  local i = k
  while i > 1 do
    local pl = level_of(TB.at(i - 1), p)
    if pl > 0 and pl < STARVE then i = i - 1 else break end
  end
  local j = k
  local n = TB.count()
  while j < n do
    local nl = level_of(TB.at(j + 1), p)
    if nl > 0 and nl < STARVE then j = j + 1 else break end
  end
  local t_end = TB.at(j + 1) and TB.at(j + 1).t or TB.at(j).t
  return t_end - TB.at(i).t
end

function M.hover(mx, my)
  local c = ctx
  if not c then return end
  local canvas = c.canvas
  local rel_x, rel_y = mx - canvas:GetLeft(), my - canvas:GetTop()
  local S = strings()
  local rec = nil
  if rel_x >= canvas:GetWidth() - RIGHT_W then
    for i = 1, row_hit.n do
      if rel_y >= row_hit.y0[i] and rel_y <= row_hit.y1[i] then rec = row_hit.rec[i] break end
    end
  end
  if rec ~= hover_row then hover_row = rec; c.rerender() end
  if rec then
    local p = (rec.mag >= rec.sta) and MAG or STA
    local nr = 0
    nr = nr + 1; ROWS[nr][1], ROWS[nr][2] = S.total, c.fmt_val(rec.total)
    nr = nr + 1; ROWS[nr][1], ROWS[nr][2] = S.share, PCT_TEXT[math_floor(rec.total / math_max(totals.spend, 1) * 100 + 0.5)] or ""
    nr = nr + 1; ROWS[nr][1], ROWS[nr][2] = S.pool, S.pools[p]
    c.show_card(pool_col(c, p), rec.name or "", string_format(S.casts, rec.casts, c.fmt_val(rec.total / rec.casts)), "", ROWS, nr, nil, mx, my)
    return
  end
  if lane.span <= 0 or rel_x < lane.x or rel_x > lane.x + lane.w or rel_y < lane.y or rel_y > lane.y + lane.h then
    c.hide_card()
    return
  end
  local p = (pick == PICK_MAG) and MAG or (pick == PICK_STA) and STA or ((rel_y < lane.mid) and MAG or STA)
  local t = lane.t0 + (rel_x - lane.x) / lane.w * lane.span
  local TB = Vermilion.TemporalBuffer
  local k = sample_index_at(TB, t)
  local s = TB.at(k)
  if not s then c.hide_card() return end
  local level = level_of(s, p)
  local sigma = Vermilion.Resources.window_sigma(TB, k, 10, p)
  local stat = string_format(S.flows, c.fmt_val(in_of(s, p)), c.fmt_val(out_of(s, p)))
  if sigma then stat = stat .. string_format(S.sigma, sigma) end
  local nr = 0
  local top_id, top_cost = Vermilion.Casts.spend_top(s.t - WINDOW_MS, s.t, p)
  if top_id > 0 then
    nr = nr + 1
    ROWS[nr][1], ROWS[nr][2] = S.top, string_format("%s  ·  %s", Vermilion.SkillColors.ability_name(top_id), c.fmt_val(top_cost))
  end
  local starved_ms = starved_span(TB, k, p)
  if starved_ms >= STARVE_MS then
    nr = nr + 1
    ROWS[nr][1], ROWS[nr][2] = S.starved, c.fmt_secs(starved_ms)
  end
  c.crosshair(math_floor(rel_x))
  local col = (level > 0 and level < LOW) and c.low or pool_col(c, p)
  c.show_card(col, string_format("%s  %d%%", S.pools[p], math_floor(level * 100 + 0.5)), stat,
    "t  " .. c.fmt_secs(s.t - lane.t0), ROWS, nr, nil, mx, my)
end

function M.click(mx, my)
  local c = ctx
  if not c then return false end
  local rel_x, rel_y = mx - c.canvas:GetLeft(), my - c.canvas:GetTop()
  if rel_y < pick_hit.y0 or rel_y > pick_hit.y1 then return false end
  for i = 1, 3 do
    if rel_x >= pick_hit[i].x0 and rel_x <= pick_hit[i].x1 then
      if pick == i then return false end
      M.set_pick(i)
      scroll = 0
      hover_row = nil
      return true
    end
  end
  return false
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
function M.hovered() return hover_row end
function M.clear_hover() hover_row = nil end
function M.rows() return order, order.n end
function M.totals() return totals end
function M.lane() return lane end
