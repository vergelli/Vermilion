Vermilion = Vermilion or {}
Vermilion.Graph = {}
local M = Vermilion.Graph

local api  = Vermilion.zenimax.api
local zui  = Vermilion.zenimax.ui
local zc   = Vermilion.zenimax.constants
local zev  = Vermilion.zenimax.events
local WINDOW_MANAGER             = zui.WINDOW_MANAGER
local GetGameTimeMilliseconds    = api.GetGameTimeMilliseconds
local GetString                  = api.GetString
local math_max                   = math.max
local math_floor                 = math.floor
local string_format              = string.format

-- ── UI constants ──────────────────────────────────────────────────────────
local log               = Vermilion.Log.for_module("graph")
local TOPLEFT           = zc.TOPLEFT
local BOTTOMLEFT        = zc.BOTTOMLEFT
local BOTTOM            = zc.BOTTOM
local BOTTOMRIGHT       = zc.BOTTOMRIGHT
local CENTER            = zc.CENTER
local GuiRoot           = zc.GuiRoot
local CT_TEXTURE        = zc.CT_TEXTURE
local CT_LABEL          = zc.CT_LABEL
local TEXT_ALIGN_LEFT   = zc.TEXT_ALIGN_LEFT
local TEXT_ALIGN_CENTER = zc.TEXT_ALIGN_CENTER
local TEXT_ALIGN_BOTTOM = zc.TEXT_ALIGN_BOTTOM

local C_EDPS      = { r = 0.88, g = 0.24, b = 0.18, a = 0.92 }  -- deep crimson (HP work)
local C_SHDPS     = { r = 0.85, g = 0.40, b = 0.75, a = 0.90 }  -- pink-magenta (shield work)
local C_LINE_EDPS = { r = 1.00, g = 0.42, b = 0.32, a = 1.00 }  -- brighter crimson frontier
local C_LINE_EOS  = { r = 1.00, g = 0.92, b = 0.96, a = 1.00 }  -- bright EOS frontier
local C_CHROME    = { r = 1.00, g = 0.62, b = 0.58, a = 0.82 }  -- pronounced crimson wash

-- CRIT view: muted crimson base (non-crit) + punchy gold cap (crit damage).
local C_NONCRIT   = { r = 0.55, g = 0.22, b = 0.18, a = 0.90 }  -- muted crimson base
local C_CRIT      = { r = 1.00, g = 0.82, b = 0.28, a = 0.96 }  -- bright gold (crit pops)

-- Viewport (the dark graph area) carries a faint crimson hue so the whole
-- window reads as Vermilion's. Only the RGB bias changes — the user's alpha
-- (the darkness level) is preserved, so the dark stays dark.
local C_VIEWPORT  = { r = 1.00, g = 0.78, b = 0.75 }

local FILL_TEXTURE   = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_fill.dds"
local FILL_T, FILL_B = 0, 0.53125
local LINE_THICKNESS = 2

local N_HGRID      = 3
local N_VGRID      = 3
local TIME_STRIP_H = 18
local C_GRID_LINE = { r = 0.55, g = 0.58, b = 0.70, a = 0.25 }
local C_GRID_LBL  = { r = 0.82, g = 0.85, b = 0.90, a = 0.92 }
local C_TIME_LBL  = { r = 0.68, g = 0.70, b = 0.75, a = 0.85 }

-- ── state ─────────────────────────────────────────────────────────────────
local controls           = {}
local recording_start_ms = 0

local VIEW_BY_SKILL   = 1
local VIEW_BY_OUTCOME = 2
local VIEW_BY_CRIT    = 3
local VIEW_LABELS     = { "SKILL", "OUTCOME", "CRIT" }
local current_view    = VIEW_BY_SKILL

-- ── small helpers ─────────────────────────────────────────────────────────
local function fmt_val(v)
  if v >= 1000 then return string_format("%.0fk", v / 1000) end
  return tostring(math_floor(v))
end

local function fmt_secs(ms)
  local s = math_floor(ms / 1000)
  if s >= 60 then return string_format("%d:%02d", math_floor(s / 60), s % 60) end
  return s .. "s"
end

-- One-decimal compact form for the header readout (e.g. 12345 -> "12.3k").
local function fmt_readout(v)
  if v >= 1000 then return string_format("%.1fk", v / 1000) end
  return tostring(math_floor(v + 0.5))
