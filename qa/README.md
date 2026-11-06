# Vermilion quality guarantees

Everything a release claims about its numbers, executed and reported. The Robot Framework
suite in `qa/robot` runs the offline ESO harness and replays every recorded fight through the
real pipeline against an independent oracle, and produces the human-readable report
(`log.html`, `report.html`). `test/gate.sh` stays the fast pre-merge gate; Robot wraps the same
checks.

## Running the report

```
qa\gate.bat --open      (Windows; --open launches report.html when done)
bash qa/gate.sh          (Git Bash / Linux / macOS)
```

By hand:

```
python -m pip install -r qa/robot/requirements.txt
python -m robot --outputdir qa/robot/output qa/robot/gate.robot
```

## Comparing a fight with the game's own log

`/encounterlog` makes the game write `Logs/Encounter.log`, which is independent of the addon. With a
trace of the same fight, `python qa/encounter_audit.py <Encounter.log> <trace.lua>` replays the trace
through the current code and checks every number against the log. `--slice=<trace>.encounter.log`
saves the part of the log for that fight next to the trace in the corpus, and from then on the gate
checks it. A recording only has to be made once: a fix is verified by replaying it.

A tester with a release build only has to send `Logs/Encounter.log` and `SavedVariables/Vermilion.lua`.
`python qa/encounter_audit.py --saved <Encounter.log> <Vermilion.lua>` compares every saved session the
log covers, as it was recorded. It cannot verify a fix, that needs a trace.
`--self-check <log> <trace>` runs the same comparison on a replayed fight, the gate does it on every trace.

## Feeding the oracle with real fights

The only data that validates the measurement is a trace: the game's raw events, captured in
game and replayed offline. With the debug keys on (`DEV` and `MODE` in `core/constants.lua`):

```
/vermilion trace auto    once; every Record now captures, every Stop stages the trace
... play ...
/vermilion flush         writes SavedVariables to disk (it reloads the UI)
qa\ingest.bat --open     on the PC: pulls the staged traces into the corpus, runs the suite
```

The addon keeps the last three staged traces in SavedVariables. `qa/ingest.py` extracts each
one into `../traces/<date>_<zone>_<world>_<events>_sv.lua`, skips the ones already there, then
runs the suite. `/vermilion trace` shows how many are staged; `/vermilion trace clear` empties
the ring once they are ingested.

## Random user sessions

The recorded fights all follow one path: record, stop, compare. Most of the bugs that got through lived between actions, or between two views of the same fight. `test/simlab/monkey.lua` fires random sequences of what a player does with a fixed seed, and checks rules after each step: the totals agree with a ledger of what was really fired, nothing moves after Stop, a fight reads the same before saving and after reopening, and a session looks the same whatever was opened before it.

```
lua test/simlab/monkey.lua . <seed> <steps> [0|1]     one session, a failure prints the seed, the step and the last actions
python qa/monkey_mutants.py                           puts each known bug back in a copy of the code, the sessions must find it
```

When a new bug appears, fix it with its own test and add it to the list in `qa/monkey_mutants.py`. If the sessions do not find it, they are missing a rule or a kind of fight.

Nothing under `qa/` or `test/` ships: the release workflow copies an allowlist of runtime
directories and neither is in it.
