# 66. Power circuits and shootable lights

Status: Accepted

Date: 2026-11-06

## Context

M7 needs lights the player can shoot out and a breaker that cuts a group of lights, without the breaker knowing the lights and without special-casing lamps. Stimuli carry type, intensity, origin and shape but no payload, so "which circuit" cannot ride on a stimulus field.

## Decision

- **Shootable lamps are ordinary breakables.** `objects/light_fixture/ceiling_lamp.tscn` and `wall_lamp.tscn` are static bodies on the world layer composed from existing parts: Tags (`object.lamp`, `material.glass`), Attributes (`health` 1), a StimulusReceiver with the shared `take_damage` receptron, Breakable with the glass material profile (glass break sound, green debris, break noise 15), a Light3D and a bulb mesh. No script on the lamp. A bullet (`damage.ballistic`) breaks it; Breakable frees the entity and the light goes with it. Lamp meshes do not cast shadows (they would black out their own light).
- **`Powered` component** (`objects/components/powered.gd`): `circuit` (StringName), `on`, `targets` (node paths shown while on and hidden while off; default every Light3D under the entity). An entity opts into a circuit by this property only: Powered joins group `circuit.<id>` (and `powered`). `Powered.set_circuit(tree, id, on)` switches the group. A hidden light lights nothing (LightExposure skips it, [ADR 0065](0065-light-level-model.md)). Saveable (`on`).
- **`CircuitBreaker` component** (`objects/components/circuit_breaker.gd`, a `Usable`): `circuit`, `closed`, `label`, `noise_loudness` (6). E on it ("E: switch off lab lights" / "switch on") toggles `closed`, calls `Powered.set_circuit`, turns the lever, emits a `noise` stimulus (PATH, the usual noise path) from the panel and logs `power.switched` {circuit, on, powered}. A breaker placed open cuts its circuit when the level starts. Saveable (`closed`); loading re-applies its state to the circuit. `objects/breaker_panel/breaker_panel.tscn` is a wall panel with the component.
- **Why a group and not a stimulus**: switching a circuit is not perceived through space (no origin, reach or line of sight matters), and encoding the circuit in the stimulus type (`power.<id>`) would need a StimulusReceiver on every lamp plus an effect parsing the type string. A group keyed by the circuit id is a public component API found by group, which AGENTS.md allows; any future switch (a keypad, a timer, an EMP effect) calls the same `set_circuit`.
- **Broken lamps across save and load**: a lamp has saveables (Tags, Attributes, Powered), so `LevelSnapshot` lists a broken lamp under `removed` and frees it on load; the open breaker and the remaining lamps' `on` come back from `states`.

## Alternatives considered

- Breaker holding NodePaths to its lamps: breaks "no references to specific lights" and every new lamp edits the breaker.
- A `power` stimulus with radius: meaningless distance, needs receivers on lamps and a payload.
- Toggling `light_energy` instead of `visible`: would also need the bulb's glow handled separately; `visible` covers both.

## Consequences

- A new powered thing (a camera, a door) is a scene with a Powered whose targets are its own nodes; nothing else changes.
- Powered only hides nodes: anything that should stop working (a turret) reads `on` or listens to `power_changed`.
- See [light and visibility](../game/light-and-visibility.md), [security](../game/security.md).