end

-- Header DPS iNDICATOR. It may change
local DPS_ICON_IDLE   = "/esoui/art/treeicons/collection_indexicon_weapons_up.dds"
local DPS_ICON_ACTIVE = "/esoui/art/treeicons/collection_indexicon_weapons_down.dds"

local function update_header(eos)
  controls.readout:SetText(fmt_readout(eos))
  controls.dps_icon:SetTexture(eos > 0 and DPS_ICON_ACTIVE or DPS_ICON_IDLE)
end

local function header_tick()
  if controls.window:IsHidden() then return end
  local now = GetGameTimeMilliseconds()
  update_header(Vermilion.Metrics.eDPS(now) + Vermilion.Metrics.ShDPS(now))
end

-- ── pool factories (lib/plot/Pool wrappers) ───────────────────────────────
local Pool = Vermilion.lib.plot.Pool

local function fill_factory(c)
  c:SetTexture(FILL_TEXTURE)
  c:SetTextureCoords(0, 1, FILL_T, FILL_B)
  -- Sub-pixel positioning: keep adjacent bars on a clean float boundary.
  c:SetPixelRoundingEnabled(false)
end

local function fill_reset(c) c:SetHidden(true) end

local function line_factory(line) line:SetThickness(LINE_THICKNESS) end

local function line_reset(line)
  line:SetHidden(true)
  line:ClearAnchors()
end

local function make_fill_pool(name_prefix)
  return Pool.new(name_prefix, controls.canvas, CT_TEXTURE, fill_factory, fill_reset)
end

local function make_line_pool(name_prefix)
  return Pool.new_virtual(name_prefix, controls.canvas, "VermilionGraphLineTemplate", line_factory, line_reset)
end

-- ── grid system ───────────────────────────────────────────────────────────
local function create_grid(prefix, parent_ctrl)
  local WM  = WINDOW_MANAGER
  local obj = { hlines = {}, vlines = {}, ylabels = {} }

  for i = 1, N_HGRID do
    local gl = WM:CreateControl(prefix .. "H" .. i, parent_ctrl, CT_TEXTURE)
    gl:SetTexture(FILL_TEXTURE)
    gl:SetTextureCoords(0, 1, 0, 0.05)
    gl:SetHeight(1)
    gl:SetColor(C_GRID_LINE.r, C_GRID_LINE.g, C_GRID_LINE.b, C_GRID_LINE.a)
    gl:SetHidden(true)
    obj.hlines[i] = gl

    local lbl = WM:CreateControl(prefix .. "YL" .. i, parent_ctrl, CT_LABEL)
    lbl:SetFont("ZoFontGameSmall")
    lbl:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    lbl:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)
    lbl:SetColor(C_GRID_LBL.r, C_GRID_LBL.g, C_GRID_LBL.b, C_GRID_LBL.a)
    lbl:SetDimensions(54, 10)
    lbl:SetHidden(true)
    obj.ylabels[i] = lbl
  end

  for i = 1, N_VGRID do
    local vl = WM:CreateControl(prefix .. "V" .. i, parent_ctrl, CT_TEXTURE)
    vl:SetTexture(FILL_TEXTURE)
    vl:SetTextureCoords(0, 0.05, 0, 1)
    vl:SetWidth(1)
    vl:SetColor(C_GRID_LINE.r, C_GRID_LINE.g, C_GRID_LINE.b, C_GRID_LINE.a)
    vl:SetHidden(true)
    obj.vlines[i] = vl
  end

  local function make_time_lbl(name, align)
    local t = WM:CreateControl(name, parent_ctrl, CT_LABEL)
    t:SetFont("ZoFontGameSmall")
    t:SetHorizontalAlignment(align)
    t:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)
    t:SetColor(C_TIME_LBL.r, C_TIME_LBL.g, C_TIME_LBL.b, C_TIME_LBL.a)
    t:SetDimensions(44, 10)
    t:SetHidden(true)
    return t
  end
  obj.time_l = make_time_lbl(prefix .. "TL", TEXT_ALIGN_LEFT)
  obj.time_m = make_time_lbl(prefix .. "TM", TEXT_ALIGN_CENTER)
  obj.time_r = make_time_lbl(prefix .. "TR", TEXT_ALIGN_RIGHT)

  return obj
