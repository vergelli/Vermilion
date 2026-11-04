SIMLAB_ROOT = arg[1] or "."
HARNESS_ROOT = SIMLAB_ROOT
HARNESS_DEBUG = false
local sv_path, out_dir, names_path = arg[2], arg[3], arg[4]
if not sv_path or not out_dir then
  print("usage: lua test/simlab/saved_sessions.lua <root> <SavedVariables/Vermilion.lua> <out dir> [names.tsv]")
  os.exit(2)
end

dofile(SIMLAB_ROOT .. "/test/harness/mock_eso.lua")
local real_name = {}
if names_path then
  for line in io.lines(names_path) do
    local id, name = line:match("^(%d+)\t(.*)$")
    if id then real_name[tonumber(id)] = name end
  end
end
local mock_name = GetAbilityName
GetAbilityName = function(id) return real_name[id] or mock_name(id) end

dofile(SIMLAB_ROOT .. "/test/harness/loader.lua")
HARNESS.fire(EVENT_ADD_ON_LOADED, "Vermilion")

local f = assert(io.open(sv_path, "rb"))
local src = f:read("*a")
f:close()
local env = {}
local chunk = setfenv and setfenv(assert(loadstring(src)), env) or assert(load(src, "sv", "t", env))
chunk()

local lib
local function walk(t, depth)
  if lib or depth > 7 then return end
  for k, v in pairs(t) do
    if type(v) == "table" then
      if k == "library" and v.sessions then lib = v return end
      walk(v, depth + 1)
    end
  end
end
walk(env.VermilionSavedVars, 0)
if not lib then
  print("no library in " .. sv_path)
  os.exit(2)
end

local dump = dofile(SIMLAB_ROOT .. "/test/simlab/dump_lib.lua")
Vermilion.Visibility.set("graph", true)
for i, sess in ipairs(lib.sessions) do
  if Vermilion.Graph.load_session(sess) then
    dump(string.format("%s/%03d.tsv", out_dir, i), sess, {})
  end
end
os.exit(0)
