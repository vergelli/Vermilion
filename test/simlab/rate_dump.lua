SIMLAB_ROOT   = arg[1] or "."
HARNESS_ROOT  = SIMLAB_ROOT
HARNESS_DEBUG = false
local sv_path, rate, out_path = arg[2], tonumber(arg[3]), arg[4]

dofile(SIMLAB_ROOT .. "/test/harness/mock_eso.lua")
dofile(SIMLAB_ROOT .. "/test/harness/loader.lua")
HARNESS.fire(EVENT_ADD_ON_LOADED, "Vermilion")
local H = HARNESS
local codec = dofile(SIMLAB_ROOT .. "/test/simlab/tracecodec.lua")
dofile(sv_path)
local trace
local function find_trace(t, depth)
  if type(t) ~= "table" or depth > 8 or trace then return end
  if type(t.trace) == "table" and t.trace.chunks then trace = t.trace return end
  for _, v in pairs(t) do if type(v) == "table" then find_trace(v, depth + 1) end end
end
find_trace(VermilionSavedVars, 0)
local events = codec.decode_chunks(trace.chunks)
local sv = Vermilion.SavedVars
sv.temporal = sv.temporal or {}
sv.temporal.time_window_s, sv.temporal.sample_rate_ms = 7200, rate
Vermilion.TemporalBuffer.init(7200 * math.floor(1000 / rate))
Vermilion.Graph.on_record_click()
local offset = events[1].t - H.now()
for _, e in ipairs(events) do
  local target = e.t - offset
  if target > H.now() then H.advance(target - H.now()) end
  codec.fire(H, e)
end
Vermilion.Graph.on_stop_click()
local TB = Vermilion.TemporalBuffer
local f = assert(io.open(out_path, "w"))
for i = 1, TB.count() do
  local s = TB.at(i)
  f:write(string.format("%d %.3f %.3f\n", s.t, s.eDPS, s.ShDPS))
end
f:close()