end

local function hide_grid(grid)
  for i = 1, N_HGRID do
    grid.hlines[i]:SetHidden(true)
    grid.ylabels[i]:SetHidden(true)
  end
  for i = 1, N_VGRID do grid.vlines[i]:SetHidden(true) end
  grid.time_l:SetHidden(true)
  grid.time_m:SetHidden(true)
  grid.time_r:SetHidden(true)
end

local function draw_grid(grid, canvas, max_val, span_ms)
  local cw = canvas:GetWidth()
  local ch = canvas:GetHeight()
  if cw <= 0 or ch <= 0 then hide_grid(grid) return end

  local has_y    = (max_val > 0)
  local has_time = (span_ms > 0)
  if not has_y and not has_time then hide_grid(grid) return end

  local y_base  = has_time and TIME_STRIP_H or 0
  local ch_plot = math_max(1, ch - y_base)

  if has_y then
    for i = 1, N_HGRID do
      local frac = i / (N_HGRID + 1)
      local y    = y_base + math_floor(ch_plot * frac)
      local gl = grid.hlines[i]
      gl:ClearAnchors()
      gl:SetAnchor(BOTTOMLEFT,  canvas, BOTTOMLEFT,  0, -y)
      gl:SetAnchor(BOTTOMRIGHT, canvas, BOTTOMRIGHT, 0, -y)
      gl:SetHidden(false)
      local lbl = grid.ylabels[i]
      lbl:ClearAnchors()
      lbl:SetAnchor(BOTTOMLEFT, canvas, BOTTOMLEFT, 2, -(y + 1))
      lbl:SetText(fmt_val(max_val * frac))
      lbl:SetHidden(false)
    end
  else
    for i = 1, N_HGRID do
      grid.hlines[i]:SetHidden(true)
      grid.ylabels[i]:SetHidden(true)
    end
  end

  for i = 1, N_VGRID do
    local frac = i / (N_VGRID + 1)
    local x    = math_floor(cw * frac)
    local vl = grid.vlines[i]
    vl:ClearAnchors()
    vl:SetAnchor(TOPLEFT,    canvas, TOPLEFT,    x, 0)
    vl:SetAnchor(BOTTOMLEFT, canvas, BOTTOMLEFT, x, -y_base)
    vl:SetHidden(false)
  end

  if has_time then
    grid.time_l:ClearAnchors()
    grid.time_l:SetAnchor(BOTTOMLEFT, canvas, BOTTOMLEFT, 2, 0)
    grid.time_l:SetText("0s")
    grid.time_l:SetHidden(false)
    grid.time_m:ClearAnchors()
    grid.time_m:SetAnchor(BOTTOM, canvas, BOTTOM, 0, 0)
    grid.time_m:SetText(fmt_secs(span_ms / 2))
    grid.time_m:SetHidden(false)
    grid.time_r:ClearAnchors()
    grid.time_r:SetAnchor(BOTTOMRIGHT, canvas, BOTTOMRIGHT, -2, 0)
    grid.time_r:SetText(fmt_secs(span_ms))
    grid.time_r:SetHidden(false)
  else
    grid.time_l:SetHidden(true)
    grid.time_m:SetHidden(true)
    grid.time_r:SetHidden(true)
  end
end

-- ── release all pools ─────────────────────────────────────────────────────
local function release_all_pools()
  controls.pool_eos_segments:ReleaseAllObjects()
  controls.pool_eos_line:ReleaseAllObjects()
  controls.pool_edps:ReleaseAllObjects()
  controls.pool_shdps:ReleaseAllObjects()
  controls.pool_line_edps:ReleaseAllObjects()
  controls.pool_line_eos:ReleaseAllObjects()
end

local function slot_geometry(cw)
  local capacity = Vermilion.TemporalBuffer.capacity()
  local n        = Vermilion.TemporalBuffer.count()
  local slot_w   = cw / capacity
  local bar_gap  = (slot_w > 3) and 1 or 0
  local bw       = math_max(1, slot_w - bar_gap)
  local offset   = capacity - n
  return slot_w, bw, offset
end

local function window_extent()
  local max_eos = 0
  local t_first, t_last = 0, 0
  Vermilion.TemporalBuffer.iterate(function(i, s)
    local eos = s.eDPS + s.ShDPS
    if eos > max_eos then max_eos = eos end
    if i == 1 then t_first = s.t end
    t_last = s.t
  end)
  return max_eos, (t_last - t_first)
