Vermilion = Vermilion or {}
local Vermilion = Vermilion

Vermilion.Settings = {}
local M = Vermilion.Settings
local Sound = Vermilion.Sound

local api = Vermilion.zenimax.api
local zui = Vermilion.zenimax.ui
local zc  = Vermilion.zenimax.constants
local Scene = Vermilion.zenimax.scene
local GetUIMousePosition = api.GetUIMousePosition
local GetString          = api.GetString
local d                  = d
local WINDOW_MANAGER     = zui.WINDOW_MANAGER
local math_max           = math.max
local math_min           = math.min
local math_floor         = math.floor

local log         = Vermilion.Log.for_module("settings")
local TOP         = zc.TOP
local TOPLEFT     = zc.TOPLEFT
local TOPRIGHT    = zc.TOPRIGHT
local BOTTOM      = zc.BOTTOM
local BOTTOMLEFT  = zc.BOTTOMLEFT
local CT_TEXTURE  = zc.CT_TEXTURE
local GuiRoot     = zc.GuiRoot

local FILL_TEXTURE = "EsoUI/Art/UnitAttributeVisualizer/attributeBar_dynamic_fill.dds"

local SAMPLE_1HZ, SAMPLE_2HZ = 1000, 500
local SAMPLE_DEFAULT = SAMPLE_1HZ

local VPALPHA_DEFAULT = 30
local LIGHTA_DEFAULT = 40

local sliders = {}

local controls           = {}
local current_sample     = SAMPLE_DEFAULT
local current_vpalpha    = VPALPHA_DEFAULT
local current_lighta     = LIGHTA_DEFAULT

local function persist_temporal(key, val)
  local sv = Vermilion.SavedVars
  if sv then sv.temporal = sv.temporal or {} ; sv.temporal[key] = val end
end

local function persist_graph(key, val)
  local sv = Vermilion.SavedVars
  if sv then sv.graph = sv.graph or {} ; sv.graph[key] = val end
end

local function sample_label(ms)
  local hz = math_floor(1000 / ms)
  return string.format(GetString(VERMILION_SETTINGS_SAMPLE), hz, math_floor(Vermilion.Constants.TEMPORAL.CAPACITY / hz / 60))
end

local function refresh_all_sliders()
  sliders.vpalpha.set(current_vpalpha)
  sliders.lighta.set(current_lighta)
end

function M.refresh_unknown_count()
  local SC = Vermilion.SkillColors
  local n = (SC and SC.unknown_count and SC.unknown_count()) or 0
  local text = GetString(VERMILION_SETTINGS_UNKNOWN)
  if n > 0 then text = text .. " (" .. n .. ")" end
  controls.unknown_label:SetText(text)
  if n > 0 then
    controls.unknown_label:SetColor(0.93, 0.76, 0.38, 1)
  else
    controls.unknown_label:SetColor(0.62, 0.62, 0.62, 1)
  end
end

local function dock_window()
  local win = controls.window
  local host = VermilionGraphWindow
  if not host or host:IsHidden() then return end
  local screen_w = GuiRoot:GetWidth()
  local panel_w  = win:GetWidth()
  win:ClearAnchors()
  if host:GetRight() + panel_w + 16 <= screen_w then
    win:SetAnchor(TOPLEFT, host, TOPRIGHT, 8, 0)
  else
    win:SetAnchor(TOPRIGHT, host, TOPLEFT, -8, 0)
  end
end

function M.refresh_dev_button()
  local b = VermilionSettingsPanelDevBtn
  controls.dev_btn = b
  b:SetText("DEV")
  b:SetHidden(not Vermilion.Constants.DEBUG)
end

function M.toggle()
  local win    = controls.window
  local hidden = win:IsHidden()
  if hidden then
    dock_window()
    Scene.show_top_level(win)
    refresh_all_sliders()
    M.refresh_unknown_count()
    M.refresh_dev_button()
    Sound.play("open")
  else
    Scene.hide_top_level(win)
    Vermilion.About.hide()
    Sound.play("close")
  end
end

function M.on_move_stop()
  local sv = Vermilion.SavedVars
  if not sv or not controls.window then return end
  sv.settings = sv.settings or {}
  sv.settings.x = controls.window:GetLeft()
  sv.settings.y = controls.window:GetTop()
