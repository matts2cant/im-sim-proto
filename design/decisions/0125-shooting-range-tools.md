# 125. Shooting range tools: impact marks, walking target, stats board, tuning panel by reflection

Status: Accepted (builds the range of [ADR 0120](0120-weapon-feel.md)'s M13a)

Date: 2026-11-12

## Context

ADR 0120 asks the shooting range for M13a's feel loop: dummies at 5, 10, 20 and 40 m and one walking side to side, a spray wall that keeps every hole, a stats panel (hit share, group size), live tuning sliders per weapon that save into its tuning file, a Weapons skill tier switch and a button resetting every downed dummy. The recoil and spread values are being added in parallel by another agent (`@export_range` properties on `WeaponData`, `AimConfig` or a new `RecoilConfig`), so the panel cannot know their names. The 14 m hall had no room for two more lanes.

## Decision

- **The hall grows 10 m to the east** (local +X, hub +Z; 24 x 48 m, outer hub z 3.5 to 28.5; nothing else stands east of hub x 19). Two lanes join the four: lane 5 (x 10.5 to 14.5) holds the spray wall, lane 6 (x 14.5 to 20.5) the walking dummy. The melee pair moves 10 m east with its wall.
- **Impact marks are a component** (`ImpactMarks`, `objects/components/impact_marks.gd`): any surface entity with it and the `marked_by_bullets` receptron (`damage.ballistic` -> `MarkImpactEffect`) keeps a 5 cm mark where each ray hit it, one MultiMesh, the oldest reused past `max_marks` (500). Visual only and not saved, like a muzzle flash. The spray wall is a kit `Ledge` (3.6 x 3 m) carrying them; nothing in the code names it.
- **The walking dummy is a training dummy with a `Shuttle`** (`objects/components/shuttle.gd`): it moves its entity back and forth along a line (4 m, 1.5 m/s, a guard's walk) and stops while the entity cannot act (`state.dead`, `state.unconscious`). Saveable (where it is, which way it goes). It slides: the mannequin's animator reads a CharacterBody3D's speed only.
- **The stats board** (`StatsBoard` + `ShotStats`, `objects/range/`) is a debug readout: it listens to `StimulusSystem.stimulus_processed` for `damage` RAY stimuli (whoever fires them), counts one shot per projectile line, a hit when the ray's collider is a target or inside it (the point kept in the target's frame, so a moving target's group stays put), a miss against the target whose aim point the line passed within 1.5 m. Per target the last 10 shots give hit share and group size (the widest pair of hits, cm). The signal's "gameplay must not" rule holds: nothing in play reads the board.
- **Tuning by reflection** (`TuningProperties`, `ui/tuning_panel/`): the weapon in the user's hand and every scripted Resource it references through exported properties, recursively, each once; of each, every exported float or int with `PROPERTY_HINT_RANGE` becomes a slider (min, max, step from the hint) that sets the live resource and emits `changed`. Save writes each file the resources live in (`ResourceSaver`; embedded sub-resources go with their file); Revert reloads the files ignoring the cache and copies the range values back. No property name appears in the code, so the recoil agent's names work unchanged.
- **The tuning panel** (`TuningPanel`) is a `WindowFrame` (Halcyon look; a new `HalcyonSlider` theme variation) on the right of the screen: the world keeps running and stays visible (no dim, no pause), the user's input is off and the mouse free while it is open; Esc, ✕, walking more than 3 m from the desk or being unable to act close it. A `TuningDesk` (a Usable on the counter's terminal) opens it.
- **The Weapons skill tier** of the gun in hand: the skill whose effects write one of the weapon's class attributes (`<attribute_class>_*`, ADR 0061), set through `Skills.set_tier()` like the Skills tab (`WeaponSkill`). Both the panel's tier buttons and a physical `SkillTierSwitch` (E: next tier) use it.
- **Physical controls on the counter** (`range_button.tscn` with a behaviour node): `BodyResetButton` resets the `BodyParts` of every downed entity tagged `actor.dummy` in the room (dead or knocked out; property, not identity); `CallButton` calls a method on its targets (level wiring for "Clear wall" and "Reset stats").
- **A second rack** east of the medkits: a pistol, 60 rounds and a labelled empty slot for the submachine gun.

## Alternatives considered

- **Stats from the EventLog** (`weapon.fired`, `stimulus.received`): it carries no shot line, so misses could not be placed; the log is also a ring buffer that tests clear.
- **A receptron on every target counting hits**: still needs the shots that missed, which only the ray carries.
- **A list of known tuning properties**: breaks the moment the recoil agent names them differently.
- **A pausing, full-screen panel**: the point of live tuning is to see and feel the change; the world stays visible on the left.
- **An AnimatableBody for the walker**: the training dummy is a StaticBody3D whose hitboxes and collision tip with its pose; moving it by its transform keeps the scene unchanged.

## Consequences

- `tools/lint.sh` now passes files to gdformat and gdlint in batches of 300: the project's ~780 paths passed Windows' 32 K command-line limit.
- Saving from the panel rewrites a .tres in Godot's own format (ids, ordering): commit only the values you meant.
- Shots fired anywhere near a target count on the board, also a guard's (none on the range).
- Tests: `tests/objects/components/impact_marks_test.gd`, `shuttle_test.gd`, `tests/objects/range/` (stats, board, controls), `tests/ui/tuning_panel/` (reflection with test resources, the panel), `tests/levels/gallery/shooting_range/shooting_range_tools_test.gd` (room) and `shooting_range_tools_hub_test.gd` (hub, with the player).
