Vermilion = Vermilion or {}
local Vermilion = Vermilion

Vermilion.Constants = {
  ADDON_NAME    = "Vermilion",
  VERSION       = "0.1.0",
  SLASH_COMMAND = "/vermilion",

  -- DEBUG gates developer-only slash subcommands (probe/dump/report/...) and
  -- the observability layers (log/profiler/validation/copybox). Release
  -- builds keep this false so the no-op references are wired in and the cost
  -- of dev instrumentation stays out of the hot path.
  DEBUG         = false,

  SV_TABLE   = "VermilionSavedVars",
  SV_VERSION = 1,

  PROBE = {
    -- Distinct names per registration: EVENT_MANAGER keys filters by (name, eventCode).
    SRC_DAMAGE_OUT      = "Vermilion_DamageOut",     -- landed damage where source=player
    SRC_SHIELD_OUT      = "Vermilion_ShieldOut",     -- DAMAGE_SHIELDED where source=player
    SRC_COMBAT_STATE    = "Vermilion_CombatState",
    SRC_CAST            = "Vermilion_Cast",
    SRC_PLAYER          = "Vermilion_PlayerActivated",
    SRC_AUTOSAVE        = "Vermilion_AutoSave",

    -- Last N events kept per category in the rolling buffer.
    BUFFER_LIMIT = 200,

    -- Min ms between chat lines while logging is ON, to avoid spam in trials.
    CHAT_INTERVAL_MS = 250,

    -- How many full snapshots to keep in SavedVars (rotated, newest at index 1).
    DUMP_HISTORY_LIMIT = 5,

    -- Min ms between auto-saves on combat exit, to avoid disk thrash.
    AUTOSAVE_COOLDOWN_MS = 30000,
  },

  TEMPORAL = {
    UPDATE_NAME          = "VermilionTemporalSample",
    SAMPLE_RATE_DEFAULT  = 1000,   -- ms interval → 1 Hz
    TIME_WINDOW_DEFAULT  = 60,     -- seconds
  },

  -- Rolling-window durations for the rate metrics (core/metrics.lua).
  -- eDPS integrates over 5 s; ShDPS over 30 s because shielded-damage events
  -- are sparse (mostly PvP / specific PvE mechanics) and a wider window keeps
  -- the metric from collapsing to a permanent zero. Mirrors Verdant's
  -- W_MS / W_SHIELD_MS split.
  METRICS = {
    DAMAGE_WINDOW_MS = 5000,
    SHIELD_WINDOW_MS = 30000,
  },

  POOL = {
    -- Worst case for Vermilion is sustained player AoE in a 12-man trial,
    -- potentially a higher event rate than Verdant's heal/shield path.
    -- Inherited at 4096; bump if engine.pool.exhausted trips (SPEC §15.5).
    EVENT_CAPACITY = 4096,
  },

  -- VermilionEvent.kind values. Numeric ints for fast switch dispatch in
  -- pipeline/processing.
  ABILITY_KIND = {
    DAMAGE_OUT = 1,   -- landed on enemy HP (eDPS)
    SHIELD_OUT = 2,   -- absorbed by an enemy damage shield (ShDPS)
  },

  -- Per-stage profiler budgets in ms (SPEC §13). A sample exceeding the
  -- budget emits log.write("warn", "profiler.budget_exceeded", ...).
  PROFILER_BUDGETS_MS = {
    ["pipeline.combat_event"]             = 5.0,
    ["pipeline.combat_event.acquisition"] = 2.0,
    ["pipeline.combat_event.filter"]      = 2.0,
    ["pipeline.combat_event.processing"]  = 3.0,
    ["pipeline.render_tick"]              = 10.0,
    ["graph.sample_tick"]                 = 15.0,
  },
}