end

-- ── View 1 — BY_SKILL: EOS stack colored by skill line ────────────────────
local function render_by_skill()
  controls.pool_eos_segments:ReleaseAllObjects()
  controls.pool_eos_line:ReleaseAllObjects()
  controls.pool_edps:ReleaseAllObjects()
  controls.pool_shdps:ReleaseAllObjects()
  controls.pool_line_edps:ReleaseAllObjects()
  controls.pool_line_eos:ReleaseAllObjects()

  local n = Vermilion.TemporalBuffer.count()
  if n == 0 then
    controls.no_data:SetHidden(false)
    hide_grid(controls.grid)
    return
  end
  controls.no_data:SetHidden(true)

  local canvas = controls.canvas
  local cw, ch = canvas:GetWidth(), canvas:GetHeight()
  if cw <= 4 or ch <= 4 then return end
  local ch_plot = math_max(4, ch - TIME_STRIP_H)

  local max_eos, span_ms = window_extent()
  if max_eos <= 0 then hide_grid(controls.grid) return end
  draw_grid(controls.grid, canvas, max_eos, span_ms)

  local slot_w, bw, offset = slot_geometry(cw)
  local xs, eos_hs = {}, {}

  Vermilion.TemporalBuffer.iterate(function(i, s)
    local x   = (offset + i - 1) * slot_w
    local eos = s.eDPS + s.ShDPS
    local col_h = math_max(0, math_floor(ch_plot * (eos / max_eos) + 0.5))
    xs[i]     = x + bw * 0.5
    eos_hs[i] = col_h

    local y_off = 0
    local groups = s.eos_groups
    for g = 1, #groups do
      local grp   = groups[g]
      local seg_h = math_max(1, math_floor(col_h * grp.share + 0.5))
      local t = controls.pool_eos_segments:AcquireObject()
      t:ClearAnchors()
      t:SetAnchor(BOTTOMLEFT, canvas, BOTTOMLEFT, x, -(y_off + TIME_STRIP_H))
      t:SetWidth(bw)
      t:SetHeight(seg_h)
      t:SetColor(grp.r, grp.g, grp.b, grp.a)
      t:SetHidden(false)
      y_off = y_off + seg_h
    end
  end)

  -- Top frontier polyline (EOS), gated on slot width like Verdant.
  if slot_w >= 3 then
    for i = 2, n do
      local le = controls.pool_eos_line:AcquireObject()
      le:ClearAnchors()
      le:SetAnchor(BOTTOMLEFT,  canvas, BOTTOMLEFT, xs[i-1], -(eos_hs[i-1] + TIME_STRIP_H))
      le:SetAnchor(BOTTOMRIGHT, canvas, BOTTOMLEFT, xs[i],   -(eos_hs[i]   + TIME_STRIP_H))
      le:SetColor(C_LINE_EOS.r, C_LINE_EOS.g, C_LINE_EOS.b, C_LINE_EOS.a)
      le:SetThickness(LINE_THICKNESS)
      le:SetHidden(false)
    end
  end
end

