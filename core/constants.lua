Vermilion = Vermilion or {}
local Vermilion = Vermilion

Vermilion.Constants = {
  ADDON_NAME    = "Vermilion",
  VERSION       = "0.8.0",
  SLASH_COMMAND = "/vermilion",

  DEBUG         = false,

  SV_TABLE   = "VermilionSavedVars",
  SV_VERSION = 1,

  PROBE = {
    SRC_DAMAGE_OUT      = "Vermilion_DamageOut",
    SRC_SHIELD_OUT      = "Vermilion_ShieldOut",
    SRC_COMBAT_STATE    = "Vermilion_CombatState",
    SRC_CAST            = "Vermilion_Cast",
    SRC_PLAYER          = "Vermilion_PlayerActivated",
    SRC_AUTOSAVE        = "Vermilion_AutoSave",

    BUFFER_LIMIT = 200,

    CHAT_INTERVAL_MS = 250,

    DUMP_HISTORY_LIMIT = 5,

    AUTOSAVE_COOLDOWN_MS = 30000,
  },

  TEMPORAL = {
    UPDATE_NAME          = "VermilionTemporalSample",
    SAMPLE_RATE_DEFAULT  = 1000,   -- ms interval → 1 Hz
    TIME_WINDOW_DEFAULT  = 60,     -- seconds
  },

  METRICS = {
    DAMAGE_WINDOW_MS = 5000,
    SHIELD_WINDOW_MS = 30000,
  },

  POOL = {
    EVENT_CAPACITY = 4096,
  },

  ABILITY_KIND = {
    DAMAGE_OUT = 1,   -- landed on enemy HP (eDPS)
    SHIELD_OUT = 2,   -- absorbed by an enemy damage shield (ShDPS)
  },

  PROFILER_BUDGETS_MS = {
    ["pipeline.combat_event"]             = 5.0,
    ["pipeline.combat_event.acquisition"] = 2.0,
    ["pipeline.combat_event.filter"]      = 2.0,
    ["pipeline.combat_event.processing"]  = 3.0,
    ["pipeline.render_tick"]              = 10.0,
    ["graph.sample_tick"]                 = 15.0,
  },
}
