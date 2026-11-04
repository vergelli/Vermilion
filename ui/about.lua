Vermilion = Vermilion or {}
Vermilion.About = {}
local M = Vermilion.About

local api = Vermilion.zenimax.api
local zui = Vermilion.zenimax.ui
local zc  = Vermilion.zenimax.constants
local Scene = Vermilion.zenimax.scene
local Sound = Vermilion.Sound
local GetString = api.GetString

local AUTHOR = "Federico Vergelli"
local HANDLE = "@vergelli"
local CREDITS = {
  { "Solinur", "LibCombat, combat tracking concepts" },
}

local PAD, W = 14, 312
local C_HEAD = { 0.95, 0.42, 0.34 }

local window
local meters = {}

local function label(name, font, x, y, w, h, r, g, b, align)
  local l = zui.WINDOW_MANAGER:CreateControl(name, window, zc.CT_LABEL)
  l:SetFont(font)
  l:SetAnchor(zc.TOPLEFT, window, zc.TOPLEFT, x, y)
  l:SetDimensions(w, h)
  l:SetColor(r, g, b, 1)
  l:SetHorizontalAlignment(align or zc.TEXT_ALIGN_LEFT)
  l:SetVerticalAlignment(zc.TEXT_ALIGN_CENTER)
  return l
end

local function heading(name, text, y)
  local l = label(name, "ZoFontGameSmall", PAD, y, W, 12, C_HEAD[1], C_HEAD[2], C_HEAD[3])
  l:SetText(text)
  local sep = zui.WINDOW_MANAGER:CreateControl(name .. "Sep", window, zc.CT_TEXTURE)
  sep:SetColor(C_HEAD[1], C_HEAD[2], C_HEAD[3], 0.22)
  sep:SetAnchor(zc.TOPLEFT, window, zc.TOPLEFT, PAD, y + 14)
  sep:SetDimensions(W, 1)
end

local function build()
  local Meter = Vermilion.Meter
  local y = 44
  local name = label("VermilionAboutName", "ZoFontWinH3", PAD, y, W, 26, 0.95, 0.42, 0.34)
  name:SetText("Vermilion  " .. Vermilion.Constants.VERSION)
  y = y + 28
  local by = label("VermilionAboutAuthor", "ZoFontGame", PAD, y, W, 18, 0.92, 0.88, 0.84)
  by:SetText(string.format("%s  %s", AUTHOR, HANDLE))
  y = y + 28
  heading("VermilionAboutCredits", GetString(VERMILION_ABOUT_CREDITS), y)
  y = y + 20
  for i = 1, #CREDITS do
    local who = label("VermilionAboutCredit" .. i, "ZoFontGameSmall", PAD, y, 90, 14, 0.92, 0.88, 0.84)
    who:SetText(CREDITS[i][1])
    local what = label("VermilionAboutCreditFor" .. i, "ZoFontGameSmall", PAD + 90, y, W - 90, 14, 0.62, 0.62, 0.62)
    what:SetText(CREDITS[i][2])
    y = y + 16
  end
  y = y + 10
  heading("VermilionAboutDisk", GetString(VERMILION_ABOUT_DISK), y)
  y = y + 20
  meters.sessions = Meter.new("VermilionAboutSessions", window, PAD, y, W)
  y = y + Meter.HEIGHT
  meters.diagnostics = Meter.new("VermilionAboutDiagnostics", window, PAD, y, W)
  y = y + Meter.HEIGHT
  meters.preferences = Meter.new("VermilionAboutPreferences", window, PAD, y, W)
  y = y + Meter.HEIGHT + 8
  heading("VermilionAboutMemory", GetString(VERMILION_ABOUT_MEMORY), y)
  y = y + 20
  meters.film = Meter.new("VermilionAboutFilm", window, PAD, y, W)
  y = y + Meter.HEIGHT + 6
  window:SetHeight(y)
end

function M.refresh()
  local R = Vermilion.StorageReport
  local r = R.report()
  local fmt = R.format_bytes
  local total = (r.total > 0) and r.total or 1
  meters.sessions.set(GetString(VERMILION_ABOUT_SESSIONS),
    string.format("%s  ·  %d/%d", fmt(r.sessions), r.session_count, r.session_cap), r.sessions / total)
  meters.diagnostics.set(GetString(VERMILION_ABOUT_DIAGNOSTICS), fmt(r.diagnostics), r.diagnostics / total)
  meters.preferences.set(GetString(VERMILION_ABOUT_PREFERENCES), fmt(r.preferences), r.preferences / total)
  local heap = (r.heap > 0) and r.heap or 1
  meters.film.set(GetString(VERMILION_ABOUT_FILM),
    string.format("%s / %s", fmt(r.film), fmt(r.heap)), r.film / heap)
end

function M.show()
  M.refresh()
  Scene.show_top_level(window)
  Sound.play("open")
end

function M.hide()
  if window:IsHidden() then return end
  Sound.play("close")
  Scene.hide_top_level(window)
end

function M.toggle()
  if window:IsHidden() then M.show() else M.hide() end
end

function M.init()
  window = VermilionAbout
  Scene.register_top_level(window)
  window:SetHidden(true)
  Vermilion.Skin.panel(VermilionAboutBg)
  Vermilion.Skin.close(VermilionAboutCloseBtn)
  VermilionAboutWindowTitle:SetText(GetString(VERMILION_ABOUT_TITLE))
  build()
end
