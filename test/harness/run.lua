HARNESS_ROOT  = arg[1] or "."
HARNESS_DEBUG = (arg[2] ~= "0")

dofile(HARNESS_ROOT .. "/test/harness/mock_eso.lua")
dofile(HARNESS_ROOT .. "/test/harness/loader.lua")

HARNESS.fire(EVENT_ADD_ON_LOADED, "Vermilion")

local CASES = {
  "boot",
  "record_flow",
  "views",
  "zero_alloc",
  "silence",
  "trace_flow",
  "vsf_codec",
  "session_store",
  "content_kind",
  "auto_record",
  "auto_stop",
  "manual_save",
  "library_flow",
  "session_nav",
  "button_manners",
  "settings_panel",
  "user_profiles",
  "pixel_grid",
  "grow_to_fill",
  "view_tabs",
  "light_mode",
  "report_card",
  "polish",
  "contrib_view",
  "scroll_views",
  "debuff_tracker",
  "debuffs_view",
  "shield_pairing",
  "shield_strip",
  "ultimate_band",
  "targets_view",
  "kills",
  "self_damage",
  "assign_flyout",
  "basic_attacks",
}

local passed, failed = 0, 0
for _, name in ipairs(CASES) do
  local case = dofile(HARNESS_ROOT .. "/test/harness/cases/" .. name .. ".lua")
  local ok, err = pcall(case, HARNESS)
  if ok then
    passed = passed + 1
    print(string.format("PASS  %s", name))
  else
    failed = failed + 1
    print(string.format("FAIL  %s\n      %s", name, tostring(err)))
  end
end

print(string.format("== %d passed, %d failed (DEBUG=%s) ==",
  passed, failed, tostring(HARNESS_DEBUG)))
os.exit(failed == 0 and 0 or 1)
