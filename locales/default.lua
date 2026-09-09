Vermilion = Vermilion or {}

-- Keybinding label shown in ESO Controls settings
ZO_CreateStringId("SI_BINDING_NAME_VERMILION_TOGGLE", "Toggle Vermilion Window")
ZO_CreateStringId("SI_BINDING_NAME_VERMILION_RECORD", "Start / Stop Recording")
ZO_CreateStringId("SI_BINDING_NAME_VERMILION_SAVE",   "Save Recording to Library")

-- Debug / status strings. I have a copybox for these, but they should be localized anyway.
ZO_CreateStringId("VERMILION_PROBE_ON",       "Probe ON. Logging events to chat (rate-limited).")
ZO_CreateStringId("VERMILION_PROBE_OFF",      "Probe OFF. Buffers keep filling silently.")
ZO_CreateStringId("VERMILION_BUFFER_CLEARED", "Buffers cleared.")
ZO_CreateStringId("VERMILION_LOADED",         "Vermilion v%s loaded. Type %s to toggle.")

-- Settings panel
ZO_CreateStringId("VERMILION_SETTINGS_TITLE",         "Vermilion Settings")
ZO_CreateStringId("VERMILION_SETTINGS_RESET",         "Reset to Defaults")
ZO_CreateStringId("VERMILION_SETTING_SAMPLE_RATE",    "Sampling Rate")
ZO_CreateStringId("VERMILION_SETTING_TIME_WINDOW",    "Time Window")
ZO_CreateStringId("VERMILION_SETTING_VIEWPORT_ALPHA", "Viewport Alpha")
ZO_CreateStringId("VERMILION_SETTING_CRIT_THRESHOLD", "Crit-rate threshold")
ZO_CreateStringId("VERMILION_SETTINGS_UNKNOWN",       "Unknown Contributions")
ZO_CreateStringId("VERMILION_SETTINGS_LOGO_ON",       "Logo: Visible")
ZO_CreateStringId("VERMILION_SETTINGS_LOGO_OFF",      "Logo: Hidden")
ZO_CreateStringId("VERMILION_LOGO_HINT",              "Logo hidden. Bind a key to Vermilion under Settings > Controls > Keybindings (Add-Ons), or type /vermilion.")

-- Unknown-contributions assignment window
ZO_CreateStringId("VERMILION_ASSIGN_TITLE",  "Unknown Contributions")
ZO_CreateStringId("VERMILION_ASSIGN_PICK",   "pick category")
ZO_CreateStringId("VERMILION_ASSIGN_EMPTY",  "Nothing to classify — every contribution has a color.")
ZO_CreateStringId("VERMILION_ASSIGN_DONE",   "Assign")
ZO_CreateStringId("VERMILION_ASSIGN_MORE",   "+ %d more — assign some to reveal the rest")
ZO_CreateStringId("VERMILION_ASSIGN_CONFIRM_TITLE", "Confirm assignment")
ZO_CreateStringId("VERMILION_ASSIGN_CONFIRM_NOTE",  "These assignments are irreversible. Review them before confirming.")
ZO_CreateStringId("VERMILION_ASSIGN_CONFIRM_YES",   "Assign")
ZO_CreateStringId("VERMILION_ASSIGN_CONFIRM_NO",    "Cancel")

-- Heavy buffer warning (in chat) — args: window_s, hz, capacity. This IS important but I'm working on a solution to decimate samples for long windows
-- so I don't want to be too alarmist about it.
ZO_CreateStringId("VERMILION_WARN_HEAVY_BUFFER", "%ds x %d Hz = %d samples may impact FPS. Consider a lower sample rate for long windows.")

-- Help command output. I understand conventions but I will rip these next update
ZO_CreateStringId("VERMILION_HELP_HEADER",  "Vermilion commands:")
ZO_CreateStringId("VERMILION_HELP_GRAPH",   "  /vermilion         toggle the damage analytics window")
ZO_CreateStringId("VERMILION_HELP_HELP",    "  /vermilion help    show this list")

