Vermilion = Vermilion or {}
Vermilion.Skin = {}
local M = Vermilion.Skin

local BASE = "Vermilion/assets/skin/"
local END_CAP = 9
local EDGE_SIZE = 8
local SURFACE_PX = 512
local TONE = 0.76
local INSET = 2
local CHROME_TOP = 100
local CHROME_SIDE = 14

M.CHROME = BASE .. "chrome.dds"
M.TAB_ON = BASE .. "tab_on.dds"
M.RADIO_ON = BASE .. "radio_on.dds"
M.RADIO_OFF = BASE .. "radio_off.dds"
M.CARET = BASE .. "caret.dds"
M.FRAME_EDGE = BASE .. "frame_edge.dds"
M.GOLD = { r = 0.77, g = 0.63, b = 0.36 }
M.TEXT = { r = 0.96, g = 0.91, b = 0.87 }

local PLAIN = {
  up = BASE .. "btn_up.dds", over = BASE .. "btn_over.dds",
  down = BASE .. "btn_down.dds", disabled = BASE .. "btn_disabled.dds",
}
local LACQUER = {
  up = BASE .. "lacq_up.dds", over = BASE .. "lacq_over.dds",
  down = BASE .. "lacq_down.dds", disabled = BASE .. "lacq_disabled.dds",
}
M.PLAIN, M.LACQUER = PLAIN, LACQUER
M.SUBTAB = BASE .. "subtab.dds"
M.CLOSE = { up = BASE .. "close_up.dds", over = BASE .. "close_over.dds", down = BASE .. "close_down.dds" }

function M.button(b, lacquer)
  if not b or not b.SetNormalTexture then return end
  local t = lacquer and LACQUER or PLAIN
  b:SetNormalTexture(t.up)
  b:SetMouseOverTexture(t.over)
  b:SetPressedTexture(t.down)
  b:SetDisabledTexture(t.disabled)
  if b.SetEndCapWidth then b:SetEndCapWidth(END_CAP) end
  if b.SetMouseOverBlendMode then b:SetMouseOverBlendMode(TEX_BLEND_MODE_ALPHA or 0) end
  if b.SetNormalFontColor then b:SetNormalFontColor(M.TEXT.r, M.TEXT.g, M.TEXT.b, 1) end
  if b.SetMouseOverFontColor then b:SetMouseOverFontColor(1, 1, 1, 1) end
  if b.SetPressedFontColor then b:SetPressedFontColor(M.TEXT.r, M.TEXT.g, M.TEXT.b, 1) end
end

function M.close(b)
  if not b or not b.SetNormalTexture then return end
  b:SetNormalTexture(M.CLOSE.up)
  b:SetMouseOverTexture(M.CLOSE.over)
  b:SetPressedTexture(M.CLOSE.down)
  if b.SetMouseOverBlendMode then b:SetMouseOverBlendMode(TEX_BLEND_MODE_ALPHA or 0) end
end

function M.icons(list)
  for i = 1, #list do
    local b = list[i]
    if b and b.SetMouseOverBlendMode then b:SetMouseOverBlendMode(TEX_BLEND_MODE_ALPHA or 0) end
  end
end

function M.buttons(list, lacquer)
  for i = 1, #list do M.button(list[i], lacquer) end
end

function M.frame(backdrop)
  if not backdrop or not backdrop.SetEdgeTexture then return end
  backdrop:SetEdgeTexture(M.FRAME_EDGE, 128, 16, EDGE_SIZE)
  if backdrop.SetEdgeColor then backdrop:SetEdgeColor(1, 1, 1, 1) end
end

function M.panel(backdrop)
  if not backdrop then return end
  M.frame(backdrop)
  if backdrop.SetCenterTexture then backdrop:SetCenterTexture(M.CHROME) end
  if backdrop.SetCenterColor then backdrop:SetCenterColor(TONE, TONE, TONE, 0.97) end
  if backdrop.SetInsets then backdrop:SetInsets(INSET, INSET, -INSET, -INSET) end
end

function M.section(backdrop)
  if not backdrop or not backdrop.SetEdgeTexture then return end
  backdrop:SetEdgeTexture(BASE .. "panel_edge.dds", 128, 16, EDGE_SIZE)
  backdrop:SetEdgeColor(1, 1, 1, 1)
  backdrop:SetCenterTexture(BASE .. "panel_center.dds")
  backdrop:SetCenterColor(1, 1, 1, 1)
  if backdrop.SetInsets then backdrop:SetInsets(1, 1, -1, -1) end
end

function M.chrome(tex)
  if not tex then return end
  tex:SetTexture(M.CHROME)
  tex:SetColor(TONE, TONE, TONE, 0.97)
end

function M.chrome_light(tex)
  tex:SetVertexColors(VERTEX_POINTS_TOPLEFT, 1, 1, 1, 0.97)
  tex:SetVertexColors(VERTEX_POINTS_TOPRIGHT, 1, 1, 1, 0.97)
end

local function slice(tex, x0, x1, y0, y1)
  tex:SetTextureCoords(x0 / SURFACE_PX, x1 / SURFACE_PX, y0 / SURFACE_PX, y1 / SURFACE_PX)
end

function M.fit_chrome(top, bottom, left, right, w, h)
  slice(top, INSET, w - INSET, INSET, CHROME_TOP)
  slice(bottom, INSET, w - INSET, h - CHROME_SIDE, h - INSET)
  slice(left, INSET, CHROME_SIDE, CHROME_TOP, h - CHROME_SIDE)
  slice(right, w - CHROME_SIDE, w - INSET, CHROME_TOP, h - CHROME_SIDE)
end
