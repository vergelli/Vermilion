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
