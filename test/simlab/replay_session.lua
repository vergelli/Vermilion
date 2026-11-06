SIMLAB_ROOT = arg[1] or "."
HARNESS_ROOT = SIMLAB_ROOT
HARNESS_DEBUG = false
local trace_path, out_path, channel_arg = arg[2], arg[3], arg[4]
if not trace_path or not out_path then
  print("usage: lua test/simlab/replay_session.lua <root> <trace.lua> <out.tsv> [id=ms,id=ms]")
  os.exit(2)
end

dofile(SIMLAB_ROOT .. "/test/harness/mock_eso.lua")
local codec = dofile(SIMLAB_ROOT .. "/test/simlab/tracecodec.lua")

local f = assert(io.open(trace_path, "rb"))
local src = f:read("*a")
f:close()
local env = {}
local chunk = setfenv and setfenv(assert(loadstring(src)), env) or assert(load(src, "sv", "t", env))
chunk()
local trace
local function find_trace(t, depth)
  if type(t) ~= "table" or depth > 8 or trace then return end
  if type(t.trace) == "table" and t.trace.chunks then trace = t.trace return end
  if type(t.traces) == "table" and t.traces[#t.traces] then trace = t.traces[#t.traces] return end
  for _, v in pairs(t) do find_trace(v, depth + 1) end
end
find_trace(env.VermilionSavedVars, 0)
assert(trace, "no trace in " .. trace_path)
local events = codec.decode_chunks(trace.chunks)

local CHANNEL = {}
for id, ms in (channel_arg or ""):gmatch("(%d+)=(%d+)") do CHANNEL[tonumber(id)] = tonumber(ms) end

local real_name = {}
for _, e in ipairs(events) do
  if e.tag == "CE" and e.args[16] and e.args[3] ~= "" then real_name[e.args[16]] = e.args[3] end
  if e.tag == "EF" and e.args[15] and e.args[3] ~= "" then real_name[e.args[15]] = e.args[3] end
end
local mock_name = GetAbilityName
GetAbilityName = function(id) return real_name[id] or mock_name(id) end

dofile(SIMLAB_ROOT .. "/test/harness/loader.lua")
HARNESS.fire(EVENT_ADD_ON_LOADED, "Vermilion")
local H = HARNESS

local c = trace.constants or {}
local POWER = {}
if c.COMBAT_MECHANIC_FLAGS_MAGICKA then POWER[c.COMBAT_MECHANIC_FLAGS_MAGICKA] = POWERTYPE_MAGICKA end
if c.COMBAT_MECHANIC_FLAGS_STAMINA then POWER[c.COMBAT_MECHANIC_FLAGS_STAMINA] = POWERTYPE_STAMINA end
if c.COMBAT_MECHANIC_FLAGS_ULTIMATE then POWER[c.COMBAT_MECHANIC_FLAGS_ULTIMATE] = COMBAT_MECHANIC_FLAGS_ULTIMATE end

local rate = tonumber(os.getenv("VERMILION_REPLAY_RATE") or "") or (trace.settings and trace.settings.sample_rate_ms)
if rate then
  Vermilion.SavedVars.temporal = Vermilion.SavedVars.temporal or {}
  Vermilion.SavedVars.temporal.sample_rate_ms = rate
end

H.slotted = { [HOTBAR_CATEGORY_PRIMARY] = {}, [HOTBAR_CATEGORY_BACKUP] = {} }
for _, e in ipairs(events) do
  if e.tag == "SU" and e.args[1] >= 3 and e.args[1] <= 8 and (e.args[2] or 0) > 0 then
    local slot, id = e.args[1], e.args[2]
    local front, back = H.slotted[HOTBAR_CATEGORY_PRIMARY], H.slotted[HOTBAR_CATEGORY_BACKUP]
    if not front[slot] then front[slot] = id
    elseif front[slot] ~= id and not back[slot] then back[slot] = id end
  elseif e.tag == "UC" then
    H.slotted[HOTBAR_CATEGORY_PRIMARY][8] = e.args[1]
    H.slotted[HOTBAR_CATEGORY_BACKUP][8] = e.args[3]
    H.state.ult_costs = { [HOTBAR_CATEGORY_PRIMARY] = e.args[2], [HOTBAR_CATEGORY_BACKUP] = e.args[4] }
    break
  end
end
local player_dead = false
IsUnitDead = function(tag) return tag == "player" and player_dead end
Vermilion.zenimax.api.IsUnitDead = IsUnitDead

local G = Vermilion.Graph
Vermilion.Visibility.set("graph", true)
if events[1].t > H.now() then H.advance(events[1].t - H.now()) end
G.on_record_click()

local hits = { start = events[1].t }
local ult_costs = {}
local ULT_SLOT = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1

for _, e in ipairs(events) do
  if e.t > H.now() then H.advance(e.t - H.now()) end
  local a = e.args
  if e.tag == "DE" and a[1] == "player" then player_dead = a[2] == true end
  if e.tag == "SU" then
    player_dead = false
    if a[1] == ULT_SLOT then
      H.fire(EVENT_ACTION_SLOT_ABILITY_USED, a[1])
      if (a[4] or 0) > 0 then ult_costs[a[4]] = true end
    elseif (a[4] or 0) > 0 and (a[3] == 1 or a[3] == 2) then
      Vermilion.Casts.stage(a[2], a[3], a[4], e.t, a[5] or CHANNEL[a[2]])
    end
  elseif e.tag == "PU" then
    local p = POWER[a[3]]
    if p then H.fire(EVENT_POWER_UPDATE, a[1], a[2], p, a[4], a[5], a[6]) end
  else
    if e.tag == "CE" and not a[2] and (a[7] == COMBAT_UNIT_TYPE_PLAYER or a[7] == COMBAT_UNIT_TYPE_PLAYER_PET) and (a[10] or 0) > 0 then
      hits[#hits + 1] = { e.t, a[16] or 0, a[10], a[1] }
    end
    codec.fire(H, e)
  end
end
G.on_stop_click()

local dump = dofile(SIMLAB_ROOT .. "/test/simlab/dump_lib.lua")
local sess = Vermilion.SessionStore.capture()
G.on_flush_click()
assert(G.load_session(sess))
dump(out_path, sess, hits)
local sv_out = os.getenv("VERMILION_REPLAY_SV")
if sv_out then
  local function ser(w, v)
    local kind = type(v)
    if kind == "table" then
      w:write("{")
      for k, x in pairs(v) do
        w:write("[")
        ser(w, k)
        w:write("]=")
        ser(w, x)
        w:write(",")
      end
      w:write("}")
    elseif kind == "string" then
      w:write(string.format("%q", v))
    elseif kind == "number" then
      w:write(string.format("%.17g", v))
    else
      w:write(tostring(v))
    end
  end
  sess.head.ts = "@TS@"
  local w = assert(io.open(sv_out, "wb"))
  w:write("VermilionSavedVars=")
  ser(w, { library = { sessions = { sess } } })
  w:close()
end
os.exit(0)
