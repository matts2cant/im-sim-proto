# Debug panel

Milestone: M0 (shell); tabs fill in as features land.

## Purpose

Debug tooling built from day one ([ADR 0009](../decisions/0009-debug-tooling.md)). `DebugPanel` is one of the three autoloads.

## Player-facing behaviour

Toggled with the ` key (QuoteLeft). Tabs:

| Tab | Content |
|---|---|
| Overlays | "Stimuli" checkbox (M2): wire sphere per RADIUS stimulus, polyline per noise path and ray, colour per type (noise yellow, fire orange, damage red, others hashed), visible 1.5 s, drawn through walls. "Heat" checkbox (M3): a label above every Flammable and Explosive, drawn through walls: `heat 3.2 / 6.0` while cold, `BURNING  fuel 12.5 s` (`inf` for permanent fires), `charred`; barrels `heat x / 4.0 (explodes)`. Later: vision cones, AI state labels, light level |
| Spawn | (M3) One button per scene in `objects/object_catalog.tres`: spawns it 2 m in front of the player facing the same way (physics objects 0.7 m up so they drop onto the floor), logged `debug.spawned`. "Ignite looked-at": CONTACT `fire` of intensity 100 to the object under the crosshair (20 m ray). "Damage looked-at 10": CONTACT `damage.blunt` 10. "Reset level" (the only reset button; `LevelReset.reload_level`, shared with the death overlay): reloads the current main scene from its file (fires use objects up; playtests need a fresh room), drops stimuli still queued, logs `debug.reset_level {scene}` (`level.reset` from the death overlay), does nothing without a current scene, closes the panel; the time scale and the Event Log stay. (M4) The catalogue also has the medkit and the training dummy (it appears facing away from the player). Later: guards |
| Time | (M3) Time-scale slider 0.1-2.0 (step 0.05) and Reset to 1.0; sets `Engine.time_scale` (physics keeps its fixed 60 Hz step, game time slows or speeds up) |
| Stats | Attributes, skills, augmentations, energy, body parts |
| Event Log | Live stimulus log, filterable; empties when the log is cleared |
| Player | Live speed, movement mode, grounded, crouched, floor surface, last footstep and landing loudness (M1); what is carried and the carry limit (M3); body-part health and stun, `move_speed_mult`, equipped weapon, aim spread and stance (M4) |

## Rules

- M0 delivers the panel shell; each tab becomes functional when the system it inspects lands (see the milestone table in [../README.md](../README.md)).
- Tuning in v0 lives in `.tres` files and this panel; there are no difficulty settings.
- The Stats tab is where skill and augmentation values are edited ([abilities.md](abilities.md)).
- The Event Log tab reads the `EventLog` autoload ([stimulus-response.md](stimulus-response.md)).
- Overlays draw in the 3D world and stay visible while the panel is closed. The stimulus overlay (`ui/debug_panel/stimulus_overlay.gd`, `DebugPanel.stimulus_overlay`) only listens to `StimulusSystem.stimulus_processed`; core code holds no drawing logic.
- The Spawn and Time tabs and the Heat overlay (`ui/debug_panel/heat_overlay.gd`, `DebugPanel.heat_overlay`) are built in, like Overlays and Event Log. The Spawn tab finds the player through the `player` group.
- Systems register their own tabs with `DebugPanel.register_tab()`; the Player tab is registered by the player and removed with it ([movement.md](movement.md)).

## Interactions

- [perception-and-ai.md](perception-and-ai.md), [light-and-visibility.md](light-and-visibility.md), [damage.md](damage.md), [attributes-and-tags.md](attributes-and-tags.md), [controls.md](controls.md)

## Open questions

- Which milestone first makes each tab functional beyond the shell: TBD per milestone.
