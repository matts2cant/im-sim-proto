# Debug panel

Milestone: M0 (shell); tabs fill in as features land.

## Purpose

Debug tooling built from day one ([ADR 0009](../decisions/0009-debug-tooling.md)). `DebugPanel` is one of the three autoloads.

## Player-facing behaviour

Toggled with the ` key (QuoteLeft). Tabs:

| Tab | Content |
|---|---|
| Overlays | Sound radii/paths, vision cones, AI state labels, light level |
| Spawn | Objects, guards |
| Time | Time scale |
| Stats | Attributes, skills, augmentations, energy, body parts |
| Event Log | Live stimulus log, filterable; empties when the log is cleared |
| Player | Live speed, movement mode, grounded, crouched, floor surface, last footstep and landing loudness (M1) |

## Rules

- M0 delivers the panel shell; each tab becomes functional when the system it inspects lands (see the milestone table in [../README.md](../README.md)).
- Tuning in v0 lives in `.tres` files and this panel; there are no difficulty settings.
- The Stats tab is where skill and augmentation values are edited ([abilities.md](abilities.md)).
- The Event Log tab reads the `EventLog` autoload ([stimulus-response.md](stimulus-response.md)).
- Systems register their own tabs with `DebugPanel.register_tab()`; the Player tab is registered by the player and removed with it ([movement.md](movement.md)).

## Interactions

- [perception-and-ai.md](perception-and-ai.md), [light-and-visibility.md](light-and-visibility.md), [damage.md](damage.md), [attributes-and-tags.md](attributes-and-tags.md), [controls.md](controls.md)

## Open questions

- Which milestone first makes each tab functional beyond the shell: TBD per milestone.
