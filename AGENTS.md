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
- `levels/hub/`, `levels/gallery/<room>/`, `levels/mission/`
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
```

Godot binary: env var `GODOT_BIN`, default `C:\Program Files\Godot\Godot_v4.7.2-stable_win64_console.exe`.
