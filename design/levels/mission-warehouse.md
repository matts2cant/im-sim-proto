# Mission: warehouse

Milestone: M9.

## Goal

Small two-storey warehouse compound. Take the datapad from the security office, then reach extraction.

## Contents

- 5 guards, mixed loadouts (pistol / baton) ([../game/perception-and-ai.md](../game/perception-and-ai.md))
- 2 cameras, 1 turret guarding the office, 1 alarm panel linked to the cameras, 1 breaker panel (lights) ([../game/security.md](../game/security.md))

## Routes

```mermaid
graph TD
    S["Start"] --> G["1 Front gate: guards and camera"]
    S --> D["2 Side door: keypad"]
    S --> R["3 Roof"]
    S --> W["4 Back wall"]
    D -->|"code from note in dumpster"| O["Security office"]
    D -->|"or multitool"| O
    G --> O
    R -->|"stacked crates + mantle, or Speed aug"| V["Vent"]
    V --> O
    W -->|"weakened wall + explosive barrel (loud)"| O
    O --> P["Take datapad"]
    P --> X["Extraction"]
```

## Rules

- Success: extraction with the datapad. Fail: death, then reload or restart ([../game/saving.md](../game/saving.md)).
- Summary screen on extraction: time, alarms, kills/knockouts, route used.
- Route relevance: movement ([../game/movement.md](../game/movement.md)), physics and explosives ([../game/objects-and-fire.md](../game/objects-and-fire.md)), abilities ([../game/abilities.md](../game/abilities.md)).
- Scenario tests cover the routes ([../tech/testing.md](../tech/testing.md)).
- No difficulty settings.

## Open questions

- Layout, guard patrols, how route is detected for the summary, datapad pickup mechanics: TBD in M9.
