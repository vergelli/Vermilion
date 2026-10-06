# Changelog

All notable changes to Vermilion are documented here. This project follows
[semantic versioning](https://semver.org/).

## [Unreleased]

### Changed
- Recording is configured from the record button. Its arrow opens a small panel with three choices, one row each: how a recording starts (by hand, any fight, boss fights), how it stops (by hand, when the fight ends; automatic starts always stop with the fight) and how it saves (by hand, when it stops). The panel closes from the arrow, with a click anywhere else, or with the window. The three buttons in Settings are gone, a note points to the button. The main half records or stops and pulses while recording; a small tag beside the status names the mode in force.

### Added
- Magicka and stamina are recorded with the session: the level of each pool at every sample, and how much was regained and how much was spent in that second, from the game's power events (no polling). Sessions carry the two pools by addition; older sessions load without them. Under the ultimate band the graph shows a thin row per pool, blue for magicka, green for stamina, filled to the pool's level and turning vermilion while the pool sits under 30%; hover a moment for the level, the regained and spent amounts of that second and the regen-to-spend ratio over the last ten seconds. The damage report adds one line per pool: the ratio over the fight and the share of the fight spent under 15%.
- A RESOURCES view, the seventh tab. A picker chooses magicka, stamina or both. With both, the lane mirrors the two pools around a midline, magicka growing up and stamina hanging down, each column filled to the pool's level and vermilion under 30%. With one pool the lane splits in two: the level on top, the flows below as a hydrograph, regained up and spent down around a midline, second by second. Every level drawing carries the 15% band and the 30% line, so the thresholds that colour the strip are visible, and a vermilion mark along the edge shows where the pool sat under 15% for two seconds or more. Beside the lane two ranked lists in the CONTRIB style, icon, skill-line colour and value: SPENT BY SKILL, what each skill cost over the fight, from the casts the addon now records with the ability's mechanic and its real cost at the moment of casting; and RECOVERED BY, what gave the pool back, from the game's energize events (heavy attacks, potions, synergies, set procs) with a Recovery row for the character's own regeneration, read from the recovery stat when the recording starts. Both are new session streams, by addition. Hover the lane for the level, the flows of that second, the ten-second regen-to-spend ratio, the top spender of the last ten seconds, what recovered that second, the recovery per tick and how long the pool had been starved; hover a row for its casts or restores, average, total and share. The report gains a damage-per-1k-spent line. Debug builds get `/vermilion castprobe`, which lists the slotted skills with the mechanic flags and costs the game reports. The picker, each half of the lane (or the level and flow lanes) and the two lists sit in thin gold frames; the lanes name what they show (LEVEL, REGAINED, SPENT); the 15 to 30% zone is a faint yellow band with a yellow line at 30%; in BOTH the columns fade toward the midline so a full pool stays quiet; RECOVERED BY colours its bars by pool and rows without a usable icon, the Recovery row included, wear the pool's icon.
- Developer panel (debug builds only): every diagnostic command becomes a clickable row, grouped by purpose, with the command it runs shown beside it. `/vermilion dev` opens it, as does the DEV button next to the version in Settings.
- The game's own encounter log can be switched from the addon: `/vermilion elog [on|off|status]` and the matching panel row, which shows whether the engine is writing `Documents\Elder Scrolls Online\live\Logs\Encounter.log` right now.
- Traces stamp the wall-clock epoch when they start (`EP` line) and `/vermilion mark [label]` writes a labelled `MK` line, so a trace can be aligned event by event with the encounter log recorded during the same fight.

### Fixed
- Resource flows above 4 095 in one second (a potion, a heavy attack restore, a burst of casts) were clipped to 4 095 when a session was saved; new sessions carry wider fields. Sessions saved before this read back unchanged.
- Debug traces that hit their 40 000-event capacity were thrown away when the recording stopped. The capture still stops at the cap, but what was captured is kept and saved, and the status line says it was capped.

## [1.2.1] - 2026-09-12

### Fixed
- The two session-navigation keybinds (Previous / Next Session) never actually worked: the PR that added them wired the header arrows and the display names but never registered the keybind actions in bindings.xml. The arrows themselves were never affected.

## [1.2.0] - 2026-09-12

### Added
- Hover cards size their rows to the text: a long shield or ability name no longer gets cut off next to its value, and the card widens when a row needs it.
- Two arrows next to the library icon step through the saved sessions without opening the library: left for the older one, right for the newer, and the status line shows the session's position in the library. Two keybinds do the same. Nothing happens while a recording runs.

### Changed
- The orchid layer that hung from the top of SKILL and TYPE is gone: it took height from the bars, and the absorbed damage is already stacked inside them. In its place a shield strip sits under the ultimate band on every plot view, a heat strip on the PRESSURE ramp showing how hard enemy shields were absorbing at every moment, with the shield icon at the left, always present and empty when nothing was absorbed, like the ultimate band; hover it for the rate and share. PRESSURE lanes gain a thin sub-lane at their foot on a second colour ramp, showing the absorption on that enemy over time.

## [1.1.1] - 2026-09-12

### Fixed
- The shield layer and ShDPS averaged absorbed damage over a 30-second window while the bars use 5 seconds, so a cracked shield showed as a long, low band that outlived the hit by half a minute, and EOS added two different time scales. Both now share the 5-second window: the layer has the height and width of the event, and the header sums like with like.

## [1.1.0] - 2026-09-12

### Fixed
- Damage you deal to yourself (Infinite Archive verses like Frigid Waters, set drawbacks) no longer counts as outgoing damage, so it stops showing as a grey contribution and as a lane with your own name in PRESSURE.
- Damage absorbed by an enemy's shield was credited to that shield's ability, so enemy wards showed up in SKILL and CONTRIB as if they were the player's skills. Each shield event is now paired with the attack that caused it and credited to that attack; a shield that finds no attack lands in a single "Shields cracked" bucket instead.
- TYPE now includes damage absorbed by shields, typed by the attack, so every view sums to the same EOS as the header.
- The category flyout in Unknown Contributions opened with no backdrop, so its rows drew over whatever sat behind the window; it now has an opaque fill with the crimson edge.
- Light and heavy attacks of most weapons (Inferno and Dual Wield first, bow and others by the same rule) landed in Unknown Contributions. Basic attacks are now recognised by name, with the names learned from the game client so the rule holds in every language, then by the weapon death-recap icons, with the fixed id list as the last resort.

### Added
- Light mode draws four corner brackets on hover, so the resize corners of the dimmed window are easy to find.
- CONTRIB rows show the share of each ability that was absorbed by shields as an orchid tail on the bar, with the amount on hover.
- SKILL and TYPE hang a faint orchid layer from the top of the plot: its depth at every column is the damage a shield absorbed at that moment, on the same scale as the bars. Hover it for the absorbed rate and share.
- PRESSURE replaces OUTCOME: damage pressure per enemy over time, a heat lane per target, hotter where you hit harder. Lanes are ordered by damage taken; a bar chart on the right, aligned row by row, shows the accumulated pressure per enemy with an orchid tail for the part a shield absorbed; the mouse wheel scrolls; hover shows the rate at that moment, the enemy's totals, its share of your output and the shields involved. Saved sessions keep it.
- The damage report names the enemy you focused most and the shield that absorbed the most over the recording, plus the share of the fight spent on your main target and how many times the pressure moved to another enemy.
- Killing blows (the engine reports them as "died, experience" for NPCs and as a killing blow for players; both are read): a skull marks the moment of every kill you land, at the top of SKILL, TYPE and CRIT and on the victim's lane in PRESSURE. Hover it for the victim and the ability. The damage report counts them. Saved sessions keep them. A "Kill markers" toggle in Settings hides the skulls, for content where everything dies all the time; the report keeps counting.
- PRESSURE folds enemies of the same name into one lane with a count, so a pull of twelve skeletons is one lane, while enemy players (by unit type, never by name) always keep their own.
- Ultimate band above every plot view, as in Verdant: a row per bar showing the charge over time, bright when ready, a tick at every cast, the ultimate's icon at the left. Hover for the charge at that moment. The damage report adds the time the ultimate sat ready and the casts. Saved sessions keep it.

## [1.0.1] - 2026-09-10

### Added
- CONTRIB view: the Type column shows the damage-type icon instead of a word, and the shield rows wear the shield icon. Hover a row and the card carries the same icon with the type's name. Every second row wears a faint band, and each row shows its rank.
- The summary chip ends with the icon of the damage type that carried the recording and its share; the damage report names it.
- The header reads "idle" in grey while nothing is recording, and shows the number again as soon as a recording starts. The crit readout now sits right after the damage readout instead of by the gear. The close cross sits level with the gear.

### Fixed
- The damage report of a library session showed zero total and zero hits; it now reads the totals saved with the session.
- Debuffs never land in Unknown Contributions any more; that window is for abilities that dealt damage.

### Changed
- DEBUFFS view: Minor Brittle, Lifesteal, Magickasteal, Mangle and Timidity join the family colours, status effects (Burning, Poisoned, Chilled, Concussed, Overcharged, Diseased, Hemorrhaging, Sundered) wear an ember colour of their own and taunts, stuns and snares a khaki one, so fewer lanes stay grey.

## [1.0.0] - 2026-09-10

### Added
- Session library: every recording can be kept, named, locked and reopened from the library window; autosave on Stop, a manual Save icon and keybind, the SAVING / SAVED / NOT SAVED status and the content kind of the fight (dungeon, trial, arena, Infinite Archive, battleground, Alliance War, home, overland).
- Auto-record on boss fights or any combat, with a grace period after combat, and Auto-stop for recordings started by hand.
- CONTRIB view: abilities ranked by the damage they dealt over the window, with the damage type, a bar coloured by skill line, hover details and mouse-wheel scrolling.
- DEBUFFS view: the debuffs you put on enemies, one lane per debuff with uptime, targets at once, applications, the always-on strip and a hover card with the ability description.
- Tab strip for the views with tooltips, Next and Previous view keybinds, a double click on the title bar restores the default size.
- Summary chip after a recording (AVG, PEAK, CRIT, ACTIVE, SHIELD); hovering it opens the damage report, clicking copies it.
- Light mode while recording with its own opacity, fade-in on open, a logo heartbeat while a recording runs with the window closed, glyphs on Record and Stop.
- Settings in sections with user profiles, a question before experimental sample-rate and window combinations, a Sounds toggle and the build version.
- Sounds on every window and button, all behind the Sounds setting.
- Offline test lab, replay of recorded fights against an independent oracle and the Robot quality report (nothing under qa/ or test/ ships).

### Changed
- Bars sit on a physical-pixel grid: one width and one pitch at any UI scale; a young recording grows to fill the axis, which reads from -15s to now.
- The window slider reaches 20 minutes.
- The CopyBox ships in release builds for the report copy.
- Manifest: APIVersion lists the current live patch and the PTS one, so the addon is no longer flagged out of date.
- Debug tools need two keys in core/constants.lua, DEV and MODE, like the rest of the family. Flipping DEBUG alone does nothing.

## [0.9.1] - 2026-07-12

- The damage-type icon on the hover card doubles in size (14px chip to a 28px icon spanning the name and stat lines); the SKILL view keeps its color chip untouched.

## [0.9.0] - 2026-07-12

- New DAMAGE TYPE view: your damage split and colored by damage type (fire, shock, poison, disease, bleed, physical, magic and friends), with per-type icons.
- New crit threshold setting (0-100%, default 50%) driving the crit display.
- Crit display redrawn with UI components instead of textures: crisper at every scale.
- Smoother memory behavior: incremental garbage-collection pacing (no more GC spikes mid-fight).
- Sample rate is now capped at 5 Hz (was 10). The 6-10 Hz options doubled the cost for no perceptible visual gain; saved settings above 5 Hz are clamped automatically.
- Release pipeline hardening: staged-texture guard, hidden-file strip and a dev-keys-off check.

## [0.8.0] - 2026-06-07

First public beta — the crimson twin of [Verdant](https://www.esoui.com/downloads/info4557-Verdant.html).

**Live damage analytics in a single window.**

- **Three views**, switchable from the title bar:
  - **SKILL** — your damage stacked and colored by source (class lines, weapons, guilds, status effects, item procs).
  - **OUTCOME** — eDPS (landing on health) vs ShDPS (absorbed by the target's shields).
  - **CRIT** — your landed damage split into non-critical base and critical cap.
- **Live DPS readout** in the window header, updated each second.
- **eDPS / ShDPS / EOS** metrics — see how much of your output is dropping health versus being eaten by shields.
- **Skill-line color classification**, with an **Unknown Contributions** window to label the handful of hits (set procs, generic-icon enchants) the classifier can't place — applied live, no reload.
- **Record / Stop / Flush** to capture and clear a session.
- **Floating logo button** (movable, optional) and an assignable keybind.
- **Per-server SavedVariables** — EU / NA / PTS kept separate.

**Under the hood:** zero-allocation sampling path, pooled combat events, fixed-interval snapshots, no dependencies. Localized number formatting (DE/FR decimal separators).
