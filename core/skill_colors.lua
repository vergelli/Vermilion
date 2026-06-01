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
-- weapon light + heavy attacks render as a dedicated white
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
  item        = { r = 0.95, g = 0.20, b = 0.80, a = 0.95 },  -- magenta (sets / enchants)
  status      = { r = 0.45, g = 0.62, b = 0.60, a = 0.90 },  -- teal-grey, elemental status-effect damage
  -- Weapon skill lines (damage domain; Verdant only ever saw destru/resto).
  twohanded   = { r = 0.80, g = 0.42, b = 0.28, a = 0.95 },  -- burnt orange
  dualwield   = { r = 0.78, g = 0.55, b = 0.30, a = 0.95 },  -- bronze
  bow         = { r = 0.60, g = 0.80, b = 0.50, a = 0.95 },  -- sage green
  onehand     = { r = 0.70, g = 0.74, b = 0.82, a = 0.95 },  -- steel blue-grey
  -- Guild skill lines.
  fighters_guild = { r = 0.78, g = 0.34, b = 0.30, a = 0.95 },  -- brick red
  soul_magic     = { r = 0.60, g = 0.50, b = 0.72, a = 0.95 },  -- lavender
  other       = { r = 0.55, g = 0.55, b = 0.55, a = 0.80 },  -- unknown (grey)
}

-- Human-readable labels for the assignment UI (ui/assign). Internal group keys
-- are terse; these are what the user actually reads in the category picker.
local GROUP_LABELS = {
  basic          = "Light / Heavy Attack",
  templar        = "Templar",
  dk             = "Dragonknight",
  sorc           = "Sorcerer",
  nb             = "Nightblade",
  warden         = "Warden",
  necro          = "Necromancer",
  arcanist       = "Arcanist",
  twohanded      = "Two Handed",
  dualwield      = "Dual Wield",
  bow            = "Bow",
  onehand        = "One Hand & Shield",
  destru         = "Destruction Staff",
  resto          = "Restoration Staff",
  fighters_guild = "Fighters Guild",
  mages_guild    = "Mages Guild",
  undaunted      = "Undaunted",
  soul_magic     = "Soul Magic",
  support        = "Alliance War",
  scribing       = "Scribing",
  vampire        = "Vampire",
  item           = "Item Set / Enchant",
  status         = "Status Effect",
  other          = "Unknown (grey)",
}

-- Curated display order for the category picker — grouped by domain (basic,
-- class, weapon, guild, world, special) rather than alphabetical, so the list
-- reads the way a player thinks about where a hit came from.
local GROUP_ORDER = {
  "basic",
  "templar", "dk", "sorc", "nb", "warden", "necro", "arcanist",
  "twohanded", "dualwield", "bow", "onehand", "destru", "resto",
  "fighters_guild", "mages_guild", "undaunted", "soul_magic", "support", "scribing",
  "vampire",
  "item", "status",
  "other",
}

-- Light/heavy attack classification.
--
-- VALIDATED against esoui/ source: there is NO stable API such as
-- IsLightAttack(abilityId) (approach (a) is unavailable). So classification
-- falls back to approach (c) — a direct abilityId set, checked at the HIGHEST
-- precedence — plus approach (b) icon patterns as a backstop.
--
-- The exact light/heavy attack ability IDs per weapon line must be captured
-- in-game: run `/vermilion skills` after a session that uses light + heavy
-- attacks on every weapon type, then add the reported IDs here. This iterative
-- bootstrap is the process describe. Seeding it empty (vs.
-- guessing numeric IDs) avoids mis-classifying real abilities.
-- Ranged (staff / bow) basic attacks. Melee basics are handled by the
-- death_recap_melee_basic icon pattern below (all melee weapons share it), so
-- only ranged basics — which share death_recap_*_ranged art with enchant
-- glyphs and so can't be safely pattern-matched — need explicit IDs here.
-- Verified in-session via /vermilion skills (names from GetAbilityName).
-- Capture more (Inferno/Frost staff, Bow) with `/vermilion basic <id>` — it
-- persists to SavedVars and survives reloads.
local BASIC_ABILITY_IDS = {
  [18350] = true,  -- Light Attack (Lightning staff)
  [18396] = true,  -- Heavy Attack (Lightning staff)
  [19277] = true,  -- Heavy Attack (Lightning staff, channel tick)
  -- Melee IDs below are also covered by the icon pattern; listed for clarity.
  [15435] = true,  -- Light Attack (One Handed)
  [16037] = true,  -- Light Attack (Two Handed)
  [17162] = true,  -- Heavy Attack (Two Handed)
}

