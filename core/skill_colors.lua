Vermilion = Vermilion or {}
Vermilion.SkillColors = {}
local M = Vermilion.SkillColors

local api = Vermilion.zenimax.api
local GetAbilityName                          = api.GetAbilityName
local GetAbilityIcon                          = api.GetAbilityIcon
local GetSpecificSkillAbilityKeysByAbilityId  = api.GetSpecificSkillAbilityKeysByAbilityId
local GetSkillLineId                          = api.GetSkillLineId
local string_find                             = string.find

-- One color per class / skill-line. `basic` (white) is the Vermilion addition
-- per SPEC §10.1: weapon light + heavy attacks render as a dedicated white
-- stripe in the skill stack. All other groups carry over from Verdant verbatim
-- (class abilities classify identically regardless of HP-vs-damage role).
local GROUP_COLORS = {
  basic       = { r = 0.95, g = 0.95, b = 0.95, a = 0.90 },  -- white, light/heavy attacks
  templar     = { r = 0.95, g = 0.75, b = 0.15, a = 0.95 },  -- amber gold
  arcanist    = { r = 0.50, g = 1.00, b = 0.00, a = 0.95 },  -- vivid green
  warden      = { r = 0.00, g = 0.75, b = 0.50, a = 0.95 },  -- sky cyan
  resto       = { r = 0.72, g = 0.50, b = 0.18, a = 0.95 },  -- warm brown
  destru      = { r = 0.75, g = 0.90, b = 1.00, a = 0.95 },  -- pale ice
  dk          = { r = 0.88, g = 0.28, b = 0.08, a = 0.95 },  -- rust orange
  sorc        = { r = 0.28, g = 0.38, b = 0.95, a = 0.95 },  -- electric blue
  nb          = { r = 0.82, g = 0.10, b = 0.18, a = 0.95 },  -- crimson
  necro       = { r = 0.65, g = 0.18, b = 0.82, a = 0.95 },  -- violet
  scribing    = { r = 0.20, g = 0.80, b = 1.00, a = 0.95 },  -- arcane blue
  undaunted   = { r = 0.42, g = 0.42, b = 0.18, a = 0.95 },  -- olive
  support     = { r = 0.42, g = 0.31, b = 0.68, a = 0.95 },  -- muted purple
  vampire     = { r = 0.55, g = 0.05, b = 0.10, a = 0.95 },  -- carmesi (blood)
  mages_guild = { r = 0.10, g = 0.45, b = 0.65, a = 0.95 },  -- celeste oscuro
  item        = { r = 0.95, g = 0.20, b = 0.80, a = 0.95 },  -- magenta
  other       = { r = 0.55, g = 0.55, b = 0.55, a = 0.80 },  -- unknown (grey)
}

-- Light/heavy attack classification (SPEC §10.2 / §15.2).
--
-- VALIDATED against esoui/ source: there is NO stable API such as
-- IsLightAttack(abilityId) (approach (a) is unavailable). So classification
-- falls back to approach (c) — a direct abilityId set, checked at the HIGHEST
-- precedence — plus approach (b) icon patterns as a backstop.
--
-- The exact light/heavy attack ability IDs per weapon line must be captured
-- in-game: run `/vermilion skills` after a session that uses light + heavy
-- attacks on every weapon type, then add the reported IDs here. This iterative
-- bootstrap is the process SPEC §10.3 / §14.5 describe. Seeding it empty (vs.
-- guessing numeric IDs) avoids mis-classifying real abilities.
local BASIC_ABILITY_IDS = {
  -- [<lightAttackId>] = true,   -- captured via /vermilion skills
}

