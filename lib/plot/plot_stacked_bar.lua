-- lib/plot/plot_stacked_bar.lua
--
-- Composer for a vertical stacked bar of colored segments. Encapsulates
-- a per-instance ZO_ObjectPool of CT_TEXTURE controls plus the layout
-- math for stacking segments BOTTOMLEFT-up to a target height.
--
-- Replaces the make_skill_pool + render_skill_segments pair previously
-- duplicated 3-4 times in ui/bar.lua. The widget keeps chrome / peak
-- lines / fill backgrounds; this only owns the colored stack.

Vermilion = Vermilion or {}
Vermilion.lib = Vermilion.lib or {}
Vermilion.lib.plot = Vermilion.lib.plot or {}

local M = {}
M.__index = M
Vermilion.lib.plot.StackedBar = M

local Pool = Vermilion.lib.plot.Pool

local zc = Vermilion.zenimax.constants
local CT_TEXTURE = zc.CT_TEXTURE
local BOTTOMLEFT = zc.BOTTOMLEFT

local math_max   = math.max
local math_min   = math.min
local math_floor = math.floor

-- Construct a stacked-bar instance.
--   parent      : control to own the pool's children (typically the area)
--   name_prefix : counter-suffixed name for each pooled texture
--   opts (optional):
--     texture        : "EsoUI/Art/..." dds path. Default: a flat white-ish
--                      texture for solid color bars.
--     texture_coords : {l, r, t, b}. Optional. Use to crop a gradient.
function M.new(parent, name_prefix, opts)
  opts = opts or {}
  local texture = opts.texture
  local tc      = opts.texture_coords  -- {l, r, t, b} or nil

  local self = setmetatable({}, M)
  self._pool = Pool.new(name_prefix, parent, CT_TEXTURE, function(c)
    if texture then c:SetTexture(texture) end
    if tc then c:SetTextureCoords(tc[1], tc[2], tc[3], tc[4]) end
  end)
  return self
end

-- Render `segments` as a vertical stack from `area`'s BOTTOMLEFT.
--   area       : the control segments are anchored against (bar fill area)
--   segments   : array of { r, g, b, a, share } (share sums to 1)
--   area_w     : width of each segment (typically area's width)
--   area_h     : maximum vertical extent the stack can occupy
--   total_frac : 0..1, fraction of area_h the full stack should cover
--
-- Per-segment height = total_h × share, with min 1px so tiny shares stay
-- visible. The pool is fully released before redrawing — this is a
-- repaint, not an incremental update.
function M:render(area, segments, area_w, area_h, total_frac)
  self._pool:ReleaseAllObjects()
  local total_h = (total_frac > 0.005) and math_max(2, area_h * math_min(1, total_frac)) or 0
  local cum_h   = 0
  for i = 1, #segments do
    local seg   = segments[i]
    local seg_h = math_max(1, math_floor(total_h * seg.share + 0.5))
    local t     = self._pool:AcquireObject()
    t:ClearAnchors()
    t:SetAnchor(BOTTOMLEFT, area, BOTTOMLEFT, 0, -cum_h)
    t:SetWidth(area_w)
    t:SetHeight(seg_h)
    t:SetColor(seg.r, seg.g, seg.b, seg.a)
    t:SetHidden(false)
    cum_h = cum_h + seg_h
  end
end

-- Release all pooled segments back. Used when hiding or switching modes.
function M:release()
  self._pool:ReleaseAllObjects()
end
