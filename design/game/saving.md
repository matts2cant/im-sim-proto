# Saving

Milestone: contract in M0; F5/F9 in M6.

## Purpose

Every stateful system is saveable from day one so quicksave/quickload never needs retrofitting ([ADR 0025](../decisions/0025-saving.md)).

## Player-facing behaviour

F5 quicksave, F9 quickload (M6). Death leads to reload/restart ([../levels/mission-warehouse.md](../levels/mission-warehouse.md)).

## Rules

- Nodes in group `saveable` implement `save_state() -> Dictionary` and `load_state(data: Dictionary) -> void`.
- Save code lives in `core/save/`.
- Systems that must comply: attributes ([attributes-and-tags.md](attributes-and-tags.md)), inventory ([inventory.md](inventory.md)), health ([damage.md](damage.md)), AI ([perception-and-ai.md](perception-and-ai.md)), objects ([objects-and-fire.md](objects-and-fire.md)).
- Contract tests are written with each feature.

## Open questions

- File format and location, scene restoration approach, handling of the in-flight stimulus queue: TBD in M6.