-- Icon-path → group lookup. Locale-independent. The two `basic` patterns sit
-- at the TOP so weapon light/heavy attacks match before the weapon-line
-- classifiers (ability_destructionstaff_ etc.). These substrings are unlikely
-- to collide with anything else; if a live LA/HA icon doesn't match, the
-- BASIC_ABILITY_IDS set (above) is the authoritative fallback.
local ICON_PATTERNS = {
  { "_lightattack",              "basic"       },
  { "_heavyattack",              "basic"       },
  { "ability_grimoire_",         "scribing"    },
  { "ability_templar_",          "templar"     },
  { "ability_sorcerer_",         "sorc"        },
  { "ability_arcanist_",         "arcanist"    },
  { "ability_warden_",           "warden"      },
  { "ability_dragonknight_",     "dk"          },
  { "ability_necromancer_",      "necro"       },
  { "ability_nightblade_",       "nb"          },
  { "ability_restorationstaff_", "resto"       },
  { "ability_destructionstaff_", "destru"      },
  { "ability_ava_",              "support"     },
  { "ability_undaunted_",        "undaunted"   },
  { "ability_mageguild_",        "mages_guild" },
  { "ability_u26_vampire_",      "vampire"     },
  { "ability_vampire_",          "vampire"     },
}

-- Skill-line ID → group. Third-tier fallback for cast IDs the icon classifier
-- didn't resolve. Carried over verbatim from Verdant's VerdantSkillDump output;
-- weapon lines (destru/resto) already present, the rest classify damage
-- abilities identically to their heal counterparts.
local SKILL_LINE_TO_GROUP = {
  -- Class lines
  [22]  = "templar",  [27]  = "templar",  [28]  = "templar",
  [35]  = "dk",       [36]  = "dk",       [37]  = "dk",
  [38]  = "nb",       [39]  = "nb",       [40]  = "nb",
  [41]  = "sorc",     [42]  = "sorc",     [43]  = "sorc",
  [127] = "warden",   [128] = "warden",   [129] = "warden",
  [131] = "necro",    [132] = "necro",    [133] = "necro",
  [218] = "arcanist", [219] = "arcanist", [220] = "arcanist",
  -- Vengeance subclass lines (mirror their base class)
  [297] = "dk",       [298] = "dk",       [299] = "dk",
  [300] = "nb",       [301] = "nb",       [302] = "nb",
  [303] = "templar",  [304] = "templar",  [305] = "templar",
  [306] = "sorc",     [307] = "sorc",     [308] = "sorc",
  [309] = "warden",   [310] = "warden",   [311] = "warden",
  [312] = "necro",    [313] = "necro",    [314] = "necro",
  [315] = "arcanist", [316] = "arcanist", [317] = "arcanist",
  -- Weapons
  [33]  = "destru",   [34]  = "resto",
  [323] = "destru",   [324] = "resto",
  -- Guilds
  [44]  = "mages_guild",
  [55]  = "undaunted",
  -- Alliance War
  [48]  = "support",  [67]  = "support",
  [325] = "support",  [326] = "support",
  -- World
  [51]  = "vampire",
}

-- Direct ID → group overrides. Highest precedence after the basic-attack set.
-- Carried over from Verdant; populate over time with damage abilities that
-- fall through icon + skill-tree classification, via /vermilion skills.
local ABILITY_OVERRIDES = {
  [186191] = "arcanist",
  [186243] = "arcanist",
  [186265] = "arcanist",
  [186267] = "arcanist",
  [186203] = "arcanist",
  [61506]  = "support",
  [33524]  = "templar",
  [217608] = "scribing",
  [22228]  = "templar",
  [44013]  = "resto",
  [45518]  = "undaunted",
  [176922] = "item",
  [217469] = "scribing",
  [69773]  = "destru",
  [26824]  = "templar",
  [44391]  = "templar",
  [55677]  = "undaunted",
  [63511]  = "undaunted",
  [184634] = "item",
}

-- Runtime cache (abilityId → group string); populated on first encounter.
local ability_cache = {}

-- IDs that fell through every classifier: { [abilityId] = "name | icon" }.
-- Printed by M.print_unknown() so the user can add an override / extend a
-- pattern / mark it basic.
local unknown_log = {}

local function classify_by_icon(abilityId)
  local icon = GetAbilityIcon(abilityId)
  if not icon or icon == "" then return nil end
  for _, p in ipairs(ICON_PATTERNS) do
    if string_find(icon, p[1], 1, true) then
      return p[2]
    end
  end
  return nil
end

local function classify_by_skill_tree_api(abilityId)
  local skillType, lineIndex = GetSpecificSkillAbilityKeysByAbilityId(abilityId)
  if not skillType or skillType <= 0 then return nil end
  local skillLineId = GetSkillLineId(skillType, lineIndex)
  if not skillLineId then return nil end
  return SKILL_LINE_TO_GROUP[skillLineId]