-- ── View 2 — BY_OUTCOME: eDPS (bottom) + ShDPS (top) ──────────────────────
local function render_by_outcome()
  controls.pool_eos_segments:ReleaseAllObjects()
  controls.pool_eos_line:ReleaseAllObjects()
  controls.pool_edps:ReleaseAllObjects()
  controls.pool_shdps:ReleaseAllObjects()
  controls.pool_line_edps:ReleaseAllObjects()
  controls.pool_line_eos:ReleaseAllObjects()

  local n = Vermilion.TemporalBuffer.count()
  if n == 0 then
    controls.no_data:SetHidden(false)
    hide_grid(controls.grid)
    return
  end
  controls.no_data:SetHidden(true)

  local canvas = controls.canvas
  local cw, ch = canvas:GetWidth(), canvas:GetHeight()
  if cw <= 4 or ch <= 4 then return end
  local ch_plot = math_max(4, ch - TIME_STRIP_H)

  local max_eos, span_ms = window_extent()
  if max_eos <= 0 then hide_grid(controls.grid) return end
  draw_grid(controls.grid, canvas, max_eos, span_ms)

  local slot_w, bw, offset = slot_geometry(cw)
  local xs, edps_hs, eos_hs = {}, {}, {}

  Vermilion.TemporalBuffer.iterate(function(i, s)
    local x       = (offset + i - 1) * slot_w
    local edps_h  = math_max(0, math_floor(ch_plot * (s.eDPS  / max_eos) + 0.5))
    local shdps_h = math_max(0, math_floor(ch_plot * (s.ShDPS / max_eos) + 0.5))
    xs[i]      = x + bw * 0.5
    edps_hs[i] = edps_h
    eos_hs[i]  = edps_h + shdps_h

    if edps_h > 0 then
      local te = controls.pool_edps:AcquireObject()
      te:ClearAnchors()
      te:SetAnchor(BOTTOMLEFT, canvas, BOTTOMLEFT, x, -TIME_STRIP_H)
      te:SetWidth(bw)
      te:SetHeight(edps_h)
      te:SetColor(C_EDPS.r, C_EDPS.g, C_EDPS.b, C_EDPS.a)
      te:SetHidden(false)
    end

    if shdps_h > 0 then
      local ts = controls.pool_shdps:AcquireObject()
      ts:ClearAnchors()
      ts:SetAnchor(BOTTOMLEFT, canvas, BOTTOMLEFT, x, -(TIME_STRIP_H + edps_h))
      ts:SetWidth(bw)
      ts:SetHeight(shdps_h)
      ts:SetColor(C_SHDPS.r, C_SHDPS.g, C_SHDPS.b, C_SHDPS.a)
      ts:SetHidden(false)
    end
  end)

  if slot_w >= 3 then
    for i = 2, n do
      local le = controls.pool_line_edps:AcquireObject()
      le:ClearAnchors()
      le:SetAnchor(BOTTOMLEFT,  canvas, BOTTOMLEFT, xs[i-1], -(edps_hs[i-1] + TIME_STRIP_H))
      le:SetAnchor(BOTTOMRIGHT, canvas, BOTTOMLEFT, xs[i],   -(edps_hs[i]   + TIME_STRIP_H))
      le:SetColor(C_LINE_EDPS.r, C_LINE_EDPS.g, C_LINE_EDPS.b, C_LINE_EDPS.a)
      le:SetThickness(LINE_THICKNESS)
      le:SetHidden(false)

      local lo = controls.pool_line_eos:AcquireObject()
      lo:ClearAnchors()
      lo:SetAnchor(BOTTOMLEFT,  canvas, BOTTOMLEFT, xs[i-1], -(eos_hs[i-1] + TIME_STRIP_H))
      lo:SetAnchor(BOTTOMRIGHT, canvas, BOTTOMLEFT, xs[i],   -(eos_hs[i]   + TIME_STRIP_H))
      lo:SetColor(C_LINE_EOS.r, C_LINE_EOS.g, C_LINE_EOS.b, C_LINE_EOS.a)
      lo:SetThickness(LINE_THICKNESS)
      lo:SetHidden(false)
    end
  end
end

