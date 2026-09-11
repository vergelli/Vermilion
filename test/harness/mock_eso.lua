unpack = unpack or table.unpack

HARNESS = { chat = {}, state = { grouped = false, group_size = 1, mouse_x = 400, mouse_y = 300, world = "NA Megaserver", in_combat = false, bosses = {} } }
local H = HARNESS

local T = 0

function d(msg) H.chat[#H.chat + 1] = tostring(msg) end

EVENT_ADD_ON_LOADED            = 1
EVENT_COMBAT_EVENT             = 2
EVENT_EFFECT_CHANGED           = 3
EVENT_GROUP_MEMBER_JOINED      = 4
EVENT_GROUP_MEMBER_LEFT        = 5
EVENT_GROUP_UPDATE             = 6
EVENT_PLAYER_ACTIVATED         = 7
EVENT_PLAYER_DEACTIVATED       = 8
EVENT_PLAYER_COMBAT_STATE      = 9
EVENT_ACTION_SLOT_ABILITY_USED = 10
EVENT_BOSSES_CHANGED           = 11
EVENT_UNIT_DEATH_STATE_CHANGED = 12
EVENT_ACTIVE_WEAPON_PAIR_CHANGED = 13
EVENT_POWER_UPDATE               = 14
POWERTYPE_HEALTH                 = 32
COMBAT_MECHANIC_FLAGS_ULTIMATE   = 10
ACTION_BAR_ULTIMATE_SLOT_INDEX   = 7
REGISTER_FILTER_POWER_TYPE       = 107
NUMBER_ABBREVIATION_PRECISION_TENTHS = 1

REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE = 101
REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE = 102
REGISTER_FILTER_COMBAT_RESULT           = 103
REGISTER_FILTER_IS_ERROR                = 104
REGISTER_FILTER_UNIT_TAG                = 105
REGISTER_FILTER_UNIT_TAG_PREFIX         = 106

DAMAGE_TYPE_NONE = 0 DAMAGE_TYPE_GENERIC = 1 DAMAGE_TYPE_PHYSICAL = 2 DAMAGE_TYPE_FIRE = 3 DAMAGE_TYPE_SHOCK = 4
DAMAGE_TYPE_OBLIVION = 5 DAMAGE_TYPE_COLD = 6 DAMAGE_TYPE_EARTH = 7 DAMAGE_TYPE_MAGIC = 8 DAMAGE_TYPE_DROWN = 9
DAMAGE_TYPE_DISEASE = 10 DAMAGE_TYPE_POISON = 11 DAMAGE_TYPE_BLEED = 12
COMBAT_UNIT_TYPE_PLAYER     = 1
COMBAT_UNIT_TYPE_PLAYER_PET = 2
COMBAT_UNIT_TYPE_GROUP      = 3
COMBAT_UNIT_TYPE_OTHER      = 5

ACTION_RESULT_HEAL              = 16
ACTION_RESULT_HOT_TICK          = 1073741840
ACTION_RESULT_CRITICAL_HEAL     = 32
ACTION_RESULT_HOT_TICK_CRITICAL = 1073741856
ACTION_RESULT_HEAL_ABSORBED     = 3470
ACTION_RESULT_DAMAGE            = 1
ACTION_RESULT_DOT_TICK          = 1073741825
ACTION_RESULT_CRITICAL_DAMAGE   = 2
ACTION_RESULT_DOT_TICK_CRITICAL = 1073741826
ACTION_RESULT_BLOCKED_DAMAGE    = 2151
ACTION_RESULT_FALL_DAMAGE       = 2420
ACTION_RESULT_DAMAGE_SHIELDED   = 2460
ACTION_RESULT_KILLING_BLOW      = 2262

EFFECT_RESULT_GAINED       = 1
EFFECT_RESULT_FADED        = 2
EFFECT_RESULT_UPDATED      = 3
EFFECT_RESULT_FULL_REFRESH = 4
EFFECT_RESULT_TRANSFER     = 5

BOSS_RANK_ITERATION_BEGIN = 1
BOSS_RANK_ITERATION_END   = 7

HOTBAR_CATEGORY_PRIMARY = 0
HOTBAR_CATEGORY_BACKUP  = 1

BUFF_EFFECT_TYPE_BUFF   = 1
BUFF_EFFECT_TYPE_DEBUFF = 2
ABILITY_TYPE_HEAL       = 2

TOPLEFT = 41 TOP = 42 TOPRIGHT = 43 LEFT = 44 CENTER = 45 RIGHT = 46
BOTTOMLEFT = 47 BOTTOM = 48 BOTTOMRIGHT = 49
CT_CONTROL = 51 CT_LABEL = 52 CT_TEXTURE = 53 CT_BACKDROP = 54 CT_COOLDOWN = 55 CT_BUTTON = 56
TEXT_WRAP_MODE_ELLIPSIS = 2 TEXT_WRAP_MODE_TRUNCATE = 1
CD_TYPE_RADIAL = 1 CD_TYPE_VERTICAL = 2
CD_TIME_TYPE_TIME_UNTIL = 0 CD_TIME_TYPE_TIME_REMAINING = 1
TEXT_ALIGN_LEFT = 61 TEXT_ALIGN_CENTER = 62 TEXT_ALIGN_RIGHT = 63
KEY_DELETE = 118 KEY_UPARROW = 119 KEY_DOWNARROW = 120 KEY_ENTER = 121 KEY_ESCAPE = 122
MOUSE_BUTTON_INDEX_LEFT = 1 MOUSE_BUTTON_INDEX_RIGHT = 2
TEXT_ALIGN_TOP = 64 TEXT_ALIGN_BOTTOM = 65
SCENE_SHOWN = "shown" SCENE_HIDDEN = "hidden"
SOUNDS = setmetatable({}, { __index = function(_, k) return "sound:" .. tostring(k) end })
ZO_COMBOBOX_SUPPRESS_UPDATE = true
SLASH_COMMANDS = {}

H.controls = {}

local FRACX = {
  [TOPLEFT] = 0, [TOP] = 0.5, [TOPRIGHT] = 1,
  [LEFT] = 0, [CENTER] = 0.5, [RIGHT] = 1,
  [BOTTOMLEFT] = 0, [BOTTOM] = 0.5, [BOTTOMRIGHT] = 1,
}
local FRACY = {
  [TOPLEFT] = 0, [TOP] = 0, [TOPRIGHT] = 0,
  [LEFT] = 0.5, [CENTER] = 0.5, [RIGHT] = 0.5,
  [BOTTOMLEFT] = 1, [BOTTOM] = 1, [BOTTOMRIGHT] = 1,
}

local resolving = {}
local function layout(c)
  if c == nil or c == true or c == GuiRoot then return 0, 0, 1920, 1080 end
  if resolving[c] then return 100, 100, c._w or 600, c._h or 400 end
  resolving[c] = true
  local x, y, w, h
  if c._fill then
    local base = (c._fill == true) and (c._parent or GuiRoot) or c._fill
    x, y, w, h = layout(base)
  elseif c._anchor_list and #c._anchor_list > 0 then
    local xs, ys = {}, {}
    for _, a in ipairs(c._anchor_list) do
      local rx, ry, rw, rh = layout(a.relTo or c._parent or GuiRoot)
      xs[#xs + 1] = { f = FRACX[a.point] or 0, p = rx + (FRACX[a.relPoint] or 0) * rw + (a.ox or 0) }
      ys[#ys + 1] = { f = FRACY[a.point] or 0, p = ry + (FRACY[a.relPoint] or 0) * rh + (a.oy or 0) }
    end
    local function solve(cons, dim, def)
      if #cons >= 2 and cons[1].f ~= cons[2].f then
        local d = (cons[2].p - cons[1].p) / (cons[2].f - cons[1].f)
        if d < 0 then d = 0 end
        return cons[1].p - cons[1].f * d, d
      end
      local d = dim or def
      return cons[1].p - cons[1].f * d, d
    end
    x, w = solve(xs, c._w, 600)
    y, h = solve(ys, c._h, 400)
  else
    if c._parent then
      x, y = layout(c._parent)
    else
      x, y = 100, 100
    end
    w, h = c._w or 600, c._h or 400
  end
  resolving[c] = nil
  return x, y, w, h
end

function H.layout(c)
  local x, y, w, h = layout(c)
  return { x = x, y = y, w = w, h = h }
end

local mock_control
H.xml_tags = {}
local XML_CONTAINERS = { TopLevelControl = true, Control = true, Label = true, Texture = true,
                         Backdrop = true, Button = true, Line = true, EditBox = true, Slider = true, StatusBar = true }
function H.tag_xml(path)
  local f = io.open(path, "r")
  if not f then return end
  local xml = f:read("*a")
  f:close()
  xml = xml:gsub("<!%-%-.-%-%->", "")
  local stack = {}
  for tag in xml:gmatch("<[^>]+>") do
    local closing = tag:match("^</%s*([%w_]+)")
    local self_closing = tag:match("/%s*>$") ~= nil
    local name = tag:match("^<%s*([%w_]+)")
    if closing then
      if XML_CONTAINERS[closing] and stack[#stack] and stack[#stack].tag == closing then stack[#stack] = nil end
    elseif XML_CONTAINERS[name] then
      local parent = stack[#stack]
      local attr_name = tag:match('name%s*=%s*"([^"]*)"')
      local virtual = tag:match('virtual%s*=%s*"true"') ~= nil
      local full = parent and parent.full or ""
      if attr_name and not virtual then
        full = attr_name:gsub("%$%(parent%)", parent and parent.full or "")
        H.xml_tags[full] = name
      end
      if not self_closing then stack[#stack + 1] = { tag = name, full = full } end
    end
  end
end

local DENY = {
  Button          = { SetColor = true, SetTextureCoords = true, SetTexture = true, SetFont = true },
  Texture         = { SetText = true, SetFont = true },
  Control         = { SetColor = true, SetText = true, SetTexture = true, SetTextureCoords = true, SetFont = true },
  TopLevelControl = { SetColor = true, SetText = true, SetTexture = true, SetTextureCoords = true, SetFont = true },
  Backdrop        = { SetColor = true, SetText = true, SetTexture = true, SetTextureCoords = true },
  Label           = { SetTexture = true, SetTextureCoords = true },
}
local CT_TAG = { [CT_CONTROL] = "Control", [CT_LABEL] = "Label", [CT_TEXTURE] = "Texture",
                 [CT_BACKDROP] = "Backdrop", [CT_BUTTON] = "Button" }

local MOCKC = {
  __index = function(self, k)
    local tag = rawget(self, "_xml_tag") or CT_TAG[rawget(self, "_ctype")]
    if tag and DENY[tag] and DENY[tag][k] then
      error(string.format("%s has no method %s on a %s control in ESO", tostring(rawget(self, "_name")), k, tag), 2)
    end
    if type(k) ~= "string" or k:find("^[A-Z]") ~= 1 then return nil end
    local fn
    if k == "SetAnchor" then
      fn = function(s, point, relTo, relPoint, ox, oy)
        s._anchors = (s._anchors or 0) + 1
        if s._anchors > 2 then error("too many anchors on a control (ESO max is 2)") end
        s._anchor_list = s._anchor_list or {}
        s._anchor_list[#s._anchor_list + 1] = {
          point = point, relTo = relTo, relPoint = relPoint or point,
          ox = ox or 0, oy = oy or 0,
        }
      end
    elseif k == "SetAnchorFill" then
      fn = function(s, target)
        s._anchors = 2
        s._fill = target or s._parent or true
      end
    elseif k == "ClearAnchors" then
      fn = function(s)
        s._anchors = 0
        s._anchor_list = nil
        s._fill = nil
      end
    elseif k == "SetDimensions" then fn = function(s, w, h) s._w, s._h = w, h end
    elseif k == "SetWidth" then fn = function(s, w) s._w = w end
    elseif k == "SetHeight" then fn = function(s, h) s._h = h end
    elseif k == "SetThickness" then fn = function(s, th) s._h = th end
    elseif k == "GetWidth" then fn = function(s) if s._w then return s._w end local r = H.layout(s) return r.w end
    elseif k == "GetHeight" then fn = function(s) if s._h then return s._h end local r = H.layout(s) return r.h end
    elseif k == "GetDimensions" then fn = function(s) return s:GetWidth(), s:GetHeight() end
    elseif k == "GetTop" then fn = function(s) local r = H.layout(s) return r.y end
    elseif k == "GetBottom" then fn = function(s) local r = H.layout(s) return r.y + r.h end
    elseif k == "GetLeft" then fn = function(s) local r = H.layout(s) return r.x end
    elseif k == "GetRight" then fn = function(s) local r = H.layout(s) return r.x + r.w end
    elseif k == "GetCenter" then fn = function(s) local r = H.layout(s) return r.x + r.w / 2, r.y + r.h / 2 end
    elseif k == "SetText" then fn = function(s, t) s._text = t end
    elseif k == "GetText" then fn = function(s) return s._text or "" end
    elseif k == "GetStringWidth" then
      fn = function(s, text)
        local t = tostring(text or ""):gsub("|c%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|t.-|t", "")
        return #t * 7
      end
    elseif k == "GetTextWidth" then
      fn = function(s)
        local t = tostring(s._text or "")
        t = t:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|t.-|t", "")
        local widest = 0
        for line in (t .. "\n"):gmatch("(.-)\n") do
          if #line > widest then widest = #line end
        end
        return widest * 7
      end
    elseif k == "GetTextHeight" then
      fn = function(s)
        local _, n = tostring(s._text or ""):gsub("\n", "")
        return 14 * (n + 1)
      end
    elseif k == "SetHidden" then fn = function(s, h) s._hidden = h and true or false end
    elseif k == "IsHidden" or k == "IsControlHidden" then fn = function(s) return s._hidden == true end
    elseif k == "SetColor" then fn = function(s, r, g, b, a) s._r, s._g, s._b, s._a = r, g, b, a end
    elseif k == "SetAlpha" then fn = function(s, a) s._alpha = a end
    elseif k == "SetTexture" then fn = function(s, path) s._tex = path end
    elseif k == "HasFocus" then fn = function(s) return s._has_focus == true end
    elseif k == "SetMaxLineCount" then fn = function(s, n) s._max_lines = n end
    elseif k == "StartFixedCooldown" then
      fn = function(s, pct, ctype, ttype, edge)
        s._cd_pct, s._cd_type, s._cd_time_type, s._cd_edge = pct, ctype, ttype, edge
      end
    elseif k == "SetPercentCompleteFixed" then fn = function(s, pct) s._cd_pct = pct end
    elseif k == "ResetCooldown" then fn = function(s) s._cd_pct = 0 end
    elseif k == "SetFillColor" then fn = function(s, r, g, b, a) s._fr, s._fg, s._fb, s._fa = r, g, b, a end
    elseif k == "SetRadialCooldownOriginAngle" then fn = function(s, a) s._cd_origin = a end
    elseif k == "SetRadialCooldownClockwise" then fn = function(s, cw) s._cd_cw = cw end
    elseif k == "GetTextureFileName" then fn = function(s) return s._tex or "" end
    elseif k == "SetDrawLevel" then fn = function(s, lv) s._draw_level = lv end
    elseif k == "SetDrawLayer" then fn = function(s, ly) s._draw_layer = ly end
    elseif k == "SetDrawTier" then fn = function(s, tr) s._draw_tier = tr end
    elseif k == "SetFont" then fn = function(s, f) s._font = f end
    elseif k == "SetCenterColor" then fn = function(s, r, g, b, a) s._cr, s._cg, s._cb, s._ca = r, g, b, a end
    elseif k == "SetEdgeColor" then fn = function(s, r, g, b, a) s._er, s._eg, s._eb, s._ea = r, g, b, a end
    elseif k == "SetHorizontalAlignment" then fn = function(s, a) s._halign = a end
    elseif k == "SetVerticalAlignment" then fn = function(s, a) s._valign = a end
    elseif k == "GetAlpha" then fn = function(s) return s._alpha or 1 end
    elseif k == "SetHandler" then fn = function(s, ev, h) s["_on" .. tostring(ev)] = h end
    elseif k == "GetHandler" then fn = function(s, ev) return s["_on" .. tostring(ev)] end
    elseif k == "GetNamedChild" then
      fn = function(s, suffix)
        s._children = s._children or {}
        if not s._children[suffix] then
          local child = mock_control((s._name or "MockControl") .. suffix)
          child._parent = s
          s._children[suffix] = child
        end
        return s._children[suffix]
      end
    elseif k == "GetName" then fn = function(s) return s._name or "MockControl" end
    elseif k == "SetEnabled" then fn = function(s, e) s._enabled = e and true or false end
    elseif k == "IsTextureLoaded" then fn = function() return true end
    elseif k == "GetScreenRect" then fn = function() return 0, 0, 1920, 1080 end
    elseif k:find("^Is") == 1 or k:find("^Does") == 1 then fn = function() return false end
    elseif k:find("^Get") == 1 then fn = function() return 0 end
    else fn = function() end end
    local raw = fn
    fn = function(...)
      local calls = H.calls
      if calls then calls[k] = (calls[k] or 0) + 1 end
      return raw(...)
    end
    rawset(self, k, fn)
    return fn
  end,
}
mock_control = function(name)
  local c = setmetatable({}, MOCKC)
  c._name = name
  c._xml_tag = name and H.xml_tags[name] or nil
  H.controls[#H.controls + 1] = c
  return c
end
H.mock_control = mock_control

GuiRoot = mock_control("GuiRoot")
GuiRoot.GetDimensions = function() return 1920, 1080 end

setmetatable(_G, {
  __index = function(_, k)
    if type(k) == "string" and k:find("^Vermilion%u") then
      local c = mock_control(k)
      rawset(_G, k, c)
      return c
    end
    return nil
  end,
})

WINDOW_MANAGER = {
  CreateControl = function(_, name, parent, ctype)
    local c = mock_control(name)
    c._parent = parent
    c._ctype = ctype
    if name then rawset(_G, name, c) end
    return c
  end,
  CreateControlFromVirtual = function(_, name, parent, tpl)
    local c = mock_control(name)
    c._parent = parent
    c._tpl = tpl
    if name then rawset(_G, name, c) end
    return c
  end,
  CreateTopLevelWindow = function(_, name)
    local c = mock_control(name)
    c._parent = GuiRoot
    c._toplevel = true
    if name then rawset(_G, name, c) end
    return c
  end,
  GetControlByName = function(_, name) return rawget(_G, name) end,
}
function CreateControlFromVirtual(name, parent, tpl)
  return WINDOW_MANAGER:CreateControlFromVirtual(name, parent, tpl)
end

ZO_ObjectPool = {
  New = function(_, factory, reset)
    local p = { free = {}, active = {}, factory = factory, reset = reset }
    function p:AcquireObject()
      local obj = table.remove(self.free)
      if not obj then obj = self.factory(self) end
      self.active[#self.active + 1] = obj
      return obj, #self.active
    end
    function p:ReleaseAllObjects()
      for i = #self.active, 1, -1 do
        if self.reset then self.reset(self.active[i]) end
        self.free[#self.free + 1] = self.active[i]
        self.active[i] = nil
      end
    end
    function p:GetActiveObjectCount() return #self.active end
    return p
  end,
}

DT_LOW    = 0
DT_MEDIUM = 1
DT_HIGH   = 2
DL_BACKGROUND = 0
DL_CONTROLS   = 1
DL_TEXT       = 2
DL_OVERLAY    = 3
TEX_BLEND_MODE_ADD = 71
ANIMATION_ALPHA = 72
ANIMATION_PLAYBACK_PING_PONG = 73
LOOP_INDEFINITELY = -1

ANIMATION_MANAGER = {
  CreateTimeline = function()
    local anim = {
      SetAlphaValues = function() end,
      SetDuration = function() end,
      SetEasingFunction = function() end,
    }
    return {
      InsertAnimation = function() return anim end,
      SetPlaybackType = function() end,
      PlayFromStart = function() end,
      PlayFromEnd = function() end,
      Stop = function() end,
      IsPlaying = function() return false end,
    }
  end,
}

ZO_AlphaAnimation = {
  New = function(_, control)
    return {
      FadeIn = function()
        control:SetHidden(false)
        control:SetAlpha(1)
      end,
      IsPlaying = function() return false end,
      Stop = function() end,
      FadeOut = function(_, _, _, _, cb)
        if H.state.hold_fade then return end
        control:SetAlpha(0)
        if cb then cb() end
      end,
    }
  end,
}

function ZO_ComboBox_ObjectFromContainer()
  local combo = { items = {} }
  function combo:SetSortsItems() end
  function combo:ClearItems() self.items = {} end
  function combo:CreateItemEntry(label, cb) return { label = label, cb = cb } end
  function combo:AddItem(entry) self.items[#self.items + 1] = entry end
  function combo:UpdateItems() end
  function combo:SetSelectedItemText(t) self.selected = t end
  function combo:SelectByLabel(label)
    for _, e in ipairs(self.items) do
      if e.label == label then e.cb() return true end
    end
    return false
  end
  return combo
end

ZO_SavedVars = {
  NewAccountWide = function(_, tbl, version, profile, defaults)
    local function copy(src)
      local dst = {}
      for k, v in pairs(src) do
        dst[k] = (type(v) == "table") and copy(v) or v
      end
      return dst
    end
    H.saved_vars = copy(defaults or {})
    return H.saved_vars
  end,
}

SCENE_MANAGER = {
  callbacks = {},
  top_levels = {},
  RegisterCallback = function(self, name, cb)
    self.callbacks[name] = self.callbacks[name] or {}
    local list = self.callbacks[name]
    list[#list + 1] = cb
  end,
  UnregisterCallback = function() end,
  RegisterTopLevel = function(self, c) self.top_levels[c] = true end,
  ShowTopLevel = function(self, c)
    if self.top_levels[c] then c:SetHidden(false); H.ui_mode = true end
  end,
  HideTopLevel = function(self, c)
    if self.top_levels[c] and not c._hidden then
      c:SetHidden(true)
      if c._onOnEffectivelyHidden then c._onOnEffectivelyHidden(c) end
    end
  end,
  HideTopLevels = function(self)
    for c in pairs(self.top_levels) do self:HideTopLevel(c) end
  end,
}
function H.escape() SCENE_MANAGER:HideTopLevels() end

function ZO_CreateStringId(id, str) rawset(_G, id, str) end
function ZO_Tooltips_ShowTextTooltip(control, side, text)
  H.last_tooltip = text
end
function ZO_Tooltips_HideTextTooltip()
  H.last_tooltip = nil
end
function GetString(s) return s or "" end
function ZO_AbbreviateAndLocalizeNumber(n) return tostring(math.floor(n or 0)) end
function ZO_CommaDelimitNumber(n) return tostring(n) end
function PlaySound(id)
  H.sounds = H.sounds or {}
  H.sounds[#H.sounds + 1] = id
end
function zo_callLater(fn) fn() end

function GetGameTimeMilliseconds() return T end
function GetAPIVersion() return 101050 end
function GetWorldName() return H.state.world end
function GetUIMousePosition() return H.state.mouse_x, H.state.mouse_y end
function MouseIsOver(c)
  local mx, my = H.state.mouse_x, H.state.mouse_y
  if not mx or not my then return false end
  local r = H.layout(c)
  return mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h
end
function IsUnitGrouped() return H.state.grouped end
function GetGroupSize() return H.state.group_size end
function GetUnitName(tag)
  if H.unit_names and H.unit_names[tag] then return H.unit_names[tag] end
  if H.state.bosses[tag] then return H.state.bosses[tag].name end
  if type(tag) == "string" and tag:find("^group") then return "" end
  return "Velladocuments"
end
function GetUnitDisplayName() return "@vergelli" end
function GetUnitClass() return "Templar" end
function GetUnitRace() return "Breton" end
function GetUnitLevel() return 50 end
function GetUnitChampionPoints() return 1200 end
function GetUnitAlliance() return 1 end
function GetCurrentMapZoneIndex() return 1 end
function GetZoneNameByIndex() return "Mock Zone" end
function GetSlotName() return "" end
function GetSlotBoundId(slot, cat)
  local bars = H.slotted
  if not bars then return 0 end
  if cat == nil then cat = H.state.active_bar or HOTBAR_CATEGORY_PRIMARY end
  local bar = bars[cat]
  return (bar and bar[slot]) or 0
end
function GetSlotAbilityCost(slot, mechanic, cat)
  local per_bar = H.state.ult_costs
  if per_bar and cat ~= nil and per_bar[cat] then return per_bar[cat] end
  return H.state.ult_cost or 250
end
DUNGEON_DIFFICULTY_NONE = 0 DUNGEON_DIFFICULTY_NORMAL = 1 DUNGEON_DIFFICULTY_VETERAN = 2
function GetUIGlobalScale() return H.state.ui_scale or 1 end
function GetCurrentZoneDungeonDifficulty() return H.state.difficulty or 0 end
MAP_CONTENT_NONE = 0 MAP_CONTENT_DUNGEON = 1 MAP_CONTENT_AVA = 2 MAP_CONTENT_BATTLEGROUND = 3
function GetMapContentType() return H.state.map_content or MAP_CONTENT_NONE end
function IsActiveWorldBattleground() return H.state.in_bg == true end
function GetCurrentBattlegroundId() return H.state.bg_id or 0 end
function GetBattlegroundTeamSize(id) return H.state.bg_team_size or 8 end
function IsPlayerInRaid() return H.state.in_raid == true end
function IsPlayerInEndlessDungeon() return H.state.in_archive == true end
function IsInCyrodiil() return H.state.in_cyrodiil == true end
function IsInImperialCity() return H.state.in_ic == true end
function GetCurrentZoneHouseId() return H.state.house_id or 0 end
function GetZoneId(idx) return H.state.zone_id or 0 end
function GetUnitZoneIndex(tag) return 1 end
function GetDateStringFromTimestamp(ts) return "2026-09-03" end
function GetActiveHotbarCategory()
  return H.state.active_bar or HOTBAR_CATEGORY_PRIMARY
end
function GetUnitPower(tag, ptype)
  if ptype == COMBAT_MECHANIC_FLAGS_ULTIMATE then
    return H.state.ult_value or 0, 500, 500
  end
  return 0, 100, 100
end
function GetAbilityName(id) return (H.ability_names and H.ability_names[id]) or ("Ability" .. tostring(id)) end
function GetAbilityIcon(id)
  return (H.ability_icons and H.ability_icons[id]) or "EsoUI/Art/Icons/ability_mock.dds"
end
function IsAbilityPassive(id)
  return (H.passive_ids and H.passive_ids[id]) == true
end
function GetAbilityDescription(id, rank, caster)
  if caster == "player" then
    local dc = H.ability_descs_caster and H.ability_descs_caster[id]
    if dc then return dc end
  end
  return (H.ability_descs and H.ability_descs[id]) or ""
end
function GetNumBuffs(tag)
  local l = H.unit_buffs and H.unit_buffs[tag]
  return l and #l or 0
end
function GetUnitBuffInfo(tag, i)
  local b = H.unit_buffs[tag][i]
  return "MockBuff", 0, 0, b.slot, 1, "icon.dds", 0, 0, 0, 0, b.id, false, true
end
function GetAbilityEffectDescription(slot)
  return (H.slot_descs and H.slot_descs[slot]) or ""
end
function GetSpecificSkillAbilityKeysByAbilityId(id)
  local k = H.skill_keys and H.skill_keys[id]
  if k then return k[1], k[2], k[3] end
  return 0, 0, 0
end
function GetSkillLineId() return 0 end
function DoesUnitExist(tag) return H.state.bosses[tag] ~= nil end
function IsUnitInCombat(tag)
  if tag == "player" then return H.state.in_combat end
  local b = H.state.bosses[tag]
  return b ~= nil and b.in_combat ~= false
end
function IsUnitDead(tag)
  local b = H.state.bosses[tag]
  return b ~= nil and b.dead == true
end
function ReloadUI() H.reloads = (H.reloads or 0) + 1 end
function GetUnitZone(tag)
  return H.state.zone or "Mock Zone"
end
function GetTimeStamp()
  return 1755900000
end
function GetLatency()
  return H.state.latency or 66
end
function GetUnitClassId(tag)
  return (H.unit_classes and H.unit_classes[tag]) or 6
end
function ZO_GetClassIcon(id)
  return "EsoUI/Art/Icons/mapKey/mapKey_class_" .. tostring(id) .. ".dds"
end
function AreUnitsEqual(a, b)
  if a == b then return true end
  local pg = H.state.player_group_tag
  if pg and ((a == "player" and b == pg) or (b == "player" and a == pg)) then
    return true
  end
  return false
end

local handlers = {}
local updates = {}

local FILTER_POS = {
  [EVENT_COMBAT_EVENT] = {
    [REGISTER_FILTER_COMBAT_RESULT]           = 1,
    [REGISTER_FILTER_IS_ERROR]                = 2,
    [REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE] = 7,
    [REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE] = 9,
  },
  [EVENT_EFFECT_CHANGED] = {
    [REGISTER_FILTER_UNIT_TAG]                = 4,
    [REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE] = 16,
  },
  [EVENT_UNIT_DEATH_STATE_CHANGED] = {
    [REGISTER_FILTER_UNIT_TAG]        = 1,
    [REGISTER_FILTER_UNIT_TAG_PREFIX] = { pos = 1, mode = "prefix" },
  },
  [EVENT_POWER_UPDATE] = {
    [REGISTER_FILTER_POWER_TYPE]      = 3,
    [REGISTER_FILTER_UNIT_TAG]        = 1,
    [REGISTER_FILTER_UNIT_TAG_PREFIX] = { pos = 1, mode = "prefix" },
  },
}

EVENT_MANAGER = {
  RegisterForEvent = function(_, name, code, fn)
    handlers[code] = handlers[code] or {}
    handlers[code][name] = { fn = fn, filters = {} }
    return true
  end,
  UnregisterForEvent = function(_, name, code)
    if handlers[code] then handlers[code][name] = nil end
    return true
  end,
  AddFilterForEvent = function(_, name, code, ftype, value)
    local reg = handlers[code] and handlers[code][name]
    if reg then reg.filters[#reg.filters + 1] = { ftype, value } end
    return true
  end,
  RegisterForUpdate = function(_, name, ms, fn)
    local interval = (ms and ms > 0) and ms or 16
    updates[name] = { fn = fn, interval = interval, due = T + interval }
    return true
  end,
  UnregisterForUpdate = function(_, name)
    updates[name] = nil
    return true
  end,
}

function H.fire(code, ...)
  local regs = handlers[code]
  if not regs then return 0 end
  local args = { ... }
  local nargs = select("#", ...)
  local pos_map = FILTER_POS[code]
  local fired = 0
  local snapshot = {}
  for name, reg in pairs(regs) do snapshot[name] = reg end
  for _, reg in pairs(snapshot) do
    local pass = true
    if pos_map then
      for _, f in ipairs(reg.filters) do
        local spec = pos_map[f[1]]
        if type(spec) == "table" then
          local v = args[spec.pos]
          if spec.mode == "prefix" then
            if type(v) ~= "string" or v:sub(1, #f[2]) ~= f[2] then pass = false break end
          elseif v ~= f[2] then pass = false break end
        elseif spec and args[spec] ~= f[2] then pass = false break end
      end
    end
    if pass then
      reg.fn(code, unpack(args, 1, nargs))
      fired = fired + 1
    end
  end
  return fired
end

function H.now() return T end

function H.advance(ms)
  local target = T + ms
  while true do
    local best_name, best_due
    for name, u in pairs(updates) do
      if u.due <= target and (best_due == nil or u.due < best_due) then
        best_name, best_due = name, u.due
      end
    end
    if not best_name then break end
    T = best_due
    local u = updates[best_name]
    u.due = u.due + u.interval
    u.fn()
  end
  T = target
end

function H.update_registered(name) return updates[name] ~= nil end

function H.addon_alloc(fn)
  local by_fn = {}
  local stack = {}
  local last = collectgarbage("count")
  local function key(info)
    local src = info.short_src or "?"
    if src:find("mock_eso") or src:find("loader") or src:find("/test/") or src:find("harness") then
      return "harness"
    end
    return src .. ":" .. tostring(info.linedefined or 0)
  end
  local keys = {}
  local function hook(ev)
    local now = collectgarbage("count")
    local top
    for i = #stack, 1, -1 do
      if stack[i] then top = stack[i] break end
    end
    if top then by_fn[top] = (by_fn[top] or 0) + (now - last) end
    if ev == "call" or ev == "tail call" then
      local info = debug.getinfo(2, "Sf")
      local k = false
      if info.what ~= "C" then
        k = keys[info.func]
        if not k then k = key(info); keys[info.func] = k end
      end
      if ev == "tail call" then stack[#stack] = k else stack[#stack + 1] = k end
    else
      stack[#stack] = nil
    end
    last = collectgarbage("count")
  end
  local cg = collectgarbage
  cg("collect")
  cg("stop")
  collectgarbage = function(opt, ...)
    if opt == "step" or opt == "collect" or opt == "restart" then return false end
    return cg(opt, ...)
  end
  last = cg("count")
  debug.sethook(hook, "cr")
  fn()
  debug.sethook()
  collectgarbage = cg
  cg("restart")
  local total = 0
  by_fn.harness = nil
  for k, v in pairs(by_fn) do
    if v > 0 then total = total + v end
  end
  return total * 1024, by_fn
end

local next_unit_id = 1000

function H.heal(opts)
  opts = opts or {}
  local result = opts.result or ACTION_RESULT_HEAL
  return H.fire(EVENT_COMBAT_EVENT,
    result, false, "MockHeal", 0, 0,
    "Me", opts.source_type or COMBAT_UNIT_TYPE_PLAYER,
    opts.target_name or "Ally", opts.target_type or COMBAT_UNIT_TYPE_GROUP,
    opts.hit or 1000, 0, 0, false,
    opts.source_unit_id or 500, opts.target_unit_id or 600,
    opts.ability_id or 77, opts.overflow or 0)
end

function H.shield(opts)
  opts = opts or {}
  return H.fire(EVENT_COMBAT_EVENT,
    ACTION_RESULT_DAMAGE_SHIELDED, false, "MockShield", 0, 0,
    "Enemy", opts.source_type or COMBAT_UNIT_TYPE_OTHER,
    "Ally", opts.target_type or COMBAT_UNIT_TYPE_GROUP,
    opts.hit or 800, 0, 0, false,
    opts.source_unit_id or 900, opts.target_unit_id or 600,
    opts.ability_id or 88, 0)
end

function H.damage(opts)
  opts = opts or {}
  return H.fire(EVENT_COMBAT_EVENT,
    opts.result or ACTION_RESULT_DAMAGE, false, "MockDamage", 0, 0,
    "Enemy", opts.source_type or COMBAT_UNIT_TYPE_OTHER,
    "Ally", opts.target_type or COMBAT_UNIT_TYPE_GROUP,
    opts.hit or 2000, 0, 0, false,
    opts.source_unit_id or 900, opts.target_unit_id or 600,
    opts.ability_id or 0, 0)
end

function H.effect(change_type, ability_id, unit_id, end_time_s, source_type, unit_tag, effect_type, ability_type)
  if unit_tag == nil then unit_tag = "group1" end
  if effect_type == nil then effect_type = BUFF_EFFECT_TYPE_BUFF end
  return H.fire(EVENT_EFFECT_CHANGED,
    change_type, 1, "MockEffect", unit_tag, 0, end_time_s or 0,
    1, "icon.dds", 0, effect_type, ability_type or 0, 0,
    "Ally", unit_id, ability_id,
    source_type or COMBAT_UNIT_TYPE_PLAYER)
end

function H.death(is_dead, tag)
  return H.fire(EVENT_UNIT_DEATH_STATE_CHANGED, tag or "player", is_dead and true or false)
end

function H.power(tag, value, max)
  return H.fire(EVENT_POWER_UPDATE, tag, 0, POWERTYPE_HEALTH, value, max, max)
end

function H.ult_power(value)
  return H.fire(EVENT_POWER_UPDATE, "player", 0, COMBAT_MECHANIC_FLAGS_ULTIMATE, value, 500, 500)
end

function H.ult_used()
  return H.fire(EVENT_ACTION_SLOT_ABILITY_USED, ACTION_BAR_ULTIMATE_SLOT_INDEX + 1)
end

function H.combat_state(in_combat)
  H.state.in_combat = in_combat
  return H.fire(EVENT_PLAYER_COMBAT_STATE, in_combat)
end

function H.set_bosses(list)
  H.state.bosses = {}
  for i, b in ipairs(list or {}) do
    H.state.bosses["boss" .. i] = b
  end
  return H.fire(EVENT_BOSSES_CHANGED, false)
end

function H.scene(name, state)
  local list = SCENE_MANAGER.callbacks["SceneStateChanged"] or {}
  local scene = { GetName = function() return name end }
  for _, cb in ipairs(list) do cb(scene, nil, state or SCENE_SHOWN) end
end

function H.new_unit_id()
  next_unit_id = next_unit_id + 1
  return next_unit_id
end

function H.chat_contains(pattern)
  for _, line in ipairs(H.chat) do
    if line:find(pattern) then return line end
  end
  return nil
end

function H.clear_chat() H.chat = {} end

function H.damage_out(opts)
  opts = opts or {}
  return H.fire(EVENT_COMBAT_EVENT,
    opts.result or ACTION_RESULT_DAMAGE, false, "MockStrike", 0, 0,
    "Me", COMBAT_UNIT_TYPE_PLAYER,
    opts.target_name or "Enemy", opts.target_type or COMBAT_UNIT_TYPE_OTHER,
    opts.hit or 1500, 0, opts.damage_type or DAMAGE_TYPE_PHYSICAL, false,
    opts.source_unit_id or 500, opts.target_unit_id or 900,
    opts.ability_id or 31, 0)
end

function H.kill(opts)
  opts = opts or {}
  return H.fire(EVENT_COMBAT_EVENT,
    ACTION_RESULT_KILLING_BLOW, false, "MockStrike", 0, 0,
    "Me", COMBAT_UNIT_TYPE_PLAYER,
    opts.target_name or "Enemy", opts.target_type or COMBAT_UNIT_TYPE_OTHER,
    opts.hit or 0, 0, opts.damage_type or DAMAGE_TYPE_PHYSICAL, false,
    opts.source_unit_id or 500, opts.target_unit_id or 900,
    opts.ability_id or 31, 0)
end

function H.shield_out(opts)
  opts = opts or {}
  return H.fire(EVENT_COMBAT_EVENT,
    ACTION_RESULT_DAMAGE_SHIELDED, false, "MockWard", 0, 0,
    "Me", COMBAT_UNIT_TYPE_PLAYER,
    opts.target_name or "Enemy", opts.target_type or COMBAT_UNIT_TYPE_OTHER,
    opts.hit or 600, 0, 0, false,
    opts.source_unit_id or 500, opts.target_unit_id or 900,
    opts.ability_id or 41, 0)
end
