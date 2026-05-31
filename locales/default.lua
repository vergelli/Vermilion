Vermilion = Vermilion or {}

-- Keybinding label shown in ESO Controls settings
ZO_CreateStringId("SI_BINDING_NAME_VERMILION_TOGGLE", "Toggle Vermilion Window")

-- Debug / status strings
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
ZO_CreateStringId("VERMILION_SETTINGS_UNKNOWN",       "Unknown Contributions")

-- Unknown-contributions assignment window
ZO_CreateStringId("VERMILION_ASSIGN_TITLE",  "Unknown Contributions")
ZO_CreateStringId("VERMILION_ASSIGN_HELP",   "These hits couldn't be auto-colored. Pick a category for each — it saves instantly.")
ZO_CreateStringId("VERMILION_ASSIGN_PICK",   "pick category")
ZO_CreateStringId("VERMILION_ASSIGN_EMPTY",  "Nothing to classify — every contribution has a color.")
ZO_CreateStringId("VERMILION_ASSIGN_DONE",   "Assign")

-- Heavy buffer warning (chat) — args: window_s, hz, capacity
ZO_CreateStringId("VERMILION_WARN_HEAVY_BUFFER", "%ds x %d Hz = %d samples may impact FPS. Consider a lower sample rate for long windows.")

-- Help command output
ZO_CreateStringId("VERMILION_HELP_HEADER",  "Vermilion commands:")
ZO_CreateStringId("VERMILION_HELP_GRAPH",   "  /vermilion         toggle the damage analytics window")
ZO_CreateStringId("VERMILION_HELP_HELP",    "  /vermilion help    show this list")

-- Graph window
ZO_CreateStringId("VERMILION_GRAPH_TITLE",   "Damage Analytics")
ZO_CreateStringId("VERMILION_GRAPH_RECORD",  "Record")
ZO_CreateStringId("VERMILION_GRAPH_STOP",    "Stop")
ZO_CreateStringId("VERMILION_GRAPH_FLUSH",   "Flush")
ZO_CreateStringId("VERMILION_GRAPH_NO_DATA", "No data — press Record during combat.")
