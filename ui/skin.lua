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
local ALPHA = 0.97
local GAIN = 3
local LEVEL = TONE / GAIN
local LAB_DIR = BASE .. "lab/"
local SURFACES = { "crystal", "garnet", "smoked", "frosted", "polished", "piano", "goldstone", "flake", "ruby", "crackle", "veins" }
local BUCKETS = { "vermilion", "vermilion_vivo", "carmesi", "carmin", "original" }
local lab = { surface = 1, light = true, bucket = 1 }
local strips, panels = {}, {}
local lit

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
  panels[#panels + 1] = backdrop
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
  strips[#strips + 1] = tex
end

function M.chrome_light(tex)
  lit = tex
end

local function surface_path()
  return LAB_DIR .. "surf_" .. SURFACES[lab.surface] .. ".dds"
end

local function apply_surface()
  local path = surface_path()
  for i = 1, #strips do
    strips[i]:SetTexture(path)
    strips[i]:SetColor(LEVEL, LEVEL, LEVEL, ALPHA)
  end
  if lit then
    local k = lab.light and 1 / GAIN or LEVEL
    lit:SetVertexColors(VERTEX_POINTS_TOPLEFT, k, k, k, ALPHA)
    lit:SetVertexColors(VERTEX_POINTS_TOPRIGHT, k, k, k, ALPHA)
  end
  for i = 1, #panels do
    local p = panels[i]
    if p.SetCenterTexture then p:SetCenterTexture(path, SURFACE_PX, TEX_MODE_WRAP) end
    if p.SetCenterColor then p:SetCenterColor(LEVEL, LEVEL, LEVEL, ALPHA) end
  end
  if Vermilion.Graph and Vermilion.Graph.fit_chrome then Vermilion.Graph.fit_chrome() end
end

local function apply_bucket()
  local b = VermilionSettingsPanelUnknownBtn
  if not b then return end
  local base = LAB_DIR .. "bucket_" .. BUCKETS[lab.bucket]
  b:SetNormalTexture(base .. "_up.dds")
  b:SetPressedTexture(base .. "_down.dds")
  b:SetMouseOverTexture(base .. "_over.dds")
end

local function lab_store()
  local sv = Vermilion.SavedVars
  if not sv then return nil end
  sv.lab = sv.lab or {}
  return sv.lab
end

function M.lab_apply()
  local s = lab_store()
  if s then
    lab.surface = SURFACES[s.surface] and s.surface or lab.surface
    lab.bucket = BUCKETS[s.bucket] and s.bucket or lab.bucket
    if s.light ~= nil then lab.light = s.light end
  end
  apply_surface()
  apply_bucket()
end

local function lab_step(key, size, value)
  local n = tonumber(value)
  if n and n >= 1 and n <= size then lab[key] = n
  elseif value == "prev" then lab[key] = (lab[key] - 2) % size + 1
  else lab[key] = lab[key] % size + 1 end
  local s = lab_store()
  if s then s[key] = lab[key] end
  return lab[key], size
end

function M.lab_surface(value)
  local i, n = lab_step("surface", #SURFACES, value)
  apply_surface()
  return string.format("surface %d/%d %s", i, n, SURFACES[i])
end

function M.lab_bucket(value)
  local i, n = lab_step("bucket", #BUCKETS, value)
  apply_bucket()
  return string.format("bucket %d/%d %s", i, n, BUCKETS[i])
end

function M.lab_light()
  lab.light = not lab.light
  local s = lab_store()
  if s then s.light = lab.light end
  apply_surface()
  return "top light " .. (lab.light and "on" or "off")
end

function M.lab_current(kind)
  if kind == "surface" then return lab.surface .. " " .. SURFACES[lab.surface] end
  if kind == "bucket" then return lab.bucket .. " " .. BUCKETS[lab.bucket]:gsub("vermilion_", "") end
  return lab.light and "on" or "off"
end

function M.lab_paths()
  local out = {}
  for _, name in ipairs(SURFACES) do out[#out + 1] = LAB_DIR .. "surf_" .. name .. ".dds" end
  for _, name in ipairs(BUCKETS) do
    for _, state in ipairs({ "up", "over", "down" }) do out[#out + 1] = LAB_DIR .. "bucket_" .. name .. "_" .. state .. ".dds" end
  end
  return out
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
