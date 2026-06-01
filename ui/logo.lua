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

-- Base-game animation globals (captured by value, like the zenimax wrappers).
local ANIMATION_MANAGER          = ANIMATION_MANAGER
local ANIMATION_ALPHA            = ANIMATION_ALPHA
local ANIMATION_PLAYBACK_PING_PONG = ANIMATION_PLAYBACK_PING_PONG
local LOOP_INDEFINITELY          = LOOP_INDEFINITELY
local TEX_BLEND_MODE_ADD         = TEX_BLEND_MODE_ADD

local log = Vermilion.Log.for_module("logo")

-- Idle = ghosted; hover = full. Drag threshold separates a click from a move.
local IDLE_ALPHA     = 0.40
local HOVER_ALPHA    = 1.00
local HOVER_SCALE    = 1.06  -- subtle pop on hover
local DRAG_THRESHOLD = 5     -- px of cursor travel below which an up = click
-- Fire-halo pulse (ADD-blended glow), alpha oscillates while hovered.
local GLOW_MIN       = 0.45
local GLOW_MAX       = 1.00
local GLOW_PERIOD_MS = 650

-- ── state ───────────────────────────────────────────────────────────────────
local controls = {}
local enabled  = true   -- user preference (Settings toggle), persisted
local allowed  = false  -- in_hud AND graph window hidden (pushed by Visibility)
local down_x, down_y = 0, 0

-- Clears any hover visuals (glow pulse, scale, alpha). Called when the logo is
-- hidden so it never reappears mid-flicker if the mouse left while it vanished.
local function reset_hover()
  if controls.glow_timeline then controls.glow_timeline:Stop() end
  if controls.glow then controls.glow:SetHidden(true) end
  controls.icon:SetScale(1.0)
  controls.icon:SetAlpha(IDLE_ALPHA)
end

local function refresh()
  local show = enabled and allowed
  controls.window:SetHidden(not show)
  if not show then reset_hover() end
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
function M.on_enter()
  controls.icon:SetAlpha(HOVER_ALPHA)
  controls.icon:SetScale(HOVER_SCALE)
  controls.glow:SetHidden(false)
  controls.glow_timeline:PlayFromStart()
end

function M.on_exit()
  controls.icon:SetAlpha(IDLE_ALPHA)
  controls.icon:SetScale(1.0)
  controls.glow_timeline:Stop()
  controls.glow:SetHidden(true)
end

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
  controls.glow   = VermilionLogoGlow
  controls.glow:SetBlendMode(TEX_BLEND_MODE_ADD)

  -- Flicker pulse: ping-pong the glow's alpha forever; played only while hovered.
  local tl = ANIMATION_MANAGER:CreateTimeline()
  local a  = tl:InsertAnimation(ANIMATION_ALPHA, controls.glow)
  a:SetAlphaValues(GLOW_MIN, GLOW_MAX)
  a:SetDuration(GLOW_PERIOD_MS)
  tl:SetPlaybackType(ANIMATION_PLAYBACK_PING_PONG, LOOP_INDEFINITELY)
  controls.glow_timeline = tl

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
