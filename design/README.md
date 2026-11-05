# ImSimProto design

Entry point for all design documentation. Code-facing rules for agents are in [../AGENTS.md](../AGENTS.md); setup is in [../README.md](../README.md).

## Vision and pillars

A first-person immersive sim in the spirit of Deus Ex (2000): systemic, emergent gameplay where several approaches solve the same problem. v0 is a prototype that proves the systemic framework.

Pillars (v0): stealth/perception, physics objects, security/electronics, fire. Water, electricity and social systems come later ([backlog](backlog.md)).

## v0 scope

In:

- A hub, a test gallery (one room per system) and one small warehouse mission.
- Player movement incl. mantle and vents; body-part damage; silenced pistol and stun baton; grid inventory.
- Skills (4 tiers) and augmentations with energy; no leveling.
- Light-based visibility; graded guard AI with communication and alarm; cameras, turret, alarm, locks, keypads, terminals.
- Stimulus/response framework with attributes, modifiers and tags; EventLog; debug panel; quicksave/quickload.
- GdUnit4 tests in three layers.

Out (parked in [backlog](backlog.md)): progression, own hacking design, security robot, water/electricity, lean/ladders, gamepad and rebinding, difficulty settings, real art, voiced barks, inventory rotation, remote/CI.

## Doc map

```mermaid
flowchart TD
    R["design/README.md"] --> G["game/ (systems)"]
    R --> L["levels/"]
    R --> T["tech/"]
    R --> D["decisions/ (ADRs)"]
    R --> B["backlog.md"]
    G --> L
    T --> G
    D --> G
    D --> T
```

## Milestones

```mermaid
flowchart LR
    M0["M0 Skeleton"] --> M1["M1 Player"]
    M1 --> M2["M2 Core framework"]
    M2 --> M3["M3 Physics and fire"]
    M3 --> M4["M4 Damage and weapons"]
    M4 --> M5["M5 Inventory"]
    M5 --> M6["M6 Abilities and saving"]
    M6 --> M7["M7 Light and AI"]
    M7 --> M8["M8 Security"]
    M8 --> M9["M9 Mission"]
```

| # | Milestone | Gallery room |
|---|---|---|
| M0 | Skeleton: git, docs, AGENTS/README/CLAUDE, GdUnit4 runner, gdtoolkit hook, folder layout, input map, EventLog, DebugPanel shell, hub graybox | Hub |
| M1 | Player controller: walk/crouch/sprint/jump/mantle/vents, footstep noise | Movement course |
| M2 | Core framework: stimulus/response, attributes/modifiers/tags, StimulusSystem autoload | none |
| M3 | Physics objects and fire | Physics and fire |
| M4 | Body-part damage, pistol, baton, aiming | Shooting range |
| M5 | Grid inventory, belt, items, pickup/drop | Inventory bay |
| M6 | Skills, augmentations, energy, stats tab, quicksave/quickload | Inventory bay |
| M7 | Light level, guard perception and AI, alerts, bodies | Perception lab, AI arena |
| M8 | Security: cameras, alarms, turret, doors/locks/keypads, terminals | Security wing |
| M9 | Mission area and scenario tests | Mission |

Each milestone is one branch; manual checks are in [tech/playtest-checklist.md](tech/playtest-checklist.md).

## Index

### Game systems

- [game/stimulus-response.md](game/stimulus-response.md): stimuli, receptrons, effects, propagation, EventLog.
- [game/attributes-and-tags.md](game/attributes-and-tags.md): tags, attributes, modifier evaluation.
- [game/movement.md](game/movement.md): walk, crouch, sprint, jump, mantle, vents, footstep noise.
- [game/controls.md](game/controls.md): physical-key bindings.
- [game/light-and-visibility.md](game/light-and-visibility.md): analytic light level and visibility.
- [game/perception-and-ai.md](game/perception-and-ai.md): guards, awareness states, communication, bodies.
- [game/damage.md](game/damage.md): body parts and damage types.
- [game/weapons-and-aiming.md](game/weapons-and-aiming.md): pistol, baton, reticle.
- [game/objects-and-fire.md](game/objects-and-fire.md): physics objects and fire.
- [game/security.md](game/security.md): cameras, alarms, turret, doors and locks, terminals.
- [game/inventory.md](game/inventory.md): grid, belt, items.
- [game/abilities.md](game/abilities.md): skills and augmentations.
- [game/debug-panel.md](game/debug-panel.md): debug tabs.
- [game/saving.md](game/saving.md): saveable contract, quicksave/quickload.

### Levels

- [levels/metrics.md](levels/metrics.md): player size, clearances, jump/mantle limits, noise numbers for level building.
- [levels/hub-and-gallery.md](levels/hub-and-gallery.md): hub and seven test rooms.
- [levels/mission-warehouse.md](levels/mission-warehouse.md): warehouse mission, four routes.

### Tech

- [tech/architecture.md](tech/architecture.md): layers, folders, autoloads, tick model.
- [tech/conventions.md](tech/conventions.md): code style and typing rules.
- [tech/testing.md](tech/testing.md): three test layers, scenario tests, commands.
- [tech/playtest-checklist.md](tech/playtest-checklist.md): manual checks per milestone.

### Decisions and backlog

- [decisions/README.md](decisions/README.md): ADR index (31 decisions).
- [backlog.md](backlog.md): parked items.
- [retrospectives.md](retrospectives.md): what went wrong per milestone and the process changes made.
