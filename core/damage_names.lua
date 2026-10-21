Vermilion = Vermilion or {}
local Vermilion = Vermilion

Vermilion.DamageNames = {}
local M = Vermilion.DamageNames

local by_name = {}
local key = { n = -1, t0 = 0, t1 = 0 }
local total = 0

function M.by_name(TB)
  local n = TB.count()
  local first, last = TB.at(1), TB.at(n)
  local t0, t1 = first and first.t or 0, last and last.t or 0
  if key.n == n and key.t0 == t0 and key.t1 == t1 then return by_name, total end
  key.n, key.t0, key.t1 = n, t0, t1
  for k in pairs(by_name) do by_name[k] = nil end
  total = 0
  local SC = Vermilion.SkillColors
  local t_prev = nil
  for k = 1, n do
    local s = TB.at(k)
    local dt = t_prev and (s.t - t_prev) / 1000 or 1
    if dt <= 0 then dt = 1 end
    t_prev = s.t
    local eos = ((s.eDPS or 0) + (s.ShDPS or 0)) * dt
    if eos > 0 then
      total = total + eos
      local ab = s.eos_abilities
      local cnt = ab and ab.count or 0
      for i = 1, cnt do
        local e = ab[i]
        local id, sh = e.id or 0, e.share or 0
        if id > 0 and sh > 0 then
          local nm = SC.ability_name(id)
          if nm and nm ~= "" then by_name[nm] = (by_name[nm] or 0) + sh * eos end
        end
      end
    end
  end
  return by_name, total
end

function M.invalidate() key.n = -1 end
