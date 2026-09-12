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

Nothing under `qa/` or `test/` ships: the release workflow copies an allowlist of runtime
directories and neither is in it.