-- ── View 3 — BY_CRIT: non-crit (bottom) + crit (top), of landed damage ─────
local function render_by_crit()
  controls.pool_eos_segments:ReleaseAllObjects()
  controls.pool_eos_line:ReleaseAllObjects()
  controls.pool_edps:ReleaseAllObjects()
  controls.pool_shdps:ReleaseAllObjects()
  controls.pool_line_edps:ReleaseAllObjects()
  controls.pool_line_eos:ReleaseAllObjects()

  local n = Vermilion.TemporalBuffer.count()
  if n == 0 then
    controls.no_data:SetHidden(false)
    hide_grid(controls.grid)
    return
  end
  controls.no_data:SetHidden(true)

  local canvas = controls.canvas
  local cw, ch = canvas:GetWidth(), canvas:GetHeight()
  if cw <= 4 or ch <= 4 then return end
  local ch_plot = math_max(4, ch - TIME_STRIP_H)

  -- Scale to the window's max eDPS (the crit stack sums to eDPS) so the crit
  -- ratio reads at full vertical resolution regardless of shield activity.
  local max_edps, span_ms = 0, 0
  do
    local t_first, t_last = 0, 0
    Vermilion.TemporalBuffer.iterate(function(i, s)
      if s.eDPS > max_edps then max_edps = s.eDPS end
      if i == 1 then t_first = s.t end
      t_last = s.t
    end)
    span_ms = t_last - t_first
  end
  if max_edps <= 0 then hide_grid(controls.grid) return end
  draw_grid(controls.grid, canvas, max_edps, span_ms)

  local slot_w, bw, offset = slot_geometry(cw)
  local xs, top_hs = {}, {}

  Vermilion.TemporalBuffer.iterate(function(i, s)
    local x         = (offset + i - 1) * slot_w
    local noncrit_h = math_max(0, math_floor(ch_plot * (s.noncrit / max_edps) + 0.5))
    local crit_h    = math_max(0, math_floor(ch_plot * (s.crit    / max_edps) + 0.5))
    xs[i]     = x + bw * 0.5
    top_hs[i] = noncrit_h + crit_h

    -- Non-crit base (bottom), muted crimson.
    if noncrit_h > 0 then
      local tn = controls.pool_edps:AcquireObject()
      tn:ClearAnchors()
      tn:SetAnchor(BOTTOMLEFT, canvas, BOTTOMLEFT, x, -TIME_STRIP_H)
      tn:SetWidth(bw)
      tn:SetHeight(noncrit_h)
      tn:SetColor(C_NONCRIT.r, C_NONCRIT.g, C_NONCRIT.b, C_NONCRIT.a)
      tn:SetHidden(false)
    end

    -- Crit cap (top), gold.
    if crit_h > 0 then
      local tc = controls.pool_shdps:AcquireObject()
      tc:ClearAnchors()
      tc:SetAnchor(BOTTOMLEFT, canvas, BOTTOMLEFT, x, -(TIME_STRIP_H + noncrit_h))
      tc:SetWidth(bw)
      tc:SetHeight(crit_h)
      tc:SetColor(C_CRIT.r, C_CRIT.g, C_CRIT.b, C_CRIT.a)
      tc:SetHidden(false)
    end
  end)

  -- Single frontier polyline at the top of the stack (= landed-damage level).
  if slot_w >= 3 then
    for i = 2, n do
      local lt = controls.pool_line_edps:AcquireObject()
      lt:ClearAnchors()
      lt:SetAnchor(BOTTOMLEFT,  canvas, BOTTOMLEFT, xs[i-1], -(top_hs[i-1] + TIME_STRIP_H))
      lt:SetAnchor(BOTTOMRIGHT, canvas, BOTTOMLEFT, xs[i],   -(top_hs[i]   + TIME_STRIP_H))
      lt:SetColor(C_LINE_EDPS.r, C_LINE_EDPS.g, C_LINE_EDPS.b, C_LINE_EDPS.a)
      lt:SetThickness(LINE_THICKNESS)
      lt:SetHidden(false)
    end
  end
end

local function render_current_view()
  if current_view == VIEW_BY_SKILL then
    render_by_skill()
  elseif current_view == VIEW_BY_OUTCOME then
    render_by_outcome()
  else
    render_by_crit()
  end
end

-- ── button state visuals ──────────────────────────────────────────────────
local function refresh_button_colors()
  local recording = Vermilion.TemporalBuffer.is_recording()
  controls.btn_record:SetEnabled(not recording)
  controls.btn_stop:SetEnabled(recording)
end

-- ── view switching ────────────────────────────────────────────────────────
local function persist_view()
  local sv = Vermilion.SavedVars
  if sv then sv.graph = sv.graph or {} ; sv.graph.view_idx = current_view end
end

local function set_view(v)
  current_view = v
  controls.view_label:SetText(VIEW_LABELS[v])
  persist_view()
  if Vermilion.TemporalBuffer.count() == 0 then
    controls.no_data:SetHidden(false)
    return
  end
  controls.no_data:SetHidden(true)
  render_current_view()
end

-- ── sampling loop ─────────────────────────────────────────────────────────
local prof_enter = Vermilion.Profiler.enter
local prof_exit  = Vermilion.Profiler.exit