end

function M.on_unknown_click()
  controls.window:SetHidden(true)
  Vermilion.Assign.show()
end

function M.on_logo_click()
  local now = not Vermilion.Logo.is_enabled()
  Vermilion.Logo.set_enabled(now)
  Sound.play(now and "on" or "off")
  controls.logo_btn:SetText(now and GetString(VERMILION_SETTINGS_LOGO_ON)
                                 or GetString(VERMILION_SETTINGS_LOGO_OFF))
  if not now then d("[Vm] " .. GetString(VERMILION_LOGO_HINT)) end
end

function M.on_sample_click()
  if Vermilion.TemporalBuffer.is_recording() then
    Sound.play("deny")
    return
  end
  current_sample = (current_sample == SAMPLE_1HZ) and SAMPLE_2HZ or SAMPLE_1HZ
  log:info("sample_rate ->", current_sample, "ms")
  persist_temporal("sample_rate_ms", current_sample)
  controls.sample_btn:SetText(sample_label(current_sample))
  Sound.play(current_sample == SAMPLE_2HZ and "on" or "off")
end

local function light_label(on)
  return on and GetString(VERMILION_SETTINGS_LIGHT_ON) or GetString(VERMILION_SETTINGS_LIGHT_OFF)
end

local function kills_label(on)
  return on and GetString(VERMILION_SETTINGS_KILLS_ON) or GetString(VERMILION_SETTINGS_KILLS_OFF)
end

function M.sample_ms() return current_sample end

function M.migrate_recording(temporal, settings)
  temporal.time_window_s = nil
  temporal.film_length_migrated = nil
  settings.profile = nil
  settings.user_profiles = nil
  local ms = temporal.sample_rate_ms
  if ms then temporal.sample_rate_ms = (ms < SAMPLE_1HZ) and SAMPLE_2HZ or SAMPLE_1HZ end
end

function M.kill_markers()
  local sv = Vermilion.SavedVars
  return not (sv and sv.settings and sv.settings.kill_markers == false)
end

function M.on_kills_click()
  local sv = Vermilion.SavedVars
  sv.settings = sv.settings or {}
  local now = not M.kill_markers()
  sv.settings.kill_markers = now
  controls.kills_btn:SetText(kills_label(now))
  Sound.play(now and "on" or "off")
  if Vermilion.Graph and Vermilion.Graph.rerender then Vermilion.Graph.rerender() end
end

local function avg_label(on)
  return on and GetString(VERMILION_SETTINGS_AVG_ON) or GetString(VERMILION_SETTINGS_AVG_OFF)
end

function M.average_line()
  local sv = Vermilion.SavedVars
  return (sv and sv.settings and sv.settings.average_line == true) or false
end

function M.on_avg_click()
  local sv = Vermilion.SavedVars
  sv.settings = sv.settings or {}
  local now = not M.average_line()
  sv.settings.average_line = now
  controls.avg_btn:SetText(avg_label(now))
  Sound.play(now and "on" or "off")
  if Vermilion.Graph and Vermilion.Graph.rerender then Vermilion.Graph.rerender() end
end

function M.on_light_click()
  local sv = Vermilion.SavedVars
  sv.settings = sv.settings or {}
  local now = not (sv.settings.light_mode == true)
  sv.settings.light_mode = now
  Sound.play(now and "on" or "off")
  controls.light_btn:SetText(light_label(now))
  Vermilion.Graph.set_light_enabled(now)
end

local function sounds_on()
  local sv = Vermilion.SavedVars
  return not (sv and sv.settings and sv.settings.sounds == false)
end

local function sounds_label(on)
  return on and GetString(VERMILION_SETTINGS_SOUNDS_ON) or GetString(VERMILION_SETTINGS_SOUNDS_OFF)
end

function M.on_sounds_click()
  local sv = Vermilion.SavedVars
  sv.settings = sv.settings or {}
  local now = not sounds_on()
  sv.settings.sounds = now
  controls.sounds_btn:SetText(sounds_label(now))
  if now then Sound.play("confirm") end
end

