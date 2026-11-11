# 52. Inventory pauses the game

Status: Superseded by [ADR 0110](0110-tab-interface.md) (the inventory is a tab of the Tab interface over the running world; only the game menu, briefing and summary pause)

Date: 2026-11-06

## Context

Deus Ex 1 pauses while the inventory is open. The alternative, real-time inventory management, adds tension but punishes a mouse-driven grid UI with no gamepad support. The datapad reading panel has the same question.

## Decision

- The inventory screen and the reading overlay pause the game: `get_tree().paused = true` while either is open. Both are CanvasLayers with `PROCESS_MODE_ALWAYS`; everything else (player, physics, stimuli, AI) pauses.
- `PauseScreens` (static helper, group `pause_screen`) tracks open screens: the first to open pauses and frees the mouse, the last to close unpauses and restores the previous mouse mode. Screens stack (a datapad read from the inventory sits on top of it).
- The inventory opens only when the player can act (alive, conscious, input enabled, debug panel closed). Closing calls `Player.resync_actions()` so the key that closed it (E, I, Esc) is not also a press in the game.

## Alternatives considered

- **Real time** (System Shock 2 style): more tension, but fiddly with drag and drop and unfair while guards search.
- **Slow motion while open**: still unfair, and physics/stimulus timing at low time scales complicates tests.
- **Pausing by disabling processing per system**: every new system would need to opt in.

## Consequences

- Tests pause the tree too: `PauseScreens.reset()` in `after_test` guards against a pause left by a failed test; `physics_frame` still fires while paused.
- The debug panel is `PROCESS_MODE_ALWAYS` already and keeps working while paused.
- Future menus (pause menu, M9 summary) join the same group.
