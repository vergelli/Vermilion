# Changelog

All notable changes to Vermilion are documented here. This project follows
[semantic versioning](https://semver.org/).

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
