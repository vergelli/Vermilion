Vermilion = Vermilion or {}
Vermilion.Visibility = {}
local M = Vermilion.Visibility

local Scene = Vermilion.zenimax.scene
local SCENE_SHOWN = Scene.SCENE_SHOWN
local log = Vermilion.Log.for_module("visibility")
local in_hud = true
local user_visible = { graph = false }
local restore = {}
local AUX_WINDOWS = { "VermilionSettingsPanel", "VermilionSettingsConfirm", "VermilionLibrary", "VermilionAssignPanel" }

local function apply()
  if VermilionGraphWindow then
    VermilionGraphWindow:SetHidden(not (in_hud and user_visible.graph))
  end
  for _, name in ipairs(AUX_WINDOWS) do
    local win = _G[name]
    if win then
      if in_hud then
        if restore[name] then
          win:SetHidden(false)
          restore[name] = nil
        end
      elseif not win:IsHidden() then
        restore[name] = true
        win:SetHidden(true)
      end
    end
  end
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

function M.set(key, visible)
  if user_visible[key] == visible then return end
  log:info("set", key, "->", visible and "visible" or "hidden")
  user_visible[key] = visible
  apply()
  persist()
end

function M.get(key) return user_visible[key] or false end

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
