# Testing

Framework: GdUnit4 6.2.0. Tests are written alongside every feature; nothing merges without passing tests and lint.

## Three layers

1. **Unit**: all pure logic (rules, propagation math, AI transitions, inventory, attributes). No scene tree.
2. **Integration**: load small scenes headless, step physics a fixed number of frames, assert outcomes.
3. **Scenario**: assert EventLog chains in fixture scenes.

Game feel cannot be automated: see [playtest-checklist.md](playtest-checklist.md).

## Layout

- Tests mirror the source tree, e.g. `tests/core/stimulus/stimulus_system_test.gd`.
- File naming: `<subject>_test.gd`.
- `tests/scenarios/` holds scenario tests and their fixture scenes.

## Scenario tests and the EventLog

Every stimulus emit and receptron firing is written to the `EventLog` (tick, kind, source, target, data). A scenario test loads a fixture scene, triggers an initial event, steps the fixed tick, and asserts on the ordered chain in the log. Example: shot barrel, then crate_2 burning, then guard_1 investigating within 5 s.

Determinism comes from the fixed `_physics_process` tick and the next-tick queue ([architecture.md](architecture.md)).

## Commands

```sh
tools/run_tests.sh                       # all tests, headless
tools/run_tests.sh res://tests/core      # a subset
tools/lint.sh                            # gdformat --check + gdlint
tools/lint.sh --fix                      # format in place
```

The Godot binary comes from `GODOT_BIN`, defaulting to `C:\Program Files\Godot\Godot_v4.7.2-stable_win64_console.exe`.

A pre-commit hook (`tools/hooks`, installed by `tools/install_hooks.sh`) runs format and lint. CI is deferred until a GitHub remote exists.

See [../decisions/0011-testing-strategy.md](../decisions/0011-testing-strategy.md).
