-- ZOS API surface used by Vermilion. functions are
-- forwarded by value (M.X = X), captured at module load. This is the same
-- call cost as the bare global with the wrapper benefit of a namespace.
-- Consumers may local-cache hot-path entries:
--   local GetGameTimeMs = Vermilion.zenimax.api.GetGameTimeMilliseconds

Vermilion = Vermilion or {}
Vermilion.zenimax = Vermilion.zenimax or {}
local Vermilion = Vermilion

Vermilion.zenimax.api = {}
local M = Vermilion.zenimax.api

-- ── time / version ────────────────────────────────────────────────────────
M.GetGameTimeMilliseconds = GetGameTimeMilliseconds
M.GetAPIVersion           = GetAPIVersion
M.GetWorldName            = GetWorldName

-- ── localization ──────────────────────────────────────────────────────────
M.GetString = GetString

-- ── group / unit ──────────────────────────────────────────────────────────
M.IsUnitGrouped           = IsUnitGrouped
M.GetGroupSize            = GetGroupSize
M.GetUnitName             = GetUnitName
M.GetUnitDisplayName      = GetUnitDisplayName
M.GetUnitClass            = GetUnitClass
M.GetUnitRace             = GetUnitRace
M.GetUnitLevel            = GetUnitLevel
M.GetUnitChampionPoints   = GetUnitChampionPoints
M.GetUnitAlliance         = GetUnitAlliance

-- ── world / zone ──────────────────────────────────────────────────────────
M.GetCurrentMapZoneIndex  = GetCurrentMapZoneIndex
M.GetZoneNameByIndex      = GetZoneNameByIndex

-- ── action bar / abilities ────────────────────────────────────────────────
M.GetSlotName                            = GetSlotName
M.GetSlotBoundId                         = GetSlotBoundId
M.GetAbilityName                         = GetAbilityName
M.GetAbilityIcon                         = GetAbilityIcon
M.GetSpecificSkillAbilityKeysByAbilityId = GetSpecificSkillAbilityKeysByAbilityId
M.GetSkillLineId                         = GetSkillLineId

-- ── input ─────────────────────────────────────────────────────────────────
M.GetUIMousePosition = GetUIMousePosition