local function on_sample_update()
  prof_enter("graph.sample_tick")
  local now   = GetGameTimeMilliseconds()
  local edps  = Vermilion.Metrics.eDPS(now)
  local shdps = Vermilion.Metrics.ShDPS(now)
  local crit, noncrit = Vermilion.Metrics.crit_split(now)
  local eg    = Vermilion.Metrics.eos_groups(now)
  Vermilion.TemporalBuffer.push(now, edps, shdps, crit, noncrit, eg)

  update_header(edps + shdps)

  local elapsed = math_floor((now - recording_start_ms) / 1000)
  controls.status:SetText(string_format("%d:%02d", math_floor(elapsed / 60), elapsed % 60))

  if not controls.window:IsHidden() then
    render_current_view()
  end
  prof_exit("graph.sample_tick")
end

-- ── public API ────────────────────────────────────────────────────────────
function M.current_view() return current_view end

function M.on_record_click()
  if Vermilion.TemporalBuffer.is_recording() then return end
  log:info("record click")
  Vermilion.TemporalBuffer.clear()
  release_all_pools()
  hide_grid(controls.grid)
  controls.no_data:SetHidden(false)
  Vermilion.TemporalBuffer.start_recording()
  recording_start_ms = GetGameTimeMilliseconds()
  local sv       = Vermilion.SavedVars
  local interval = (sv and sv.temporal and sv.temporal.sample_rate_ms)
                   or Vermilion.Constants.TEMPORAL.SAMPLE_RATE_DEFAULT
  zev.register_update(Vermilion.Constants.TEMPORAL.UPDATE_NAME, interval, on_sample_update)
  refresh_button_colors()
  controls.status:SetText("0:00")
end

function M.on_stop_click()
  if not Vermilion.TemporalBuffer.is_recording() then return end
  log:info("stop click")
  Vermilion.TemporalBuffer.stop_recording()
  zev.unregister_update(Vermilion.Constants.TEMPORAL.UPDATE_NAME)
  refresh_button_colors()
  render_current_view()
end

function M.on_flush_click()
  if Vermilion.TemporalBuffer.is_recording() then
    zev.unregister_update(Vermilion.Constants.TEMPORAL.UPDATE_NAME)
    Vermilion.TemporalBuffer.stop_recording()
  end
  Vermilion.TemporalBuffer.clear()
  release_all_pools()
  hide_grid(controls.grid)
  refresh_button_colors()
  controls.status:SetText("")
  update_header(0)
  controls.no_data:SetHidden(false)
end

function M.on_close_click()
  Vermilion.Visibility.set("graph", false)
  release_all_pools()
end

function M.on_move_stop()
  local sv = Vermilion.SavedVars
  if not sv then return end
  sv.graph = sv.graph or {}
  local x, y = controls.window:GetCenter()
  sv.graph.x = x
  sv.graph.y = y
end

function M.on_resize_stop()
  local sv = Vermilion.SavedVars
  if sv then
    sv.graph = sv.graph or {}
    local w, h = controls.window:GetDimensions()
    sv.graph.w = w
    sv.graph.h = h
  end
  if not controls.window:IsHidden() then render_current_view() end
end

function M.prev_view()
  local v = current_view - 1
  if v < VIEW_BY_SKILL then v = VIEW_BY_CRIT end
  release_all_pools()
  set_view(v)
end

function M.next_view()
  local v = current_view + 1
  if v > VIEW_BY_CRIT then v = VIEW_BY_SKILL end
  release_all_pools()
  set_view(v)
end

-- Live-applies viewport alpha (0..1). Called by the settings slider.
function M.set_viewport_alpha(a)
  VermilionGraphWindowViewportBg:SetCenterColor(C_VIEWPORT.r, C_VIEWPORT.g, C_VIEWPORT.b, a)
end

function M.toggle()
  local now_visible = not Vermilion.Visibility.get("graph")
  log:info("toggle ->", now_visible and "show" or "hide")
  Vermilion.Visibility.set("graph", now_visible)
  if now_visible then
    render_current_view()
  else
    release_all_pools()
  end
end

