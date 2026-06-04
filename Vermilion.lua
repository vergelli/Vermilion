Vermilion = Vermilion or {}
local Vermilion = Vermilion

local SLASH_COMMANDS          = SLASH_COMMANDS
local d                       = d
local string_format           = string.format
local string_lower            = string.lower
local string_match            = string.match
local api                     = Vermilion.zenimax.api
local GetString               = api.GetString
local GetWorldName            = api.GetWorldName

local function on_slash(input)
  local DEBUG = Vermilion.Constants.DEBUG
  input = input or ""
  local cmd = string_match(string_lower(input), "^%s*(%S+)") or ""

  -- ── debug commands (developer only) ──────────────────────────────────────
  if DEBUG then
    if cmd == "on" then
      Vermilion.Probe.set_enabled(true)
      d("[Vm] " .. GetString(VERMILION_PROBE_ON))
      return
    elseif cmd == "off" then
      Vermilion.Probe.set_enabled(false)
      d("[Vm] " .. GetString(VERMILION_PROBE_OFF))
      return
    elseif cmd == "dump" then
      -- Raw event log → CopyBox (selectable); `dump chat` keeps the old chat spew.
      local sub = string_match(string_lower(input), "^%s*%S+%s+(%S+)") or ""
      if sub == "chat" then Vermilion.Probe.dump()
      else Vermilion.CopyBox.show("Vermilion Dump", Vermilion.Probe.dump_report()) end
      return
    elseif cmd == "suspects" then
      -- Foreign-source audit → CopyBox (paste back for analysis). DEBUG-only.
      Vermilion.CopyBox.show("Vermilion Source Audit", Vermilion.Probe.suspects_report()) ; return
    elseif cmd == "stats" then
      Vermilion.Probe.print_stats() ; return
    elseif cmd == "report" then
      Vermilion.Diagnostics.full_report() ; return
    elseif cmd == "prof" then
      local sub = string_match(string_lower(input), "^%s*%S+%s+(%S+)") or ""
      if sub == "reset" then Vermilion.Profiler.reset(); d("[prof] reset")
      else Vermilion.Profiler.dump_to_chat() end
      return
    elseif cmd == "log" then
      local sub = string_match(string_lower(input), "^%s*%S+%s+(%S+)") or ""
      if sub == "flush" then
        local n = Vermilion.Log.flush()
        d("[log] flushed " .. tostring(n) .. " records to SavedVars.debug.log")
      elseif sub == "show" then
        Vermilion.Log.show_recent(20)
      elseif sub == "clear" then
        Vermilion.Log.clear(); d("[log] cleared")
      else
        local cur, cap = Vermilion.Log.size()
        d("[log] size " .. cur .. "/" .. cap .. "  (subcmd: flush | show | clear)")
      end
      return
    elseif cmd == "validate" then
      Vermilion.Validation.dump_to_chat() ; return
    elseif cmd == "copy" then
      local sub = string_match(string_lower(input), "^%s*%S+%s+(%S+)") or ""
      if sub == "clear" then Vermilion.CopyBox.clear()
      elseif sub == "hide" then Vermilion.CopyBox.hide()
      else Vermilion.CopyBox.show("Vermilion Copy", "") end
      return
    elseif cmd == "skills" then
      Vermilion.SkillColors.print_unknown() ; return
    elseif cmd == "basic" then
      -- Shortcut for `tag <id> basic` (the common case): mark a grey weapon
      -- attack white and persist it. Survives reloads.
      local id = tonumber(string_match(input, "^%s*%S+%s+(%d+)"))
      if id and id > 0 then
        Vermilion.SkillColors.set_override(id, "basic")
        local sv = Vermilion.SavedVars
        if sv then sv.skill_overrides = sv.skill_overrides or {} ; sv.skill_overrides[id] = "basic" end
        d("[Vm] tagged " .. id .. " -> basic (light/heavy attack)")
      else
        d("[Vm] usage: /vermilion basic <abilityId>")
      end
      return
    elseif cmd == "tag" then
      -- Assign ANY grey ability to ANY colour group, persisted to SavedVars.
      -- Turns colour discovery into a 2-second user action (no code, no reload):
      --   /vermilion skills        -> lists grey abilityIds + names
      --   /vermilion tag 12345 item
      local id    = tonumber(string_match(input, "^%s*%S+%s+(%d+)"))
      local group = string_match(input, "^%s*%S+%s+%d+%s+(%S+)")
      if id and id > 0 and group and Vermilion.SkillColors.set_override(id, group) then
        local sv = Vermilion.SavedVars
        if sv then sv.skill_overrides = sv.skill_overrides or {} ; sv.skill_overrides[id] = group end
        d("[Vm] tagged " .. id .. " -> " .. group)
      else
        d("[Vm] usage: /vermilion tag <abilityId> <group>")
        d("[Vm] groups: " .. table.concat(Vermilion.SkillColors.group_names(), ", "))
      end
      return
    elseif cmd == "clear" then
      Vermilion.Probe.clear()
      Vermilion.Metrics.reset()
      Vermilion.Diagnostics.reset()
      d("[Vm] " .. GetString(VERMILION_BUFFER_CLEARED))
      return
    end
  end

  -- ── window toggle ────────────────────────────────────────────────────────
  if cmd == "graph" then
    Vermilion.Graph.toggle() ; return
  end

  -- ── help ─────────────────────────────────────────────────────────────────
  -- Lists user-facing commands. Dev commands stay hidden in release —
  -- the user never needs to know they exist (mirror of Verdant phase-7 design).
  if cmd == "help" then
    d(GetString(VERMILION_HELP_HEADER))
    d(GetString(VERMILION_HELP_GRAPH))
    d(GetString(VERMILION_HELP_HELP))
    return
  end

  -- ── /vermilion (any input) → toggle the temporal analytics window ─────────
  Vermilion.Graph.toggle()
end

local function on_addon_loaded()
  local C   = Vermilion.Constants
  local Log = Vermilion.Log.for_module("bootstrap")

  -- GetWorldName() separates EU / NA / PTS SavedVars for the same @account.
  local world = GetWorldName()
  Vermilion.SavedVars = Vermilion.zenimax.savedvars.new_account_wide(
    C.SV_TABLE, C.SV_VERSION, world,
    { probe = {}, graph = {}, temporal = {}, copybox = {}, settings = {}, skill_overrides = {}, logo = {} })

  -- Replay user-captured light/heavy attack IDs (via /vermilion basic <id>).
  Vermilion.SkillColors.load_persisted(Vermilion.SavedVars)

  Log:info("savedvars opened: world=", world, "version=", C.SV_VERSION)

  -- Probe is dev-only (used by DEBUG-gated /vermilion on/off/dump/...). It
  -- registers ZOS event handlers that do conditional work per combat event
  -- even when disabled. Skipping init() in release keeps that off the hot path.
  if C.DEBUG then Vermilion.Probe.init() end
  Vermilion.Pipeline.init()
  Vermilion.Logo.init()        -- before Settings (reads Logo.is_enabled) + Visibility (calls Logo.sync)
  Vermilion.Settings.init()
  Vermilion.Graph.init()
  Vermilion.Assign.init()
  Vermilion.Visibility.init()

  SLASH_COMMANDS[C.SLASH_COMMAND] = on_slash

  Log:info("loaded v" .. C.VERSION, "DEBUG=" .. tostring(C.DEBUG))
  d("[Vm] " .. string_format(GetString(VERMILION_LOADED), C.VERSION, C.SLASH_COMMAND))
end

Vermilion.zenimax.events.register_addon_loaded(Vermilion.Constants.ADDON_NAME, on_addon_loaded)
