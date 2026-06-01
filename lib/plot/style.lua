-- lib/plot/style.lua
--
-- Centralized style constants shared across plot composers. Per
--: skill-specific colors stay in core/skill_colors.lua
-- (domain), only generic plot styling lives here (library).
--
-- Composers may override individual values via their `opts` table at
-- construction; these are sensible defaults.

Vermilion = Vermilion or {}
Vermilion.lib = Vermilion.lib or {}
Vermilion.lib.plot = Vermilion.lib.plot or {}

local M = {}
Vermilion.lib.plot.Style = M

-- ── grid / axis ──────────────────────────────────────────────────────────
M.GRID_COLOR        = { 0.35, 0.35, 0.35, 0.40 }
M.AXIS_TEXT_COLOR   = { 0.70, 0.70, 0.70, 0.90 }
M.AXIS_TEXT_FONT    = "ZoFontGameSmall"

-- ── line rendering ───────────────────────────────────────────────────────
M.DEFAULT_LINE_WIDTH       = 2

-- The "skip_below_px" optimization: when a slot's pixel width drops
-- below this threshold, individual line segments are skipped (only
-- fills are drawn). This is a meaningful FPS win at high temporal
-- buffer capacities; documented in
M.DEFAULT_SKIP_BELOW_PX    = 3

-- ── strip / fill default textures ────────────────────────────────────────
M.WHITE_PIXEL_TEXTURE = "EsoUI/Art/Miscellaneous/listItem_backdrop.dds"
