Vermilion = Vermilion or {}
local Vermilion = Vermilion

Vermilion.Heat = {}
local M = Vermilion.Heat

local math_floor = math.floor

M.N = 128
M.FADE_IN = 0.22

local RAMP = {
  { 0.05, 0.03, 0.53 },
  { 0.49, 0.01, 0.66 },
  { 0.80, 0.23, 0.48 },
  { 0.97, 0.53, 0.19 },
  { 0.94, 0.98, 0.13 },
}

local LUT = {}
for i = 0, M.N - 1 do
  local t = i / (M.N - 1) * (#RAMP - 1)
  local k = math_floor(t)
  if k >= #RAMP - 1 then k = #RAMP - 2 end
  local f = t - k
  local a, b = RAMP[k + 1], RAMP[k + 2]
  LUT[i] = { a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f }
end

function M.lut(i)
  if i < 0 then i = 0 end
  if i > M.N - 1 then i = M.N - 1 end
  return LUT[i]
end

function M.level(frac)
  if frac <= 0 then return 0 end
  if frac >= 1 then return M.N - 1 end
  local lv = math_floor(frac * (M.N - 1) + 0.5)
  if lv < 1 then lv = 1 end
  return lv
end

function M.alpha(level)
  local a = level / ((M.N - 1) * M.FADE_IN)
  if a > 1 then a = 1 end
  return 0.30 + 0.70 * a
end
