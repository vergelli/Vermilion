-- lib/plot/pool.lua
--
-- Thin wrapper around ZO_ObjectPool specialized for plot controls.
-- Per SPEC_02 §4.2 + §8 open question 1: the codebase already uses
-- ZO_ObjectPool in 3+ places; centralize the construction pattern
-- here so composers don't each reinvent factory + reset closures.

Vermilion = Vermilion or {}
Vermilion.lib = Vermilion.lib or {}
Vermilion.lib.plot = Vermilion.lib.plot or {}

local M = {}
Vermilion.lib.plot.Pool = M

local zui = Vermilion.zenimax.ui
local WINDOW_MANAGER  = zui.WINDOW_MANAGER
local ZO_ObjectPool   = zui.ZO_ObjectPool

local Primitives = Vermilion.lib.plot.Primitives

-- Create a pool of native controls (CT_TEXTURE, CT_LABEL, etc.).
-- name_prefix: counter-suffixed name for each created control.
-- parent:      parent control for new instances.
-- ctype:       CT_TEXTURE, CT_LABEL, ...
-- on_factory(ctrl, counter):  optional; called once at create time
--                              (e.g., set initial texture, font, etc.)
-- on_reset(ctrl):   optional; called on Release. Defaults to
--                   Primitives.clear (clear anchors + hide).
function M.new(name_prefix, parent, ctype, on_factory, on_reset)
  local counter = 0
  return ZO_ObjectPool:New(
    function()
      counter = counter + 1
      local c = WINDOW_MANAGER:CreateControl(name_prefix .. counter, parent, ctype)
      if on_factory then on_factory(c, counter) end
      return c
    end,
    -- ZO_ObjectPool calls the reset function with the object as a SINGLE
    -- argument, not (pool, object). Confirmed by matching the previous
    -- inline make_skill_pool pattern in bar.lua (which used function(t)).
    function(c)
      if on_reset then on_reset(c)
      else Primitives.clear(c) end
    end
  )
end

-- Pool of controls created from a virtual XML template. Same shape as
-- M.new but uses CreateControlFromVirtual instead of CreateControl.
function M.new_virtual(name_prefix, parent, virtual_template, on_factory, on_reset)
  local CreateControlFromVirtual = zui.CreateControlFromVirtual
  local counter = 0
  return ZO_ObjectPool:New(
    function()
      counter = counter + 1
      local c = CreateControlFromVirtual(name_prefix .. counter, parent, virtual_template)
      if on_factory then on_factory(c, counter) end
      return c
    end,
    function(c)
      if on_reset then on_reset(c)
      else Primitives.clear(c) end
    end
  )
end
