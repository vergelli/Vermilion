# Changelog

All notable changes to Vermilion are documented here. This project follows
[semantic versioning](https://semver.org/).

## [Unreleased]

### Fixed
- Damage you deal to yourself (Infinite Archive verses like Frigid Waters, set drawbacks) no longer counts as outgoing damage, so it stops showing as a grey contribution and as a lane with your own name in PRESSURE.
- Damage absorbed by an enemy's shield was credited to that shield's ability, so enemy wards showed up in SKILL and CONTRIB as if they were the player's skills. Each shield event is now paired with the attack that caused it and credited to that attack; a shield that finds no attack lands in a single "Shields cracked" bucket instead.
- TYPE now includes damage absorbed by shields, typed by the attack, so every view sums to the same EOS as the header.

### Added
- Light mode draws four corner brackets on hover, so the resize corners of the dimmed window are easy to find.
- CONTRIB rows show the share of each ability that was absorbed by shields as an orchid tail on the bar, with the amount on hover.
- SKILL and TYPE hang a faint orchid layer from the top of the plot: its depth at every column is the damage a shield absorbed at that moment, on the same scale as the bars. Hover it for the absorbed rate and share.
- PRESSURE replaces OUTCOME: damage pressure per enemy over time, a heat lane per target, hotter where you hit harder. Lanes are ordered by damage taken; a bar chart on the right, aligned row by row, shows the accumulated pressure per enemy with an orchid tail for the part a shield absorbed; the mouse wheel scrolls; hover shows the rate at that moment, the enemy's totals, its share of your output and the shields involved. Saved sessions keep it.
- The damage report names the enemy you focused most and the shield that absorbed the most over the recording, plus the share of the fight spent on your main target and how many times the pressure moved to another enemy.
- Killing blows: a skull marks the moment of every kill you land, at the top of SKILL, TYPE and CRIT and on the victim's lane in PRESSURE. Hover it for the victim and the ability. The damage report counts them. Saved sessions keep them.
- PRESSURE folds enemies of the same name into one lane with a count, so a pull of twelve skeletons is one lane, while enemy players always keep their own.
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
