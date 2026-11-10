# 95. Darkness and flashlights: a moving floor in the dark, flashlights as plain spot lights

Status: Accepted, amended by [ADR 0105](0105-character-model-playtest-fixes.md) (the flashlight is a model held in the off hand while lit, at the belt while off; the beam leaves its lens, about 0.46 m from where it was, along the same direction)

Date: 2026-11-09

## Context

M8 playtest: "Guards are basically unable to spot you when you're in shadow." In the vision model ([ADR 0067](0067-vision-and-detection.md)) the light factor is `clamp((L - 0.1) / 0.4, 0, 1)`: below light level 0.1 the gain is 0 beyond the 2 m close override, whatever the player does. A player could walk upright past a guard 3 m away in the dark. The user chose two changes: a small light floor for targets that move, and flashlights.

## Decision

### The moving floor

- A target whose horizontal speed is above `moving_speed` (0.5 m/s) keeps a light factor of at least `moving_light` (0.14) however dark it is: `light = max(clamp((L - 0.1) / 0.4, 0, 1), close floor, moving floor)`. A still target keeps the old behaviour (invisible in the dark beyond 2 m).
- **A step, not a ramp with speed.** The crouch factor (0.7) already makes slow movement less visible; scaling the floor with speed as well would multiply the two (crouch-walk 2 m/s against walk 4 m/s: 0.5 x 0.7 = 0.35 of the walking gain), so the crouch-walk target (Alerted in 7-11 s) and the walking one (4-7 s) could not both be met: with the walking gain at 0.17/s, crouch-walking would take about 17 s. A step also reads simply for the player: "in the dark, stand still and you are invisible; move and you can be noticed". The threshold sits well below crouch-walking (2 m/s), so creeping is still movement; a player stopping drops under it in a few frames.
- Speed comes from the target's body (`PerceptionSensor.horizontal_speed_of()`): a CharacterBody3D's `get_real_velocity()` (the motion it really made: walking into a wall is standing still), a RigidBody3D's `linear_velocity`, 0 for anything else. No player code.
- Tuning in `PerceptionConfig` (`moving_light`, `moving_speed`; `guard_perception.tres`). Cameras and turrets keep 0 (their configs do not set it): a camera is a fixed eye whose tuning (ADR 0079) already assumes no dark floor.
- 0.14 centres the targets of the brief at a held 4.5 m (gain 1.25 x 0.14 = 0.175/s walking, x 0.7 = 0.1225/s crouched): Suspicious at 0.3 after 1.7 / 2.5 s, Alerted after 5.7 / 8.2 s. When the guard walks to the point after its 2 s look it closes in under 2 m (the close override, 0.5) and the alert comes sooner (measured 5.1 s walking, 6.4 s crouch-walking if the target keeps pacing on the spot).

### Searching guards need a meter of 0.2 to alert

- Until now a Searching guard went Alerted on the first frame it saw the target with any gain above 0 ([ADR 0068](0068-awareness-states-and-guard-behaviour.md)): safe while darkness meant a gain of 0. With the moving floor, any step in the dark within a searcher's 20 m focus cone alerted it at once (the loud route: walking along the main roof 11 m from searchers on the fire escape landing below, light 0.04, was an instant alert, and their flashlights then lit the player for everyone).
- Now sight alerts a searcher once the meter reaches `search_alert_meter` (0.2, `guard_awareness.tres`; the meter rises with the wary gain and decays 0.25/s unseen; 0 keeps the old rule). A lit target 4 m away still alerts in about 0.1 s; a target moving in the dark 10 m away after about 1 s of sight; right after losing a target the meter is still high, so a glimpse re-alerts at once.

### Flashlights