-- Icon-path → group lookup. Locale-independent, matched top-to-bottom.
local ICON_PATTERNS = {
  -- Melee basic (light + heavy) attacks: ALL melee weapons (1H, 2H, DW,
  -- unarmed) share this one icon, so one pattern covers them. Ranged basics
  -- (staff/bow) share death_recap_*_ranged with enchant glyphs and so are
  -- handled by BASIC_ABILITY_IDS instead, not here.
  { "death_recap_melee_basic",   "basic"          },
  -- Weapon skill lines (the abilities themselves, not the basic attacks).
  { "ability_2handed_",          "twohanded"      },
  { "ability_dualwield_",        "dualwield"      },
  { "ability_bow_",              "bow"            },
  { "ability_1handed_",          "onehand"        },
  -- Guild skill lines.
  { "ability_fightersguild_",    "fighters_guild" },
  -- Set / monster-set procs (e.g. Kra'gh) use gear_* art.
  { "gear_",                     "item"           },
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
  -- Vermilion damage-domain additions (captured via /vermilion skills):
  [46743]  = "item",        -- Absorb Magicka (weapon enchant glyph proc)
  [148797] = "status",      -- Overcharged (shock status-effect damage)
  [148800] = "status",      -- Sundered (physical status-effect damage)
  [21481]  = "status",      -- Chill (frost status-effect damage)
  [18084]  = "status",      -- Burning (flame status-effect damage)
  [21487]  = "status",      -- Concussion (shock status-effect damage)
  [48016]  = "destru",      -- Force Pulse (Destruction Staff; secondary hit, generic AoE icon)
  [126895] = "soul_magic",  -- Soul Splitting Trap (Soul Magic line)
  [45445]  = "dualwield",   -- Forceful (Dual Wield passive cleave; generic ability_weapon_ art)
  [21970]  = "basic",       -- Bash (universal weapon bash attack)
}

-- Runtime cache (abilityId → group string); populated on first encounter.
local ability_cache = {}

-- User-defined overrides, persisted in SavedVars (set via /vermilion tag and
-- /vermilion basic). Highest precedence — lets any user fix ANY classification
-- (including a wrong auto-guess) without a code edit or reload.
local USER_OVERRIDES = {}

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

  -- 0a. User override (persisted /vermilion tag) — highest precedence of all.
  g = USER_OVERRIDES[abilityId]
  if g then ability_cache[abilityId] = g return g end

 -- 0b. Basic (light/heavy) attack.
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
-- Sorted list of valid group names (for the /vermilion tag usage hint).
function M.group_names()
  local out = {}
  for k in pairs(GROUP_COLORS) do out[#out + 1] = k end
  table.sort(out)
  return out
end

function M.is_group(group)
  return GROUP_COLORS[group] ~= nil
end

-- Human label for a group key (for the assignment UI). Falls back to the key.
function M.group_label(key)
  return GROUP_LABELS[key] or key
end

-- Ordered category list for the picker UI: array of { key, label, r,g,b,a } in
-- the curated GROUP_ORDER. Cold path (built on demand when the flyout opens).
function M.groups_ordered()
  local out = {}
  for _, key in ipairs(GROUP_ORDER) do
    local c = GROUP_COLORS[key] or FALLBACK
    out[#out + 1] = { key = key, label = GROUP_LABELS[key] or key, r = c.r, g = c.g, b = c.b, a = c.a }
  end
  return out
end

-- Snapshot of every ability that fell through classification, for the
-- assignment window: array of { id, name, icon } sorted by id. Re-derives
-- name/icon fresh (cold path) rather than parsing the unknown_log string.
function M.get_unknowns()
  local out = {}
  for id in pairs(unknown_log) do
    out[#out + 1] = { id = id, name = GetAbilityName(id) or ("#" .. id), icon = GetAbilityIcon(id) or "" }
  end
  table.sort(out, function(a, b) return a.id < b.id end)
  return out
end

-- Count of currently-unclassified abilities (for a settings badge / empty state).
function M.unknown_count()
  local n = 0
  for _ in pairs(unknown_log) do n = n + 1 end
  return n
end

-- Assign abilityId -> group at runtime. Returns false on an unknown group.
function M.set_override(abilityId, group)
  if not abilityId or abilityId <= 0 or not GROUP_COLORS[group] then return false end
  USER_OVERRIDES[abilityId] = group
  ability_cache[abilityId]  = group
  unknown_log[abilityId]    = nil
  return true
end

-- Convenience: tag as a light/heavy (basic) attack.
function M.mark_basic(abilityId)
  return M.set_override(abilityId, "basic")
end

-- Replay user classifications persisted in SavedVars. Called once at load.
function M.load_persisted(sv)
  if not sv then return end
  if type(sv.skill_overrides) == "table" then
    for id, group in pairs(sv.skill_overrides) do
      if type(id) == "number" then M.set_override(id, group) end
    end
  end
  -- Legacy array form (basic-only), from before /vermilion tag existed.
  if type(sv.skill_basic_ids) == "table" then
    for _, id in ipairs(sv.skill_basic_ids) do M.set_override(id, "basic") end
  end
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
-- View 1 lives in core/metrics.eos_groups.
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
