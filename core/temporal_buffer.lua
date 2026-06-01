Vermilion = Vermilion or {}
Vermilion.TemporalBuffer = {}
local M = Vermilion.TemporalBuffer

local math_floor = math.floor
local log        = Vermilion.Log.for_module("temporal_buffer")

-- ── state ─────────────────────────────────────────────────────────────────
local state = {
  data      = {},
  capacity  = 0,
  write     = 1,   -- next slot to overwrite (1-based, wraps)
  count     = 0,   -- active samples (≤ capacity)
  recording = false,
}

-- ── public API ────────────────────────────────────────────────────────────
function M.init(capacity)
  capacity       = math_floor(capacity)
  if capacity < 1 then capacity = 1 end
  state.capacity = capacity
  state.write    = 1
  state.count    = 0
  state.data     = {}
  for i = 1, capacity do
    state.data[i] = { t = 0, eDPS = 0, ShDPS = 0, eos_groups = {} }
  end
  log:info("init: capacity=", capacity)
end


function M.push(timestamp, eDPS, ShDPS, eos_groups)
  local slot       = state.data[state.write]
  slot.t           = timestamp
  slot.eDPS        = eDPS
  slot.ShDPS       = ShDPS
  slot.eos_groups  = eos_groups or {}
  state.write = (state.write % state.capacity) + 1
  if state.count < state.capacity then
    state.count = state.count + 1
  end
end


function M.iterate(fn)
  local n   = state.count
  if n == 0 then return end
  local cap = state.capacity
  local oldest = (n >= cap) and state.write or 1
  for i = 1, n do
    local idx = ((oldest - 1 + i - 1) % cap) + 1
    fn(i, state.data[idx])
  end
end

function M.count()        return state.count     end
function M.capacity()     return state.capacity  end
function M.is_recording() return state.recording end

function M.start_recording()
  state.recording = true
  log:info("start_recording")
end

function M.stop_recording()
  state.recording = false
  log:info("stop_recording: count=", state.count, "/", state.capacity)
end

function M.clear()
  log:info("clear: discarding", state.count, "samples")
  state.write = 1
  state.count = 0
end