- **`Flashlight`** (`actors/common/light/flashlight.gd`, scene `flashlight.tscn`, tuning `FlashlightConfig` in `flashlight.tres`): a component any character carries where it holds it. It builds a `SpotLight3D` (range 12 m, half-angle 20 degrees, energy 0.85, warm white), a small emissive lens and a camera-facing additive halo (0.7 m), all hidden while off.
- **When it is lit:** the carrier (nearest ancestor with Tags) has none of `off_tags` (`state.unconscious`, `state.dead`) and either `on_while_patrolling` (per character, set in level or population data: on in every awareness state) or the carrier's GradedAwareness is in one of `on_states` (Searching, Alerted). It polls every physics tick, logs `light.flashlight {actor, lit}` and is saveable (`on_while_patrolling`, lit).
- **Lighting is the light system's:** the beam is a plain SpotLight3D, so `LightExposure` already sees it (it handled spot cones since ADR 0065; the shadow rays ignore the carrier, the body the light hangs from). Nothing in perception knows about flashlights; a body lit by a flashlight is found by the body-discovery rules unchanged (`flashlight_detection_test.gd`).
- **Guards:** `guard.tscn` carries one on its Aim node (the eye that combat turns towards the target), 0.18 m right, 0.12 m down, 0.25 m forward, pitched 10 degrees down so the cone's axis meets the floor about 8.5 m ahead and covers a standing body's three light points at 8 m. Every guard lights it when Searching or Alerted. In the warehouse the yard patrols (G2, G3, G9: routes outside the buildings) keep it on while patrolling (`warehouse_people.py`).
- **Tuning target:** a walking target caught in the cone at 8 m in the dark reads light level about 0.23 (dim), gain about 0.35/s with the distance factor 0.85: Alerted in 2-3 s (measured below; a Suspicious guard looks 2 s and then walks closer).
- **Shadows on.** An unshadowed spot light would light the far side of a wall in the render (LightExposure never would: its shadow rays always run). That disagreement would be a real bug, so the beam casts shadows; the cost is measured below and stays small.

## Measured

Detection in the dark (L 0.04), guard facing the target, focus cone, target pacing sideways 4.5 m ahead (`darkness_detection_test.gd`; 4.5 m keeps clear of the 5 m distance breakpoint):

| Target | Before (Suspicious / Alerted) | After, held at 4.5 m | After, target paces on the spot (the guard walks up) |
|---|---|---|---|
| Walking (4 m/s) | never / never | 1.73 s / 5.73 s | 1.73 s / 5.12 s |
| Crouch-walking (2 m/s) | never / never | 2.47 s / 8.18 s | 2.47 s / 6.37 s |
| Standing still | never | never in 10 s | never |

Flashlights (`flashlight_detection_test.gd`): a walking target in the beam 8 m ahead reads 0.21-0.25 and is Alerted in 2.63 s (energy 0.85; the first guess 1.0 gave 0.26-0.28 and 2.15 s, too close to the 2 s floor of the target). A downed guard 6 m down the beam reads above 0.2 and is found within 2.5 s; the same body in the dark is not.

Cost, warehouse, all ten flashlights lit (`warehouse_shots.gd` `perf=1 flashlights=0|1`, 1152x648, vsync off, two runs each, other Godot processes running): render within the noise (hall dock 492-538 fps off, 468-470 on; west yard 686-713 off, 670-688 on; shadows off 492 / 683), physics process about +0.5 ms per physics frame (hall 5.3-5.4 ms off, 5.9-6.8 on). Each LightExposure (player, guards) traces 3 shadow rays per flashlight within 13 m at 10 Hz. Shadows stay on: their render cost is not measurable here and they keep the render honest.

## Alternatives considered

- A ramp of the floor with speed (see above): fails the crouch target, harder to read.
- A floor for every target in the dark (moving or not): the user wanted standing still in shadow to stay safe.
- A flashlight as a stimulus (a "lit" tag pushed onto targets in a cone): a second light model beside LightExposure, and lamps and flashlights would disagree.
- A volumetric beam (fog or a cone mesh): fog changes the whole level's look and costs per pixel; a cone mesh pokes through walls a guard faces. The lit pool on the ground plus the lens and halo read well enough (screenshots).
- Flashlights only in loadout scenes (`guard_pistol.tscn` ...): every guard should light it when searching, so it lives in the base guard scene; a level or population scene sets `on_while_patrolling`.

## Consequences

- Walking upright in the dark near a guard's view is no longer safe; crouch-walking buys time; standing still in shadow still hides you.
- Searching and Alerted guards light what they look at: a dark hiding spot is no longer safe from a search that looks into it.
- The yard patrols announce themselves from far away: the player can read their routes in the dark.
- See [perception-and-ai.md](../game/perception-and-ai.md), [light-and-visibility.md](../game/light-and-visibility.md), [mission-warehouse.md](../levels/mission-warehouse.md).
