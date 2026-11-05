# Controls

Milestone: M0 (input map); movement and look in M1; other actions added as features land.

## Purpose

Define the input scheme. Bindings are by physical key (QWERTY reference), so other layouts keep the same positions.

## Bindings

| Input | Action |
|---|---|
| W A S D | Move |
| Ctrl | Crouch (hold) |
| Shift | Sprint (hold, forward only) |
| Space | Jump / mantle (press facing a ledge, or hold in the air) |
| E | Use / pick up / carry |
| R | Reload |
| Q | Drop / throw |
| I | Inventory |
| 1-0 | Belt slots |
| F1-F4, F6 | Augmentations |
| F5 | Quicksave (M6) |
| F9 | Quickload (M6) |
| ` (QuoteLeft) | Debug panel |
| Mouse look | Look (captured mouse) |
| Esc | Release the mouse; click in the window to capture it again |
| LMB | Use item / fire |
| RMB | Alt |

## Rules

- Gamepad support and rebinding are parked: [../backlog.md](../backlog.md).
- Lean has no binding in v0.
- Crouch is hold-to-crouch; the player stays crouched while there is no headroom to stand ([movement.md](movement.md)).
- The mouse is captured while the player is active and the debug panel is closed; opening the panel frees it and closing restores the previous mode. Movement input is ignored while the panel is open.
- Mouse sensitivity (0.0025 rad per pixel) and the ±89° pitch clamp are in `actors/player/player_config.tres`.

## Interactions

- [movement.md](movement.md), [inventory.md](inventory.md), [abilities.md](abilities.md), [weapons-and-aiming.md](weapons-and-aiming.md), [saving.md](saving.md), [debug-panel.md](debug-panel.md)

## Open questions

- Which of F1-F4 and F6 maps to which augmentation: TBD in M6.
- Behaviour of RMB per item: TBD in M4/M5.
