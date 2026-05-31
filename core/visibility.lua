Vermilion = Vermilion or {}
Vermilion.Visibility = {}
local M = Vermilion.Visibility

local Scene = Vermilion.zenimax.scene
local SCENE_SHOWN = Scene.SCENE_SHOWN
local log = Vermilion.Log.for_module("visibility")

-- ── state ─────────────────────────────────────────────────────────────────
-- in_hud: true while the gameplay HUD scene (or the chat-overlay HUD scene) is
-- active. Anything else (inventory, map, journal, ...) sets in_hud=false and
-- we hide our window. Vermilion has a single window (the graph), so there is
-- no bar to track (Verdant's second window was dropped).
local in_hud = true

-- User-intent visibility, persisted. Independent from the actual SetHidden
-- state so auto-hiding during a non-HUD scene doesn't erase the preference.
-- Actual visibility = in_hud AND user_visible.graph.
local user_visible = { graph = false }

-- ── apply / persist ───────────────────────────────────────────────────────
local function apply()
  if VermilionGraphWindow then
    VermilionGraphWindow:SetHidden(not (in_hud and user_visible.graph))
  end
  -- Settings panel is transient: hide it whenever leaving HUD.
  if VermilionSettingsPanel and not in_hud then
    VermilionSettingsPanel:SetHidden(true)
  end
  -- The floating logo shows only in the HUD while the window is closed; the
  -- logo module ANDs this with the user's enable preference.
  if Vermilion.Logo then
    Vermilion.Logo.sync(in_hud and not user_visible.graph)
  end
end

local function persist()
  local sv = Vermilion.SavedVars
  if not sv then return end
  sv.graph = sv.graph or {}
  sv.graph.visible = user_visible.graph
end

-- ── public API ────────────────────────────────────────────────────────────
function M.set(key, visible)
  if user_visible[key] == visible then return end
  log:info("set", key, "->", visible and "visible" or "hidden")
  user_visible[key] = visible
  apply()
  persist()
end

function M.get(key) return user_visible[key] or false end

-- Master toggle wired to the keybind: flips the graph window's user-intent
-- visibility.
function M.master_toggle()
  M.set("graph", not user_visible.graph)
end

function M.init()
  local sv = Vermilion.SavedVars
  if sv then
    user_visible.graph = (sv.graph and sv.graph.visible) or false
  end

  Scene.register_callback("SceneStateChanged",
    function(scene, oldState, newState)
      if newState ~= SCENE_SHOWN then return end
      local now = Scene.is_hud_scene(scene:GetName())
      if now == in_hud then return end
      in_hud = now
      apply()
    end)

  apply()
end
