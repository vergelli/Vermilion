Vermilion = Vermilion or {}
local Vermilion = Vermilion

Vermilion.Metrics = {}

local M = Vermilion.Metrics
local W_MS        = 5000
local W_SHIELD_MS = 30000

local damage_out_buf  -- landed damage (eDPS)
local shield_out_buf  -- enemy-shield-absorbed damage (ShDPS)
local event_pool
local log = Vermilion.Log.for_module("metrics")

local SkillColors

function M.acquire_event()  return event_pool:acquire()   end
function M.release_event(ev) event_pool:release(ev)       end
function M.pool_in_use()    return event_pool:in_use()    end
function M.pool_capacity()  return event_pool:capacity()  end

local function release_to_pool(entry) event_pool:release(entry) end

function M.init()
  local MC = Vermilion.Constants.METRICS or {}
  W_MS        = MC.DAMAGE_WINDOW_MS or 5000
  W_SHIELD_MS = MC.SHIELD_WINDOW_MS or 30000

  local cap  = (Vermilion.Constants.POOL and Vermilion.Constants.POOL.EVENT_CAPACITY) or 4096
  event_pool = Vermilion.lib.mem.BufferPool.new(Vermilion.lib.mem.Event.factory, cap, "event_pool")

  local RingBuffer = Vermilion.lib.mem.RingBuffer
  damage_out_buf = RingBuffer.new(W_MS,        2048, release_to_pool)
  shield_out_buf = RingBuffer.new(W_SHIELD_MS,  512, release_to_pool)

  SkillColors = Vermilion.SkillColors
  log:info("init: dmg_window=", W_MS, "ms shield_window=", W_SHIELD_MS, "ms pool=", cap)
end

function M.set_window(ms)
  W_MS = ms or 5000
  damage_out_buf.window_ms = W_MS
  log:info("dmg window ->", W_MS, "ms")
end

function M.set_shield_window(ms)
  W_SHIELD_MS = ms or 30000
  shield_out_buf.window_ms = W_SHIELD_MS
  log:info("shield window ->", W_SHIELD_MS, "ms")
end

function M.window_seconds() return W_MS / 1000 end

function M.ingest_damage_out(ev)
  if ev.amount > 0 then damage_out_buf:push(ev) else event_pool:release(ev) end
end

function M.ingest_shield_out(ev)
  if ev.amount > 0 then shield_out_buf:push(ev) else event_pool:release(ev) end
end

function M.eDPS(now_ms)  return damage_out_buf:sum(now_ms, "amount") / (W_MS / 1000)        end
function M.ShDPS(now_ms) return shield_out_buf:sum(now_ms, "amount") / (W_SHIELD_MS / 1000) end
function M.EOS(now_ms)   return M.eDPS(now_ms) + M.ShDPS(now_ms)                            end

local function accumulate(now_ms, buckets)
  local ws  = W_MS / 1000
  local wss = W_SHIELD_MS / 1000
  local total = 0

  damage_out_buf:trim(now_ms)
  for i = damage_out_buf.head, damage_out_buf.tail do
    local e   = damage_out_buf.entries[i]
    local amt = e.amount or 0
    if amt > 0 then
      local r = amt / ws
      local g = SkillColors.group_of(e.ability_id)
      buckets[g] = (buckets[g] or 0) + r
      total = total + r
    end
  end

  shield_out_buf:trim(now_ms)
  for i = shield_out_buf.head, shield_out_buf.tail do
    local e   = shield_out_buf.entries[i]
    local amt = e.amount or 0
    if amt > 0 then
      local r = amt / wss
      local g = SkillColors.group_of(e.ability_id)
      buckets[g] = (buckets[g] or 0) + r
      total = total + r
    end
  end

  return total
end

function M.eos_groups(now_ms)
  local buckets = {}
  local total   = accumulate(now_ms, buckets)
  local out     = {}
  if total > 0 then
    for g, val in pairs(buckets) do
      local c = SkillColors.group_color(g)
      out[#out + 1] = { r = c.r, g = c.g, b = c.b, a = c.a, share = val / total }
    end
    table.sort(out, function(a, b) return a.share > b.share end)
  end
  return out
end

function M.eos_groups_into(out, now_ms)
  local buckets = {}
  local total   = accumulate(now_ms, buckets)
  local n = 0
  if total > 0 then
    for g, val in pairs(buckets) do
      n = n + 1
      local slot = out[n]
      if not slot then slot = {}; out[n] = slot end
      local c = SkillColors.group_color(g)
      slot.r = c.r; slot.g = c.g; slot.b = c.b; slot.a = c.a
      slot.share = val / total
    end

    for i = 2, n do
      local key = out[i]
      local j = i - 1
      while j >= 1 and out[j].share < key.share do
        out[j + 1] = out[j]
        j = j - 1
      end
      out[j + 1] = key
    end
  end
  out.count = n
  return n
end

function M.reset()
  log:info("reset: damage=", damage_out_buf:size(), "shield=", shield_out_buf:size(),
           "pool_in_use=", event_pool:in_use())
  damage_out_buf:reset()
  shield_out_buf:reset()
end

function M.size_snapshot()
  return {
    damage = damage_out_buf:size(),
    shield = shield_out_buf:size(),
  }
end