end

local function lookup_group(abilityId)
  if not abilityId or abilityId <= 0 then return "other" end

  local g = ability_cache[abilityId]
  if g then return g end

  -- 0. Basic (light/heavy) attack — highest precedence (SPEC §10.2 approach c).
  if BASIC_ABILITY_IDS[abilityId] then
    ability_cache[abilityId] = "basic"
    return "basic"
  end

  -- 1. Manual override — items, generic-icon procs, edge cases.
  g = ABILITY_OVERRIDES[abilityId]
  if g then ability_cache[abilityId] = g return g end

  -- 2. Icon-path classifier — locale-independent, the bulk of the work
  --    (also catches LA/HA via the _lightattack / _heavyattack patterns).
  g = classify_by_icon(abilityId)
  if g then ability_cache[abilityId] = g return g end

  -- 3. Skill-tree API — picks up cast IDs the API resolves.
  g = classify_by_skill_tree_api(abilityId)
  if g then ability_cache[abilityId] = g return g end

  -- 4. Give up — record for /vermilion skills.
  local name = GetAbilityName(abilityId) or "?"
  local icon = GetAbilityIcon(abilityId) or "?"
  unknown_log[abilityId] = name .. "  | icon=" .. icon
  ability_cache[abilityId] = "other"
  return "other"
end

-- ── public classification surface (consumed by core/metrics) ───────────────
function M.group_of(abilityId)
  return lookup_group(abilityId)
end

local FALLBACK = GROUP_COLORS.other

function M.group_color(group)
  return GROUP_COLORS[group] or FALLBACK
end

function M.get_color(abilityId)
  return GROUP_COLORS[lookup_group(abilityId)] or FALLBACK
end

-- Manually tag an abilityId as a basic (light/heavy) attack at runtime. Lets
-- the capture workflow promote a discovered LA/HA ID without an addon reload.
function M.mark_basic(abilityId)
  if not abilityId or abilityId <= 0 then return end
  BASIC_ABILITY_IDS[abilityId] = true
  ability_cache[abilityId]     = "basic"
  unknown_log[abilityId]       = nil
end

-- Print all unclassified abilities seen so far. Use /vermilion skills after a
-- session to discover what to add to ABILITY_OVERRIDES / BASIC_ABILITY_IDS.
function M.print_unknown()
  local lines = {}
  local count = 0
  for id, info in pairs(unknown_log) do
    lines[#lines + 1] = string.format("  [%d] = \"?\",  -- %s", id, info)
    count = count + 1
  end
  if count == 0 then
    d("[skill_colors] No unclassified damage abilities seen yet.")
    return
  end
  table.sort(lines)
  local header = "[skill_colors] Unclassified abilities (" .. count .. ") — add to ABILITY_OVERRIDES / BASIC_ABILITY_IDS:"
  if Vermilion.Constants.DEBUG and Vermilion.CopyBox then
    Vermilion.CopyBox.show("Vermilion /skills", header .. "\n" .. table.concat(lines, "\n"))
  else
    d(header)
    for _, line in ipairs(lines) do d(line) end
  end
end

-- Returns a sorted array of { r, g, b, a, share } (largest segment first) for a
-- single buffer. Retained from Verdant; the merged two-buffer breakdown for
-- View 1 lives in core/metrics.eos_groups (SPEC §10.4).
function M.group_shares(buf, now_ms, predicate)
  buf:trim(now_ms)
  local buckets = {}
  local total   = 0
  for i = buf.head, buf.tail do
    local e   = buf.entries[i]
    local amt = e.amount or 0
    if amt > 0 and (not predicate or predicate(e)) then
      local key = lookup_group(e.ability_id)
      buckets[key] = (buckets[key] or 0) + amt
      total = total + amt
    end
  end
  if total <= 0 then return {} end
  local out = {}
  for g, amt in pairs(buckets) do
    local c = GROUP_COLORS[g] or FALLBACK
    out[#out + 1] = { r = c.r, g = c.g, b = c.b, a = c.a, share = amt / total }
  end
  table.sort(out, function(a, b) return a.share > b.share end)
  return out
end
