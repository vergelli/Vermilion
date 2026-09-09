local M = {}

local SIG = {
  CE = "nbsnnsnsnnnnbnnnn",
  EF = "nnssnnnsnnnnsnnn",
  CS = "b",
  DE = "sb",
  WP = "",
  BO = "s",
  GR = "bnsn",
  PU = "snnnnn",
}

function M.decode_line(line)
  local parts = {}
  for p in (line .. "\t"):gmatch("([^\t]*)\t") do parts[#parts + 1] = p end
  local tag = parts[1]
  local t = tonumber(parts[2])
  local sig = SIG[tag]
  if not sig or not t then return nil end
  local args = {}
  for i = 1, #sig do
    local raw = parts[i + 2]
    local ty = sig:sub(i, i)
    if ty == "n" then args[i] = tonumber(raw)
    elseif ty == "b" then args[i] = (raw == "T")
    else args[i] = raw end
  end
  return { tag = tag, t = t, args = args, n = #sig }
end

function M.decode_chunks(chunks)
  local events = {}
  for _, chunk in ipairs(chunks or {}) do
    for line in (chunk .. "\n"):gmatch("([^\n]*)\n") do
      if line ~= "" then
        local e = M.decode_line(line)
        if e then events[#events + 1] = e end
      end
    end
  end
  return events
end

function M.fire(H, e)
  local a = e.args
  if e.tag == "CE" then
    H.fire(EVENT_COMBAT_EVENT, unpack(a, 1, e.n))
  elseif e.tag == "EF" then
    H.fire(EVENT_EFFECT_CHANGED, unpack(a, 1, e.n))
  elseif e.tag == "CS" then
    H.combat_state(a[1])
  elseif e.tag == "DE" then
    H.fire(EVENT_UNIT_DEATH_STATE_CHANGED, a[1], a[2])
  elseif e.tag == "WP" then
    H.fire(EVENT_ACTIVE_WEAPON_PAIR_CHANGED)
  elseif e.tag == "PU" then
    H.fire(EVENT_POWER_UPDATE, unpack(a, 1, e.n))
  elseif e.tag == "BO" then
    local list = {}
    for nm in tostring(a[1] or ""):gmatch("([^|]+)") do
      list[#list + 1] = { name = nm, in_combat = true }
    end
    H.set_bosses(list)
  elseif e.tag == "GR" then
    H.state.grouped = a[1] and (a[2] or 0) > 1 or false
    H.state.group_size = a[2] or 1
    H.unit_names = H.unit_names or {}
    local i = 0
    for nm in tostring(a[3] or ""):gmatch("([^|]+)") do
      i = i + 1
      H.unit_names["group" .. i] = nm
    end
    if a[4] and a[4] > 0 then
      H.state.player_group_tag = "group" .. a[4]
    elseif not H.state.grouped then
      H.state.player_group_tag = nil
    end
    H.fire(EVENT_GROUP_UPDATE)
  end
end

return M
