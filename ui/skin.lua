Vermilion = Vermilion or {}
Vermilion.Skin = {}
local M = Vermilion.Skin

local BASE = "Vermilion/assets/skin/"
local END_CAP = 9
local EDGE_SIZE = 8

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
  if backdrop.SetCenterColor then backdrop:SetCenterColor(1, 1, 1, 0.97) end
end

function M.chrome(tex)
  if not tex then return end
  tex:SetTexture(M.CHROME)
  tex:SetColor(1, 1, 1, 0.97)
end
