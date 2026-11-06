# AGENTS.md

First-person immersive sim prototype (Deus Ex 2000 inspired), Godot 4.7.2, statically typed GDScript.
v0 = hub + test gallery (one room per system) + one small warehouse mission.
Design entry point: [design/README.md](design/README.md). Full spec lives in `design/`.

## Where things live

- `core/` framework only, no game content: `core/stimulus/`, `core/attributes/`, `core/event_log/`, `core/save/`
- `actors/player/`, `actors/guard/`
- `objects/` crates, barrels, doors, lights
- `items/`
- `ui/hud/`, `ui/debug_panel/`
- `levels/hub/`, `levels/gallery/<room>/`, `levels/mission/`; `levels/kit/` graybox kit parts: build levels from them ([design/levels/kit.md](design/levels/kit.md))
- `tests/` mirrors the source tree (`tests/core/stimulus/stimulus_system_test.gd`); `tests/scenarios/` for scenario tests and fixture scenes
- `tools/` scripts (`run_tests.sh`, `lint.sh`, `hooks/`); `design/` docs; `assets/` third-party media
- `addons/` gdUnit4, csg_blockout: never edit

## Code conventions

- Folders by feature, not by file type.
- snake_case files and folders; `class_name` in PascalCase.
- Static typing everywhere. `untyped_declaration` warning is an error (addons excluded). `:=` inference is allowed.
- Composition over inheritance: behaviour lives in small component nodes (`Flammable`, `Breakable`, `Health`, `StimulusReceiver`, `PerceptionSensor`) attached to entities.
- Tuning data goes in `.tres` Resources (text, diffable), not in code.
- Exactly three autoloads: `StimulusSystem` (added M2), `EventLog`, `DebugPanel`. Do not add more.
- Pure logic goes in RefCounted/Resource classes testable without the scene tree; nodes are thin adapters.
- Every stateful system is saveable (see below).
- LF line endings only. Never write CRLF.
- Details: [design/tech/conventions.md](design/tech/conventions.md), [design/tech/architecture.md](design/tech/architecture.md).

## Framework rules

- Signals = local events (parent/child, UI). Stimuli = world events that other entities may perceive or react to.
- Stimulus: type, intensity, origin, source, shape (radius | contact | ray). Emit via `StimulusSystem.emit()`.
- `StimulusReceiver` holds Receptrons (stimulus type, min/max intensity, required tags, blocked tags, effects[]). A match runs its Effects in order.
- Effects are Resources: add/remove tag, apply modifier, change attribute, emit stimulus, play cue. New effect = small Resource subclass.
- Emergence = effects emitting new stimuli. Guard perception is just another receiver.
- Stimuli emitted during processing are queued for the next fixed tick (`_physics_process`); no recursion; chain depth is tracked.
- Every emit and every receptron firing is written to the `EventLog` (tick, kind, source, target, data). Scenario tests assert on it.
- Attributes: `AttributeSet` + `Modifier` (add | multiply | override). Skills, augmentations and damage effects are modifiers.
- Saveable contract: nodes in group `saveable` implement `save_state() -> Dictionary` and `load_state(data: Dictionary) -> void`.
- See [design/game/stimulus-response.md](design/game/stimulus-response.md) and [design/game/attributes-and-tags.md](design/game/attributes-and-tags.md).

## Testing rules

- GdUnit4, three layers: unit (pure logic), integration (small scenes, headless, fixed physics frames), scenario (EventLog chains in fixture scenes).
- Write tests alongside every feature, in the same change.
- Nothing merges without passing tests and lint.
- Test files are named `<subject>_test.gd` and mirror the source tree.
- Game feel is manual: update [design/tech/playtest-checklist.md](design/tech/playtest-checklist.md).
- Details: [design/tech/testing.md](design/tech/testing.md).

## Godot version

- The engine is Godot 4.7.2. Your training data mixes Godot 3.x and older 4.x APIs and settings.
- Before using any engine class, method, signal or project setting not already used in this codebase, check the local reference: run `tools/gen_api_docs.sh` once if `.api-docs/` is missing, then grep `.api-docs/doc/classes/<ClassName>.xml` (project settings: `ProjectSettings.xml`).

## Definition of done

A task is done only when all of these hold:

