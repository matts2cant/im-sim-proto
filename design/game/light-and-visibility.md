# Light and visibility

Milestone: M7 (Perception lab).

## Purpose

Light level affects how visible the player is to guards, computed analytically so it is testable headless.

## Player-facing behaviour

A HUD light indicator shows how lit the player is. Lights can be shot out; a breaker panel cuts lights.

## Rules

- Player light level is computed analytically: each relevant light's falloff x shadow rays to several body points.
- No render-based light gem ([ADR 0013](../decisions/0013-light-analytic.md)).
- Shootable lights; breaker panels cut lights (see [security.md](security.md)).
- The result feeds guard vision ([perception-and-ai.md](perception-and-ai.md)).
- Light level is shown in the debug Overlays tab ([debug-panel.md](debug-panel.md)).
- Logic is pure and unit-testable; scene queries are a thin adapter.

## Interactions

- Cloak augmentation: [abilities.md](abilities.md)
- Shootable lights take damage: [damage.md](damage.md)
- Perception lab room: [../levels/hub-and-gallery.md](../levels/hub-and-gallery.md)

## Open questions

- Number and placement of body sample points, falloff formula, ambient level, thresholds mapping light to detection: TBD in M7.