-- ── init ──────────────────────────────────────────────────────────────────
function M.init()
  controls.window        = VermilionGraphWindow
  controls.title         = VermilionGraphWindowTitleLabel
  controls.btn_record    = VermilionGraphWindowRecordBtn
  controls.btn_stop      = VermilionGraphWindowStopBtn
  controls.btn_flush     = VermilionGraphWindowFlushBtn
  controls.status        = VermilionGraphWindowStatusLabel
  controls.btn_prev_view = VermilionGraphWindowPrevViewBtn
  controls.view_label    = VermilionGraphWindowViewLabel
  controls.btn_next_view = VermilionGraphWindowNextViewBtn
  controls.viewport      = VermilionGraphWindowViewport
  controls.canvas        = VermilionGraphWindowViewportCanvas
  controls.no_data       = VermilionGraphWindowViewportNoDataLabel
  controls.readout       = VermilionGraphWindowReadoutLabel
  controls.dps_icon      = VermilionGraphWindowDpsIcon

  -- Restore saved view, position and size.
  local sv = Vermilion.SavedVars
  sv.graph = sv.graph or {}
  if sv.graph.view_idx and sv.graph.view_idx >= VIEW_BY_SKILL
     and sv.graph.view_idx <= VIEW_BY_CRIT then
    current_view = sv.graph.view_idx
  end
  if sv.graph.x then
    controls.window:ClearAnchors()
    controls.window:SetAnchor(CENTER, GuiRoot, TOPLEFT, sv.graph.x, sv.graph.y)
  end
  if sv.graph.w then
    controls.window:SetDimensions(sv.graph.w, sv.graph.h)
  end
  controls.window:SetDimensionConstraints(360, 240, 1000, 700)

  VermilionGraphWindowBg:SetCenterColor(0, 0, 0, 0)
  VermilionGraphWindowChromeTop   :SetColor(C_CHROME.r, C_CHROME.g, C_CHROME.b, C_CHROME.a)
  VermilionGraphWindowChromeBottom:SetColor(C_CHROME.r, C_CHROME.g, C_CHROME.b, C_CHROME.a)
  VermilionGraphWindowChromeLeft  :SetColor(C_CHROME.r, C_CHROME.g, C_CHROME.b, C_CHROME.a)
  VermilionGraphWindowChromeRight :SetColor(C_CHROME.r, C_CHROME.g, C_CHROME.b, C_CHROME.a)
  -- Crisp crimson border: the border texture takes color cleanly and is never
  -- covered by buttons, so it's the surface that actually reads as "Vermilion".
  VermilionGraphWindowBg:SetEdgeColor(1.00, 0.45, 0.40, 1.0)
  local sv_a = (sv.graph and sv.graph.viewport_alpha_pct) or 30
  VermilionGraphWindowViewportBg:SetCenterColor(C_VIEWPORT.r, C_VIEWPORT.g, C_VIEWPORT.b, sv_a / 100)

  -- Grid (behind pools).
  controls.grid = create_grid("VermilionGrid", controls.canvas)

  -- Object pools (created after grid; pool objects render on top).
  controls.pool_eos_segments = make_fill_pool("VermilionEosSeg")
  controls.pool_eos_line     = make_line_pool("VermilionEosLine")
  controls.pool_edps         = make_fill_pool("VermilionEdpsFill")
  controls.pool_shdps        = make_fill_pool("VermilionShdpsFill")
  controls.pool_line_edps    = make_line_pool("VermilionLineEdps")
  controls.pool_line_eos     = make_line_pool("VermilionLineEos")

  -- Labels / button text.
  controls.title:SetText(GetString(VERMILION_GRAPH_TITLE))
  controls.title:SetColor(0.75, 0.75, 0.75, 1)
  controls.btn_record:SetText(GetString(VERMILION_GRAPH_RECORD))
  controls.btn_stop:SetText(GetString(VERMILION_GRAPH_STOP))
  controls.btn_flush:SetText(GetString(VERMILION_GRAPH_FLUSH))
  controls.status:SetText("")
  controls.status:SetColor(0.65, 0.65, 0.65, 1)
  controls.no_data:SetText(GetString(VERMILION_GRAPH_NO_DATA))
  controls.no_data:SetColor(0.45, 0.45, 0.45, 1)
  controls.no_data:SetHidden(false)
  controls.view_label:SetText(VIEW_LABELS[current_view])
  controls.view_label:SetColor(0.75, 0.75, 0.75, 1)

  -- Live EOS readout in the header (weapons icon + value).
  controls.readout:SetColor(C_LINE_EOS.r, C_LINE_EOS.g, C_LINE_EOS.b, 0.95)
  update_header(0)
  -- Always-on 1 Hz refresh so the header tracks live DPS independent of the
  -- record/stop lifecycle.
  zev.register_update("VermilionHeaderTick", 1000, header_tick)

  refresh_button_colors()
end
