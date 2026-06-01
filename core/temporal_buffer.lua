Vermilion = Vermilion or {}
Vermilion.TemporalBuffer = {}
local M = Vermilion.TemporalBuffer

local math_floor = math.floor
local log        = Vermilion.Log.for_module("temporal_buffer")

-- ── state ─────────────────────────────────────────────────────────────────
-- data: pre-allocated array of { t, eDPS, ShDPS, eos_groups }. Write pointer
-- wraps via modulo. Not persisted — combat data is transient.
local state = {
  data      = {},
  capacity  = 0,
  write     = 1,   -- next slot to overwrite (1-based, wraps)
  count     = 0,   -- active samples (≤ capacity)
  recording = false,
}

-- ── public API ────────────────────────────────────────────────────────────

-- Call once on addon load and again whenever the user changes sample rate or
-- time window. Capacity = time_window_s * sample_hz.
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

-- Record one sample. Overwrites the oldest entry when full.
-- eos_groups is an array of { r, g, b, a, share } from Metrics.eos_groups.
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

-- Iterate samples in chronological order (oldest first).
-- fn(i, sample) where sample = { t, eDPS, ShDPS, eos_groups }.
function M.iterate(fn)
  local n   = state.count
  if n == 0 then return end
  local cap = state.capacity
  -- When full, state.write points at the oldest slot (about to be overwritten).
  -- When not full, writing started at slot 1 so oldest is slot 1.
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

-- Resets write pointer and count without freeing the pre-allocated table.
function M.clear()
  log:info("clear: discarding", state.count, "samples")
  state.write = 1
  state.count = 0
end
