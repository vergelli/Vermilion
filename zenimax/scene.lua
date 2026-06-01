-- SCENE_MANAGER wrapper. The sketch proposes a higher-level
-- semantic API (on_show / on_hide for named scenes). Vermilion's only consumer
-- (core/visibility.lua) needs the broader signal — every scene state change,
-- because it tracks the HUD <-> non-HUD transition rather than any specific
-- scene's lifecycle. So this wrapper stays close to the ZOS surface and
-- exposes what the consumer actually uses, plus the HUD-scene predicate.

Vermilion = Vermilion or {}
Vermilion.zenimax = Vermilion.zenimax or {}
local Vermilion = Vermilion

Vermilion.zenimax.scene = {}
local M = Vermilion.zenimax.scene

local SCENE_MANAGER = SCENE_MANAGER

-- ── constants ─────────────────────────────────────────────────────────────
M.SCENE_SHOWN  = SCENE_SHOWN
M.SCENE_HIDDEN = SCENE_HIDDEN

-- ── callbacks ─────────────────────────────────────────────────────────────
function M.register_callback(event_name, callback)
  SCENE_MANAGER:RegisterCallback(event_name, callback)
end

function M.unregister_callback(event_name, callback)
  SCENE_MANAGER:UnregisterCallback(event_name, callback)
end

-- ── HUD predicate ─────────────────────────────────────────────────────────
-- The two scene names ESO emits while the player is in gameplay (with or
-- without the chat input overlay active). Any other scene means the player
-- has opened a full-screen UI (inventory, map, journal, etc.).
function M.is_hud_scene(name)
  return name == "hud" or name == "hudui"
end