-- Graph window
ZO_CreateStringId("VERMILION_GRAPH_TITLE",   "Damage Analysis")
ZO_CreateStringId("VERMILION_GRAPH_RECORD",  "Record")
ZO_CreateStringId("VERMILION_GRAPH_STOP",    "Stop")
ZO_CreateStringId("VERMILION_GRAPH_FLUSH",   "Flush")
ZO_CreateStringId("VERMILION_GRAPH_NO_DATA", "No data — press Record during combat.")

ZO_CreateStringId("VERMILION_LIB_SAVED",     "Recording saved to the library: %s, %s.")

ZO_CreateStringId("VERMILION_KIND_DUNGEON", "Dungeon")
ZO_CreateStringId("VERMILION_KIND_TRIAL",   "Trial")
ZO_CreateStringId("VERMILION_KIND_ARENA",   "Arena")
ZO_CreateStringId("VERMILION_KIND_ARCHIVE", "Infinite Archive")
ZO_CreateStringId("VERMILION_KIND_BG",      "Battleground")
ZO_CreateStringId("VERMILION_KIND_BGC",     "Competitive Battleground")
ZO_CreateStringId("VERMILION_KIND_AVA",     "Alliance War")
ZO_CreateStringId("VERMILION_KIND_HOUSE",   "Home")
ZO_CreateStringId("VERMILION_KIND_WORLD",   "Overland")

ZO_CreateStringId("VERMILION_SETTINGS_AUTOREC_OFF",    "Auto-record: Off")
ZO_CreateStringId("VERMILION_SETTINGS_AUTOREC_BOSS",   "Auto-record: Boss fights")
ZO_CreateStringId("VERMILION_SETTINGS_AUTOREC_COMBAT", "Auto-record: Any combat")
ZO_CreateStringId("VERMILION_SETTINGS_AUTOSAVE_ON",    "Autosave: On")
ZO_CreateStringId("VERMILION_SETTINGS_AUTOSAVE_OFF",   "Autosave: Off")
ZO_CreateStringId("VERMILION_SETTINGS_AUTOSTOP_ON",    "Auto-stop: On")
ZO_CreateStringId("VERMILION_SETTINGS_AUTOSTOP_OFF",   "Auto-stop: Off")

ZO_CreateStringId("VERMILION_TIP_RECORD",    "Start recording. The graph fills up while you fight.")
ZO_CreateStringId("VERMILION_TIP_STOP",      "Stop recording and freeze the graph for review.")
ZO_CreateStringId("VERMILION_TIP_FLUSH",     "Clear the graph for a new recording.")
ZO_CreateStringId("VERMILION_TIP_SAVE",      "Keep this recording in the library")
ZO_CreateStringId("VERMILION_TIP_PREV_VIEW", "Previous view")
ZO_CreateStringId("VERMILION_TIP_NEXT_VIEW", "Next view")
ZO_CreateStringId("VERMILION_TIP_AUTOREC",   "Let Vermilion start recording on its own: off, boss fights, or any combat")
ZO_CreateStringId("VERMILION_TIP_AUTOSAVE",  "Save every recording into the library when it stops")
ZO_CreateStringId("VERMILION_TIP_AUTOSTOP",  "Stop a recording you started by hand a few seconds after combat ends")

ZO_CreateStringId("VERMILION_SAVE_STATUS",         "SAVED  %s")
ZO_CreateStringId("VERMILION_SAVE_STATUS_UNSAVED", "NOT SAVED")
ZO_CreateStringId("VERMILION_SAVE_BUSY",           "Stop the recording before saving it.")
ZO_CreateStringId("VERMILION_SAVE_NOTHING",        "Nothing to save. Record a fight first.")
ZO_CreateStringId("VERMILION_SAVE_ALREADY",        "This recording is already in the library.")
