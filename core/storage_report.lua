Vermilion = Vermilion or {}
Vermilion.StorageReport = {}
local M = Vermilion.StorageReport

local FILM_SLOT_BYTES = 1990
local FILM_SAMPLE_BYTES = 17200
local DIAGNOSTICS = { "probe", "trace", "traces", "evidence", "debug" }
local PREFERENCES = { "settings", "graph", "temporal", "assign", "logo", "copybox", "skill_overrides", "skill_basic_ids" }

local function escaped(s)
  local _, n = s:gsub('[\\"\n]', "")
  return n
end

local function size_of(value, depth)
  local t = type(value)
  if t == "string" then return #value + 2 + escaped(value) end
  if t == "number" then return #tostring(value) end
  if t == "boolean" then return value and 4 or 5 end
  if t ~= "table" then return 0 end
  local indent = (depth + 1) * 4
  local total = 2 * depth * 4 + 8
  for k, v in pairs(value) do
    local key = (type(k) == "string") and (#k + 4) or (#tostring(k) + 2)
    total = total + indent + key + 3 + size_of(v, depth + 1) + 4
  end
  return total
end
M.size_of = size_of

local function sum(sv, keys)
  local total = 0
  for i = 1, #keys do
    local v = sv[keys[i]]
    if v ~= nil then total = total + size_of(v, 4) end
  end
  return total
end

function M.report()
  local sv = Vermilion.SavedVars or {}
  local SS = Vermilion.SessionStore
  local TB = Vermilion.TemporalBuffer
  local sessions = (sv.library ~= nil) and size_of(sv.library, 4) or 0
  local diagnostics = sum(sv, DIAGNOSTICS)
  local preferences = sum(sv, PREFERENCES)
  return {
    sessions = sessions,
    session_count = SS.count(),
    session_cap = SS.cap(),
    diagnostics = diagnostics,
    preferences = preferences,
    total = sessions + diagnostics + preferences,
    film = TB.capacity() * FILM_SLOT_BYTES + TB.count() * FILM_SAMPLE_BYTES,
    heap = collectgarbage("count") * 1024,
  }
end

function M.format_bytes(n)
  if n >= 1048576 then return string.format("%.1f MB", n / 1048576) end
  if n >= 1024 then return string.format("%d KB", math.floor(n / 1024 + 0.5)) end
  return string.format("%d B", n)
end