function M.on_reset_click()
  log:info("reset to defaults")
  Sound.play("confirm")
  current_sample     = SAMPLE_DEFAULT
  current_vpalpha    = VPALPHA_DEFAULT
  persist_temporal("sample_rate_ms", current_sample)
  persist_graph("viewport_alpha_pct", current_vpalpha)
  Vermilion.Graph.set_viewport_alpha(current_vpalpha / 100)
  controls.sample_btn:SetText(sample_label(current_sample))
  local sv = Vermilion.SavedVars
  if sv and sv.settings then
    Vermilion.AutoRecord.set_mode("off")
    sv.settings.session_autosave = false
    Vermilion.AutoRecord.set_auto_stop(false)
    Vermilion.Graph.refresh_record_button()
    sv.settings.sounds = nil
    controls.sounds_btn:SetText(sounds_label(true))
    sv.settings.light_mode = false
    sv.settings.light_alpha_pct = nil
    controls.light_btn:SetText(light_label(false))
    sv.settings.kill_markers = nil
    controls.kills_btn:SetText(kills_label(true))
    sv.settings.average_line = nil
    controls.avg_btn:SetText(avg_label(false))
    Vermilion.Graph.set_light_enabled(false)
  end
  current_lighta = LIGHTA_DEFAULT
  refresh_all_sliders()
end

function M.snapshot()
  local hz = math_floor(1000 / current_sample)
  local capacity = Vermilion.Constants.TEMPORAL.CAPACITY
  return {
    sample_rate_ms      = current_sample,
    sample_rate_hz      = hz,
    time_window_s       = math_floor(capacity / hz),
    viewport_alpha_pct  = current_vpalpha,
    temporal_capacity   = capacity,
  }
end

function M.report_lines()
  local s = M.snapshot()
  return {
    string.format("[config] graph: sample=%dms (%dHz) keeps=%ds capacity=%d",
      s.sample_rate_ms, s.sample_rate_hz, s.time_window_s, s.temporal_capacity),
    string.format("[config] viewport_alpha=%d%%", s.viewport_alpha_pct),
  }
end