1. `tools/run_tests.sh` and `tools/lint.sh` pass; new behaviour has tests in the same change.
2. Any scene or visual change is checked with `tools/screenshot.sh res://path/scene.tscn` and the PNG looked at (open it as an image). Report the PNG path.
3. Headless import and a run of the main scene print no errors from project code.
4. The relevant `design/` docs are updated; a new design decision has an ADR; `design/tech/playtest-checklist.md` lists the manual checks for new feel-related behaviour.
5. `git status --short | grep -v '\.import$'` shows only intended files.
6. Your report lists every deviation from the brief and why, plus any engine/addon warnings seen.

## Windows notes

- Shell is Git Bash. Use POSIX paths (`/c/Users/...`).
- gdformat writes CRLF on Windows; always format through `tools/lint.sh --fix` (it strips CR).
- New shell scripts: `#!/usr/bin/env bash` and tell the reviewer to set `git update-index --chmod=+x` (git does not track the executable bit here).
- Scenes saved via `ResourceSaver` lack `uid=` headers; that is fine, the editor adds them.

## Godot 4.7 / GdUnit4 gotchas

- `simulate_frames` waits for process frames, not physics frames: `await get_tree().physics_frame` N times for physics-driven tests.
- `runner.set_time_factor(n)` keeps physics delta at 1/60: safe for speeding up tests.
- A suite instance lives across its tests: reset member fields in `before_test`, and `EventLog.clear()` when asserting on the log (autoload state leaks between tests).
- gdlint `max-public-methods` (20) counts `test_` functions: split suites by concern.
- Collision shape sizes are float32: compare with `is_equal_approx`, not `==`.
- CSG collision is built a few frames after load: wait before querying it. `get_collider()` returns the CSG root that has `use_collision`.
- In the tree, `CSGShape3D.bake_collision_shape()` returns the last built shape (empty right after load, stale right after an edit); out of the tree it computes the current one.
- Kit parts' generated CSG children are internal: `get_children()` skips them; use `get_node("Block")` or `get_children(true)`.
- CharacterBody3D often reports no slide collision on flat floors: use a RayCast3D for the floor collider.
- Main-scene nodes enter the tree before autoloads run `_ready`: never call autoloads from `_enter_tree`.
- `find_children(..., owned=true)` on a freshly instanced scene still returns nodes of instanced sub-scenes.
- `.tscn` `Transform3D(...)` lists the basis **row by row** then origin: `Transform3D(x.x, y.x, z.x, x.y, y.y, z.y, x.z, y.z, z.z, ox, oy, oz)` where x/y/z are the basis axes (verified on 4.7.2). Prefer building one CSG root per surface/material.
- Level geometry must respect [design/levels/metrics.md](design/levels/metrics.md) (player size, clearances, jump and mantle limits).
- Git Bash: long multi-file heredoc chains can fail to parse; write files with the Write tool or one per command.
- Reusable test helpers: `tests/actors/player/player_driver.gd` drives the player in integration tests; reuse it instead of writing a new one.

## Workflow

- One feature branch per milestone (`m0-skeleton`, `m1-player`, ...), merged into `master` with `--no-ff` after tests + lint pass. Small fixes may go directly on master.
- Never download files or add dependencies without the user's OK.
- Do not edit `addons/`.
- Keep design docs in sync with code: update the relevant `design/` doc, and add an ADR in `design/decisions/` for any new design decision ([index](design/decisions/README.md)).
- Missing audio: use generated placeholder beeps; do not fetch sounds.
- Backlog items are out of scope: [design/backlog.md](design/backlog.md).

## Commands

```sh
py -3.12 -m venv .venv
.venv/Scripts/pip install -r tools/requirements-dev.txt
tools/install_hooks.sh                  # git core.hooksPath -> tools/hooks
tools/run_tests.sh [res://tests/core]   # GdUnit4 headless; optional path subset
tools/lint.sh                           # gdformat --check + gdlint, addons excluded
tools/lint.sh --fix                     # format in place
tools/gen_api_docs.sh                   # local Godot 4.7.2 API reference into .api-docs/
tools/screenshot.sh res://levels/hub/hub.tscn [frames] [out.png]  # render last frame to reports/screenshots/
```

Godot binary: env var `GODOT_BIN`, default `C:\Program Files\Godot\Godot_v4.7.2-stable_win64_console.exe`.
