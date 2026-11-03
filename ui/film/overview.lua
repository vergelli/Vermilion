Vermilion = Vermilion or {}
Vermilion.FilmOverview = {}
local M = Vermilion.FilmOverview

local api = Vermilion.zenimax.api
local zui = Vermilion.zenimax.ui
local zc  = Vermilion.zenimax.constants
local zev = Vermilion.zenimax.events
local math_floor = math.floor

local STRIP_H = 20
local GAP = 3
local PITCH = 3
local INSET = 6
local DRAG_UPDATE = "VermilionFilmStripDrag"
local RIGHT_BUTTON = MOUSE_BUTTON_INDEX_RIGHT or 2
local C_BAR = { r = 0.80, g = 0.68, b = 0.40, a = 0.75 }
local C_FRAME = { r = 0.86, g = 0.28, b = 0.18, a = 0.95 }

local strip, viewport, canvas, on_change
local shade_l, shade_r
local frame = {}
local bars = {}
local peaks = {}
local showing = false
local dragging = false
local sig_n, sig_w, sig_t = -1, -1, -1

local function texture(name, level, r, g, b, a)
  local t = zui.WINDOW_MANAGER:CreateControl(name, strip, zc.CT_TEXTURE)
  t:SetColor(r, g, b, a)
  t:SetDrawLevel(level)
  t:SetHidden(true)
  return t
end

local function place(t, x, y, w, h)
  t:ClearAnchors()
  t:SetAnchor(TOPLEFT, strip, TOPLEFT, x, y)
  t:SetDimensions(w, h)
  t:SetHidden(false)
end

local function draw_bars(n, w)
  local TB = Vermilion.TemporalBuffer
  local count = math_floor(w / PITCH)
  if count > n then count = n end
  if count < 1 then count = 1 end
  for i = 1, count do peaks[i] = 0 end
  local top = 0
  for i = 1, n do
    local s = TB.at(i)
    local v = s.eDPS + s.ShDPS
    local c = math_floor((i - 1) * count / n) + 1
    if v > peaks[c] then
      peaks[c] = v
      if v > top then top = v end
    end
  end
  local bw = w / count
  for i = 1, count do
    local bar = bars[i]
    if not bar then
      bar = texture("VermilionFilmStripBar" .. i, 3, C_BAR.r, C_BAR.g, C_BAR.b, C_BAR.a)
      bars[i] = bar
    end
    local h = (top > 0) and math_floor((STRIP_H - 2) * peaks[i] / top + 0.5) or 0
    if h > 0 then
      local x0 = math_floor((i - 1) * bw)
      local x1 = math_floor(i * bw)
      place(bar, x0, STRIP_H - 1 - h, (x1 > x0 + 1) and (x1 - x0 - 1) or 1, h)
    else
      bar:SetHidden(true)
    end
  end
  for i = count + 1, #bars do bars[i]:SetHidden(true) end
end

local function draw_window(n, w)
  local cols = Vermilion.FilmColumns.cols
  local x0 = math_floor((cols.first - 1) / n * w)
  local x1 = math_floor(cols.last / n * w + 0.5)
  if x1 < x0 + 4 then x1 = x0 + 4 end
  if x0 > 0 then place(shade_l, 0, 0, x0, STRIP_H) else shade_l:SetHidden(true) end
  if x1 < w then place(shade_r, x1, 0, w - x1, STRIP_H) else shade_r:SetHidden(true) end
  place(frame[1], x0, 0, x1 - x0, 1)
  place(frame[2], x0, STRIP_H - 1, x1 - x0, 1)
  place(frame[3], x0, 0, 1, STRIP_H)
  place(frame[4], x1 - 1, 0, 1, STRIP_H)
end

function M.draw()
  if not showing then return end
  local TB = Vermilion.TemporalBuffer
  local n = TB.count()
  if n < 2 then return end
  local w = strip:GetWidth()
  if w <= 0 then return end
  local t = TB.at(n).t
  if n ~= sig_n or w ~= sig_w or t ~= sig_t then
    sig_n, sig_w, sig_t = n, w, t
    draw_bars(n, w)
  end
  draw_window(n, w)
end

function M.sync(on)
  if on == showing or not strip then return end
  showing = on
  strip:SetHidden(not on)
  canvas:ClearAnchors()
  canvas:SetAnchor(TOPLEFT, viewport, TOPLEFT, INSET, INSET)
  canvas:SetAnchor(BOTTOMRIGHT, viewport, BOTTOMRIGHT, -INSET, on and -(INSET + STRIP_H + GAP) or -INSET)
  sig_n = -1
end

function M.is_showing() return showing end

function M.drag_to(frac)
  local n = Vermilion.TemporalBuffer.count()
  if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
  if Vermilion.FilmWindow.center_on(frac, n) and on_change then on_change() end
end

local function follow_mouse()
  local w = strip:GetWidth()
  if w <= 0 then return end
  local mx = api.GetUIMousePosition()
  M.drag_to((mx - strip:GetLeft()) / w)
end

local function stop_drag()
  if not dragging then return end
  dragging = false
  zev.unregister_update(DRAG_UPDATE)
end

function M.mouse_down(button)
  if button == RIGHT_BUTTON then
    if Vermilion.FilmWindow.reset() and on_change then on_change() end
    return
  end
  follow_mouse()
  if not dragging then
    dragging = true
    zev.register_update(DRAG_UPDATE, 16, follow_mouse)
  end
end

function M.mouse_up() stop_drag() end

function M.wheel(delta)
  local cols = Vermilion.FilmColumns.cols
  local n = Vermilion.TemporalBuffer.count()
  local mid = (cols.first + cols.last) / 2
  local dir = (delta and delta < 0) and 1 or -1
  local denom = cols.denom
  local frac = (denom > 0) and ((mid - cols.first) / denom) or 0.5
  if Vermilion.FilmWindow.zoom(dir, frac, n) and on_change then on_change() end
end

function M.attach(view, canv, changed)
  viewport, canvas, on_change = view, canv, changed
  strip = zui.WINDOW_MANAGER:CreateControl("VermilionFilmStrip", viewport, zc.CT_CONTROL)
  strip:SetAnchor(BOTTOMLEFT, viewport, BOTTOMLEFT, INSET, -INSET)
  strip:SetAnchor(BOTTOMRIGHT, viewport, BOTTOMRIGHT, -INSET, -INSET)
  strip:SetHeight(STRIP_H)
  strip:SetMouseEnabled(true)
  strip:SetHidden(true)
  local track = texture("VermilionFilmStripTrack", 2, 0, 0, 0, 0.35)
  track:SetAnchorFill(strip)
  track:SetHidden(false)
  shade_l = texture("VermilionFilmStripShadeL", 4, 0, 0, 0, 0.60)
  shade_r = texture("VermilionFilmStripShadeR", 4, 0, 0, 0, 0.60)
  for i = 1, 4 do
    frame[i] = texture("VermilionFilmStripFrame" .. i, 5, C_FRAME.r, C_FRAME.g, C_FRAME.b, C_FRAME.a)
  end
  zui.tooltip(strip, VERMILION_TIP_FILM_STRIP, TOP)
  strip:SetHandler("OnMouseDown", function(_, button) M.mouse_down(button) end)
  strip:SetHandler("OnMouseUp", function() M.mouse_up() end)
  strip:SetHandler("OnMouseWheel", function(_, delta) M.wheel(delta) end)
end