function M.init()
  Vermilion.Skin.panel(VermilionSettingsPanelBg)
  Vermilion.Skin.buttons({
    VermilionSettingsPanelSampleBtn, VermilionSettingsPanelLogoBtn,
    VermilionSettingsPanelSoundsBtn, VermilionSettingsPanelLightBtn, VermilionSettingsPanelKillsBtn,
    VermilionSettingsPanelAvgBtn, VermilionSettingsPanelResetBtn,
  })
  Vermilion.Skin.close(VermilionSettingsPanelCloseBtn)
  local sv = Vermilion.SavedVars
  sv.temporal = sv.temporal or {}
  sv.settings = sv.settings or {}
  sv.graph    = sv.graph    or {}

  M.migrate_recording(sv.temporal, sv.settings)
  current_sample     = sv.temporal.sample_rate_ms or SAMPLE_DEFAULT
  current_vpalpha    = sv.graph.viewport_alpha_pct or VPALPHA_DEFAULT

  Vermilion.TemporalBuffer.init(Vermilion.Constants.TEMPORAL.CAPACITY)

  controls.window         = VermilionSettingsPanel
  controls.window:SetHidden(true)
  Scene.register_top_level(controls.window)
  VermilionSettingsPanelBg:SetCenterColor(1.00, 0.62, 0.58, 1.0)
  VermilionSettingsPanelBg:SetEdgeColor(1.00, 0.45, 0.40, 1.0)
  controls.sample_btn     = VermilionSettingsPanelSampleBtn
  controls.title_vpalpha  = VermilionSettingsPanelVPAlphaTitle
  controls.label_vpalpha  = VermilionSettingsPanelVPAlphaLabel
  controls.track_vpalpha  = VermilionSettingsPanelSliderTrackVPAlpha
  controls.reset_btn      = VermilionSettingsPanelResetBtn
  controls.unknown_btn    = VermilionSettingsPanelUnknownBtn
  controls.unknown_label  = VermilionSettingsPanelUnknownLabel
  controls.logo_btn       = VermilionSettingsPanelLogoBtn
  controls.sounds_btn     = VermilionSettingsPanelSoundsBtn
  controls.light_btn      = VermilionSettingsPanelLightBtn
  controls.kills_btn      = VermilionSettingsPanelKillsBtn
  controls.avg_btn        = VermilionSettingsPanelAvgBtn
  controls.title_lighta   = VermilionSettingsPanelLightAlphaTitle
  controls.label_lighta   = VermilionSettingsPanelLightAlphaLabel
  controls.track_lighta   = VermilionSettingsPanelSliderTrackLightAlpha

  VermilionSettingsPanelVersionLabel:SetText("v" .. Vermilion.Constants.VERSION .. (Vermilion.Constants.DEBUG and ("  " .. GetString(VERMILION_DEBUG_TAG)) or ""))
  VermilionSettingsPanelVersionLabel:SetColor(0.55, 0.46, 0.45, 0.9)
  M.refresh_dev_button()
  controls.reset_btn:SetText(GetString(VERMILION_SETTINGS_RESET))
  controls.sample_btn:SetText(sample_label(current_sample))
  M.refresh_unknown_count()

  local SEC = {
    { VermilionSettingsPanelSecGraph,     VermilionSettingsPanelSepGraph,     VERMILION_SETTINGS_SEC_GRAPH },
    { VermilionSettingsPanelSecGeneral,   VermilionSettingsPanelSepGeneral,   VERMILION_SETTINGS_SEC_GENERAL },
  }
  for _, sec in ipairs(SEC) do
    sec[1]:SetText(GetString(sec[3]))
    sec[1]:SetColor(0.95, 0.42, 0.34, 0.90)
    sec[2]:SetTexture(FILL_TEXTURE)
    sec[2]:SetTextureCoords(0, 1, 0, 0.05)
    sec[2]:SetColor(0.95, 0.42, 0.34, 0.22)
  end
  VermilionSettingsPanelSepColumns:SetTexture(FILL_TEXTURE)
  VermilionSettingsPanelSepColumns:SetTextureCoords(0, 0.05, 0, 1)
  VermilionSettingsPanelSepColumns:SetColor(0.95, 0.42, 0.34, 0.12)

  controls.logo_btn:SetText(Vermilion.Logo.is_enabled()
    and GetString(VERMILION_SETTINGS_LOGO_ON) or GetString(VERMILION_SETTINGS_LOGO_OFF))
  controls.sounds_btn:SetText(sounds_label(sounds_on()))
  controls.light_btn:SetText(light_label(sv.settings.light_mode == true))
  controls.kills_btn:SetText(kills_label(M.kill_markers()))
  controls.avg_btn:SetText(avg_label(M.average_line()))
  current_lighta = sv.settings.light_alpha_pct or LIGHTA_DEFAULT

  for _, k in ipairs({ "vpalpha", "lighta" }) do
    controls["title_" .. k]:SetColor(0.75, 0.75, 0.75, 1)
    controls["label_" .. k]:SetColor(0.95, 0.80, 0.20, 1)
  end
  controls.title_vpalpha:SetText(GetString(VERMILION_SETTING_VIEWPORT_ALPHA))
  controls.title_lighta:SetText(GetString(VERMILION_SETTING_LIGHT_ALPHA))

  local Slider = Vermilion.Slider
  sliders.vpalpha = Slider.new({
    name = "VermilionSettingsVPAlpha", track = controls.track_vpalpha, label = controls.label_vpalpha,
    min = 0, max = 100, value = current_vpalpha,
    on_change = function(v)
      current_vpalpha = v
      persist_graph("viewport_alpha_pct", v)
      Vermilion.Graph.set_viewport_alpha(v / 100)
    end,
  })
  sliders.lighta = Slider.new({
    name = "VermilionSettingsLightA", track = controls.track_lighta, label = controls.label_lighta,
    min = 10, max = 90, value = current_lighta,
    on_change = function(v)
      current_lighta = v
      local s = Vermilion.SavedVars
      s.settings = s.settings or {}
      s.settings.light_alpha_pct = v
      Vermilion.Graph.set_light_alpha(v / 100)
    end,
  })

  if sv.settings.x and sv.settings.y then
    controls.window:ClearAnchors()
    controls.window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.settings.x, sv.settings.y)
  else
    controls.window:ClearAnchors()
    controls.window:SetAnchor(zc.CENTER, GuiRoot, zc.CENTER, 0, 0)
  end

  for _, line in ipairs(M.report_lines()) do log:info(line) end
end
