*** Settings ***
Documentation     Vermilion quality guarantees. Every test here is a claim the release makes,
...               executed against the real addon code through the offline ESO harness and
...               the replay of recorded fights.
Library           VermilionGate.py

*** Test Cases ***
Every Lua File Parses
    [Tags]    static
    ${msg}=    Every Lua File Parses
    Log    ${msg}

Harness Passes With Diagnostics On
    [Tags]    harness
    ${msg}=    Harness Passes    1
    Log    ${msg}

Harness Passes In Release Mode
    [Tags]    harness
    ${msg}=    Harness Passes    0
    Log    ${msg}

Real Traces Replay At Zero Divergence
    [Documentation]    Recorded in-game traces replay through the real pipeline. An independent
    ...                oracle recomputes eDPS and ShDPS every 250 ms with zero divergence, and
    ...                the integrated rates equal the window-weighted event amounts to 1e-6.
    [Tags]    replay    numeric
    ${msg}=    Traces Replay Clean
    Log    ${msg}

Numbers Match The Raw Events
    [Documentation]    Replays recorded fights and recomputes the numbers from the raw events, without
    ...                the addon: damage total, hits, skill shares, target and skill totals, uptime and
    ...                debuff seconds per effect.
    [Tags]    replay    numeric
    ${msg}=    Traces Match Their Events
    Log    ${msg}

Fights Match The Game Log
    [Documentation]    Replays each recorded fight through the current code and compares its numbers
    ...                with the Encounter.log the game wrote for that fight: damage, hits, crits, fight
    ...                time, shares, casts, spend, restores, ultimate, effects, gaps and kills.
    [Tags]    replay    numeric
    ${msg}=    Fights Match The Game Log
    Log    ${msg}

Differences With The Reference Are Explained
    [Documentation]    A reference tool measures some things differently on purpose: other windows, the
    ...                pool lost when dying, hits of pure overkill. Frozen results of that tool, next to
    ...                the same recorded fights, must differ from ours by exactly what we can explain.
    ...                They stay outside the repository; without them this test checks nothing.
    [Tags]    replay    numeric
    ${msg}=    Differences With The Reference Are Explained
    Log    ${msg}

Saved Sessions Match The Game Log
    [Documentation]    Each replayed fight is saved to a library file and read back the way a tester's
    ...                SavedVariables are, then compared with the same log without any trace.
    [Tags]    replay    numeric
    ${msg}=    Saved Sessions Match The Game Log
    Log    ${msg}
