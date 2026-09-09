local sv_path, out_dir = arg[1], arg[2]
if not sv_path or not out_dir then
  print("usage: lua qa/ingest_extract.lua <SavedVariables/Vermilion.lua> <traces dir>")
  os.exit(2)
end

dofile(sv_path)
local root = VermilionSavedVars
if not root then
  print("VermilionSavedVars not found in " .. sv_path)
  os.exit(2)
end

local found = {}
local function walk(t, depth)
  if type(t) ~= "table" or depth > 8 then return end
  if type(t.traces) == "table" then
    for _, e in ipairs(t.traces) do
      if type(e) == "table" and e.chunks then found[#found + 1] = e end
    end
  elseif type(t.trace) == "table" and t.trace.chunks then
    found[#found + 1] = t.trace
  end
  for k, v in pairs(t) do
    if k ~= "traces" and k ~= "trace" and type(v) == "table" then walk(v, depth + 1) end
  end
end
walk(root, 0)

local function slug(s)
  s = tostring(s or ""):gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
  if s == "" then s = "unknown" end
  return s:lower()
end

local function serialize(v, indent, out)
  local tv = type(v)
  if tv == "string" then out[#out + 1] = string.format("%q", v)
  elseif tv == "number" or tv == "boolean" then out[#out + 1] = tostring(v)
  elseif tv == "table" then
    out[#out + 1] = "{\n"
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
      local ta, tb = type(a), type(b)
      if ta ~= tb then return ta < tb end
      return a < b
    end)
    for _, k in ipairs(keys) do
      out[#out + 1] = indent .. "  ["
      serialize(k, indent .. "  ", out)
      out[#out + 1] = "] = "
      serialize(v[k], indent .. "  ", out)
      out[#out + 1] = ",\n"
    end
    out[#out + 1] = indent .. "}"
  else
    out[#out + 1] = "nil"
  end
end

local written, skipped = 0, 0
for _, e in ipairs(found) do
  local ts = tonumber(e.ts) or 0
  local stamp = (ts > 0) and os.date("!%Y-%m-%d_%H%M", ts) or "undated"
  local name = string.format("%s_%s_%s_%d_sv.lua", stamp, slug(e.zone), slug(e.world), tonumber(e.count) or 0)
  local path = out_dir .. "/" .. name
  local probe = io.open(path, "r")
  if probe then
    probe:close()
    skipped = skipped + 1
  else
    local out = { "VermilionSavedVars =\n{\n  [\"Default\"] = {\n    [\"@ingest\"] = {\n      [\"$AccountWide\"] = {\n        [\"" .. tostring(e.world or "world") .. "\"] = {\n          [\"trace\"] = " }
    serialize(e, "          ", out)
    out[#out + 1] = ",\n        },\n      },\n    },\n  },\n}\n"
    local f = assert(io.open(path, "w"))
    f:write(table.concat(out))
    f:close()
    written = written + 1
    print("wrote " .. name .. "  (" .. tostring(e.count) .. " events)")
  end
end
print(string.format("ingest: %d staged trace(s), %d new, %d already in the corpus", #found, written, skipped))
