# Conventions

## Naming and layout

- snake_case for files and folders; `class_name` in PascalCase.
- Test files: `<subject>_test.gd`, mirroring the source tree (`tests/core/stimulus/stimulus_system_test.gd`).
- Folders by feature, not by file type ([architecture.md](architecture.md)).

## Typing

- Statically typed GDScript everywhere.
- The `untyped_declaration` warning is set to error in project settings (addons excluded).
- `:=` inference is allowed.

## Design rules

- Composition over inheritance: behaviour in small component nodes attached to entities.
- Tuning data in `.tres` Resources (text, diffable).
- Pure logic in RefCounted/Resource classes; nodes are thin adapters.
- Exactly three autoloads: `StimulusSystem`, `EventLog`, `DebugPanel`.
- Signals for local events; stimuli for world events.
- Every stateful system is saveable (group `saveable`, `save_state()` / `load_state()`).

## Formatting and lint

- gdtoolkit 4.x: `gdformat` and `gdlint`, run by `tools/lint.sh` and the git pre-commit hook. Addons are excluded.
- LF line endings everywhere (`.gitattributes` enforces). Never write CRLF.
- Docs are in English.

## Git

- One feature branch per milestone (`m0-skeleton`, `m1-player`, ...), merged to `master` with `--no-ff` after tests and lint pass. Small fixes may go directly on master.

See [testing.md](testing.md) for test conventions and [../decisions/0030-code-conventions.md](../decisions/0030-code-conventions.md).
