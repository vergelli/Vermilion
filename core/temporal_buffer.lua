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
    state.data[i] = { t = 0, eDPS = 0, ShDPS = 0, crit = 0, noncrit = 0, eos_groups = { count = 0 } }
  end
  log:info("init: capacity=", capacity)
end


-- `src_groups` is a SHARED scratch the caller reuses every sample. We must NOT
-- store the reference (that would alias every slot to the latest sample) — we
-- copy its values into this slot's OWN pre-allocated array, reusing the sub-
-- tables. Sub-tables grow once to the high-water-mark then are reused forever;
-- entries past `count` are left as harmless stale (the render reads `.count`).
function M.push(timestamp, eDPS, ShDPS, crit, noncrit, src_groups)
  local slot   = state.data[state.write]
  slot.t       = timestamp
  slot.eDPS    = eDPS
  slot.ShDPS   = ShDPS
  slot.crit    = crit or 0
  slot.noncrit = noncrit or 0

  local dst = slot.eos_groups
  local n   = (src_groups and (src_groups.count or #src_groups)) or 0
  for i = 1, n do
    local s = src_groups[i]
    local d = dst[i]
    if d == nil then d = {}; dst[i] = d end   -- one-time growth, then reused
    d.r = s.r; d.g = s.g; d.b = s.b; d.a = s.a; d.share = s.share
  end
  dst.count = n

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
