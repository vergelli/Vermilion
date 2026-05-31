Vermilion = Vermilion or {}
Vermilion.Logo = {}
local M = Vermilion.Logo

local api = Vermilion.zenimax.api
local zc  = Vermilion.zenimax.constants
local GetUIMousePosition = api.GetUIMousePosition
local math_abs           = math.abs
local TOPLEFT = zc.TOPLEFT
local CENTER  = zc.CENTER
local GuiRoot = zc.GuiRoot

local log = Vermilion.Log.for_module("logo")

-- Idle = ghosted; hover = full. Drag threshold separates a click from a move.
local IDLE_ALPHA     = 0.40
local HOVER_ALPHA    = 1.00
local DRAG_THRESHOLD = 5   -- px of cursor travel below which an up = click

-- ── state ───────────────────────────────────────────────────────────────────
local controls = {}
local enabled  = true   -- user preference (Settings toggle), persisted
local allowed  = false  -- in_hud AND graph window hidden (pushed by Visibility)
local down_x, down_y = 0, 0

local function refresh()
  controls.window:SetHidden(not (enabled and allowed))
end

-- ── visibility (called by core/visibility.apply) ────────────────────────────
-- is_allowed = in HUD AND the analytics window is closed. The logo only shows
-- when both that and the user's enable preference are true.
function M.sync(is_allowed)
  allowed = is_allowed
  if enabled and allowed then controls.icon:SetAlpha(IDLE_ALPHA) end
  refresh()
end

function M.is_enabled() return enabled end

function M.set_enabled(e)
  enabled = e
  local sv = Vermilion.SavedVars
  if sv then sv.logo = sv.logo or {}; sv.logo.enabled = e end
  log:info("enabled ->", e)
  refresh()
end

-- ── mouse ────────────────────────────────────────────────────────────────────
function M.on_enter() controls.icon:SetAlpha(HOVER_ALPHA) end
function M.on_exit()  controls.icon:SetAlpha(IDLE_ALPHA)  end

function M.on_mouse_down()
  down_x, down_y = GetUIMousePosition()
end

-- A click (not a drag) opens the window. movable="true" already did the moving;
-- here we only decide whether the gesture was a click. Opening flips graph
-- visibility, and Visibility.apply hides the logo via sync().
function M.on_mouse_up(up_inside)
  if not up_inside then return end
  local x, y = GetUIMousePosition()
  if (math_abs(x - down_x) + math_abs(y - down_y)) > DRAG_THRESHOLD then
    return  -- it was a drag, not a click
  end
  Vermilion.Graph.toggle()
end

function M.on_move_stop()
  local sv = Vermilion.SavedVars
  if not sv or not controls.window then return end
  sv.logo = sv.logo or {}
  sv.logo.x = controls.window:GetLeft()
  sv.logo.y = controls.window:GetTop()
end

-- ── init ─────────────────────────────────────────────────────────────────────
function M.init()
  controls.window = VermilionLogo
  controls.icon   = VermilionLogoIcon

  local sv = Vermilion.SavedVars
  sv.logo = sv.logo or {}
  if sv.logo.enabled == nil then sv.logo.enabled = true end
  enabled = sv.logo.enabled

  controls.window:ClearAnchors()
  if sv.logo.x and sv.logo.y then
    controls.window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.logo.x, sv.logo.y)
  else
    controls.window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
  end

  controls.icon:SetAlpha(IDLE_ALPHA)
  controls.window:SetHidden(true)  -- Visibility.apply reveals it if appropriate

  log:info("init: enabled=", enabled)
end
