# AGENTS.md

First-person immersive sim prototype (Deus Ex 2000 inspired), Godot 4.7.2, statically typed GDScript.
v0 = hub + test gallery (one room per system) + one small warehouse mission.
Design entry point: [design/README.md](design/README.md). Full spec lives in `design/`.

## Systemic design (core principle)

No hardcoded rules about specific things. Behaviour comes from systems that interact through tags, attributes, components and stimuli, so any entity with the right properties behaves the same way.

- Write rules about **properties, never identities**. Not "the explosive barrel explodes" but "anything `Explosive` explodes when its trigger is met"; the barrel is just a prop that has `Explosive`, `Flammable` and `Breakable` with tuning `.tres`.
- Never branch on an entity's name, scene path or concrete class (`if name == "Barrel"`, `is ExplosiveBarrel`, `"crate" in path`). Branch on a tag, component, attribute or stimulus.
- Systems talk through stimuli (or a component's public API found via the entity's tags or components), not by calling each other directly.
- The player is not special: fire, blasts, impacts, noise and damage reach the player through the same receivers and components as any NPC or prop. Player-only code is limited to input and camera.
- A new object that combines existing behaviours needs **zero new code**: only a scene composing components and `.tres` tuning. A new behaviour is a new component or Effect usable by any entity.
- Tests prove the generality: test a behaviour on a minimal entity built from its components (`tests/core/stimulus/stimulus_fixtures.gd`), not only on the one prop that ships with it, and write scenario tests for chains between systems.
- If a feature seems to need a special case, stop and describe it in your report instead of hardcoding it.

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

Fast-test checklist (the full suite runs in ~40 s; keep it there: [testing.md "Writing fast tests"](design/tech/testing.md#writing-fast-tests)):

- The runner simulates time (`--fixed-fps 144`): wait for physics frames, game time or a condition with a frame cap, never for a number of process frames standing in for time. A condition set by a worker thread (an asynchronous navigation iteration) gets a real-time cap instead (`GuardHelpers.async_iteration()`).
- Use small fixture scenes; load the hub only for hub tests, keep hub suites short (each load ~1 s, each simulated hub second ~0.3-0.6 s) and split big suites by concern.
- Switch navigation maps to synchronous iterations only with `GuardHelpers.use_sync_iterations()`, and `isolate_region()` against earlier suites' floors.
- Collect events that can happen inside a helper that clears the EventLog (`PlayerDriver.place()`) from `EventLog.entry_added`.
- Shards run in parallel processes: write files only under `user://`, reset autoloads in `before_test`, restore engine-wide settings in `after_test`.
- Iterate on a subset, run the full suite once at the end (once: each suite's own time is measured on that run and written to `reports/suite_times.tsv`; only the total wall time is skewed by new suites, so never rerun the suite to measure times); for a failure seen only in a full run, replay its shard (`-j 1 $(cat reports/shards/<n>/suites.txt)`) and fix the root cause, never retry.

## Tool use (right first time)

Measured over 14 agents (4288 tool calls, 62 failed, retrospective 2026-11-12): half the failures were the worktree sandbox refusing compound shell commands. Each failure costs a call and a retry.

- **One plain command per Bash call in a worktree.** The sandbox refuses what it cannot verify: heredocs (`python - <<'EOF'`, `cat <<EOF`), `for` loops, `cd`, `$(...)`, `&&`/`;` chains, `sed -i` with escapes. Use `git -C <absolute path>` instead of `cd`; create folders with a plain `mkdir -p <path>` call of its own.
- **Edit files with Read/Edit/Write**, not shell edits. For a scripted or repeated edit, Write a `.py` file into your scratch subfolder and run `py -3.12 -I <file>` (open files with `encoding='utf-8'`, write with `newline='\n'`); never inline Python in Bash (quotes like `'''` also break the shell).
- **Re-Read before Write or Edit** when a formatter (`tools/lint.sh --fix`), a generator or another process may have touched the file since you read it.
- **Lint before staging, as its own call**: `tools/lint.sh --fix`, then `tools/lint.sh`; never chain lint with `git add`/`git commit`. Watch the limits as you write: 1000 lines per file, 120 characters per line, gdlint's class order.
- **Read a non-zero exit before retrying**: `grep` with no match, `git commit` with nothing staged and a screenshot run that saved its PNG can all exit non-zero. Check `git status --short` before committing.
- **Never `sleep` in the foreground** to wait: run long commands with `run_in_background` and wait for the notification.
- **Sub-agents never call `update_plan` or `wrap_up`** (the main session's task list); report in your final message.

## Godot version

- The engine is Godot 4.7.2. Your training data mixes Godot 3.x and older 4.x APIs and settings.
- Before using any engine class, method, signal or project setting not already used in this codebase, check the local reference: run `tools/gen_api_docs.sh` once if `.api-docs/` is missing, then grep `.api-docs/doc/classes/<ClassName>.xml` (project settings: `ProjectSettings.xml`).

## Definition of done

A task is done only when all of these hold:

1. `tools/run_tests.sh` and `tools/lint.sh` pass; new behaviour has tests in the same change.
2. Any scene or visual change is checked with `tools/screenshot.sh res://path/scene.tscn` and the PNG looked at (open it as an image). Include first-person views at eye height (1.65 m) at every connection between parts (doorways, corridor ends, ledges), not only overview shots: seams and z-fighting only show up close. Level tests run `KitGeometry.coplanar_material_overlaps()`. Report the PNG paths.
3. Headless import and a run of the main scene print no errors from project code.
4. The relevant `design/` docs are updated; a new design decision has an ADR; `design/tech/playtest-checklist.md` lists the manual checks for new feel-related behaviour.
5. `git status --short | grep -v '\.import$'` shows only intended files.
6. Your report lists every deviation from the brief and why, plus any engine/addon warnings seen.

## Windows notes

- Shell is Git Bash. Use POSIX paths (`/c/Users/...`).
- gdformat writes CRLF on Windows; always format through `tools/lint.sh --fix` (it strips CR).
- New shell scripts: `#!/usr/bin/env bash` and tell the reviewer to set `git update-index --chmod=+x` (git does not track the executable bit here).
- Scenes saved via `ResourceSaver` lack `uid=` headers; that is fine, the editor adds them.
- Python on this machine defaults to cp1252: always open files with `encoding='utf-8'` (or set `PYTHONUTF8=1`), otherwise text like `·` or `×` silently fails to match or gets garbled.
- Screenshots from plain windowed runs may open at 840×648 despite `--resolution`; screenshot fixtures set the size with `DisplayServer.window_set_size(Vector2i(1152, 648))`.

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
- Git Bash: heredocs can fail to parse; write files with the Write tool (see "Tool use").
- Props scan world, objects and `static_actors` (layer 7), never the player or actors layers: a character whose body never moves by script (training dummy) also goes on layer 7 so props bounce off it; moving characters stay off it and push props through `BodyPusher` ([ADR 0070](design/decisions/0070-guard-combat-and-loadouts.md)).
- Fixtures freed with `auto_free` can still be in the tree during the next suite (a stale navigation region answers path queries): reuse `tests/actors/guard/guard_helpers.gd`, which waits for old fixtures and disables other regions. `PlayerDriver.place()` clears the EventLog after landing, so events during the landing are lost; the EventLog is a 2000-entry ring buffer.
- HUD/UI labels refresh in `_process`, which lags physics frames under a time factor: call the component's refresh (`Hud.refresh_overlay()`, `refresh_weapon()`, ...) before asserting, never rely on a bare `process_frame` await.
- Fixtures with navigation: place them far from the origin and from other suites' fixtures (existing ones use offsets like (±200, 0, 200/400)); a late-freed navmesh at the origin answers other suites' path queries.
- Guard test helpers: `tests/actors/guard/guard_helpers.gd` (guards in fixtures with sync navigation), `tests/actors/guard/combat_helpers.gd` (armed guard + hostile/ally stand-ins). Fixtures with guards need lamps: the player is only seen within 2 m at ambient light.
- Reusable test helpers: `tests/actors/player/player_driver.gd` drives the player in integration tests; reuse it instead of writing a new one. `tests/actors/common/character_fixtures.gd` builds minimal CharacterBody3D characters (walker controller, Tags, receiver, BodyParts and any of MovementNoise/FallImpact/Knockback/ImpactSensor) and floors. `tests/core/stimulus/stimulus_fixtures.gd` builds stimulus entities (Tags + Attributes + StimulusReceiver) in code.
- `await get_tree().physics_frame` resumes *before* that frame's `_physics_process` calls: a stimulus emitted from a test is delivered after the second await.
- Navigation maps iterate asynchronously by default: in tests call `NavigationServer3D.map_set_use_async_iterations(map, false)` (and the region's equivalent) or a freed region from the previous test can still answer path queries. Bake a `duplicate()` of a fixture's NavigationMesh: sub-resources are shared between instances. Switching a region to synchronous iterations after it already got its navmesh (LevelNavigation bakes in `_ready`) can lose the pending update for good: bake again after switching (`tests/actors/guard/guard_helpers.gd`). A map without polygons answers `map_get_closest_point()` with the origin: check `map_get_closest_point_owner()` is valid first.
- Rigid-body contacts (Jolt): with `contact_monitor` on, `PhysicsServer3D.body_get_direct_state(rid)` in `_physics_process` gives the last step's contacts and post-step velocity; keep the previous tick's velocity to measure an impact (see `ImpactNoise`).
- `for x: T in [a, b]` types the array literal: a freed object in it errors "invalid (previously freed?) object instance into a TypedArray". Stimulus sources are often freed before processing (a broken crate's noise): check `is_instance_valid` first.
- Jolt pairs a rigid body with a kinematic body (player, guards) only when the **rigid body's** mask has the kinematic body's layer. Props scan neither the player nor the actors layer (`PhysicsLayers.CHARACTER_LAYERS`), so the solver never shoves them with infinite mass; the `BodyPusher` component applies bounded push and weight instead ([ADR 0054](design/decisions/0054-player-and-physics-props.md), [ADR 0068](design/decisions/0068-awareness-states-and-guard-behaviour.md)). New kinematic actors follow the same rule.
- Guard tests: `tests/actors/guard/guard_helpers.gd` loads the guard fixture (`tests/scenarios/fixtures/guard_post.tscn`, optionally with the player) in a scene runner at time factor 9 with synchronous navigation, and builds tagged stand-in entities for noises and hits. Labels updated in `_process` may lag physics frames under a time factor: call the component's refresh in tests.
- Jolt `cast_motion` ignores an overlap at the start of the cast (returns [1, 1]): check the start with `intersect_shape` first.
- In a worktree, `tools/lint.sh` uses the main checkout's `.venv`: never link or copy `.venv` into a worktree (removing the worktree can delete the linked venv).
- `tools/screenshot.sh` forces a 1152x648 window (`SHOT_SIZE=WxH` overrides) because this machine's default 840x648 cropped the 2D layer; if UI shots still look wrong, save `get_viewport().get_texture().get_image()` from a fixture script (`tests/objects/fixtures/showcase/showcase_trigger.gd`).

## Engine probes

- When engine behaviour is uncertain (CSG timing, navigation map sync, physics frame order), write a 10–20 line `--script` probe **before** building on an assumption. It is far cheaper than debugging the full feature.
- Probes live in the scratchpad, not in `res://`, end with `quit()`, and run under `timeout 60 "$GODOT_BIN" --headless ...`. Never leave a Godot process running when you finish: check with `tasklist | grep -i godot`, but only stop processes you started (note their PIDs): other agents' test runs may be in progress and slow yours down.
- Windowed runs (screenshots, review shots): run them through `tools/run_windowed.sh <seconds> <godot args...>` (or `tools/screenshot.sh`, which uses it), never plain `timeout`: `timeout` only kills the `_console.exe` wrapper and leaves the Godot window open on the user's screen. Every screenshot fixture also quits itself on every path (shot saved, the scene closed before the shot, unknown shot name) and has a real-time watchdog (about 25 s) that saves what is shown and quits. After each windowed run, check `tasklist | grep -i godot` and stop the processes you started.
- Scratch files go in a private subfolder of the scratchpad named after your task (other agents share the scratchpad).
- After adding or renaming a `class_name`, the class cache must be refreshed: `tools/run_tests.sh` re-imports when a `class_name`/`extends` line or a non-script file changed; for ad-hoc runs use `--headless --import`.
- In an isolated worktree, compound shell commands are refused: see "Tool use".

## Workflow

- One feature branch per milestone (`m0-skeleton`, `m1-player`, ...), merged into `master` with `--no-ff` after tests + lint pass. Small fixes may go directly on master.
- Never download files or add dependencies without the user's OK.
- Do not edit `addons/`.
- When a change deletes or moves a resource, grep the whole project for its path and fix every reference in the same change.
- Keep design docs in sync with code: update the relevant `design/` doc, and add an ADR in `design/decisions/` for any new design decision ([index](design/decisions/README.md)).
- Missing audio: use generated placeholder beeps; do not fetch sounds.
- Backlog items are out of scope: [design/backlog.md](design/backlog.md).

## Commands

```sh
py -3.12 -m venv .venv
.venv/Scripts/pip install -r tools/requirements-dev.txt
tools/install_hooks.sh                  # git core.hooksPath -> tools/hooks
tools/run_tests.sh [res://tests/core]   # GdUnit4 headless in parallel shards (~40 s for all); optional subset
tools/run_tests.sh -j 1 res://tests/ui  # one Godot process, output streamed; -j N sets the shard count
TEST_FIXED_FPS=0 tools/run_tests.sh ... # real-time frames instead of simulated time; TEST_IMPORT=1 forces the import
tools/lint.sh                           # gdformat --check + gdlint, addons excluded
tools/lint.sh --fix                     # format in place
tools/gen_api_docs.sh                   # local Godot 4.7.2 API reference into .api-docs/
tools/screenshot.sh res://levels/hub/hub.tscn [frames] [out.png]  # render last frame to reports/screenshots/ (SHOT_TIMEOUT=60)
tools/run_windowed.sh 60 --path . res://path/fixture.tscn -- shot=x  # any windowed run: closes the window on timeout (exit 124)
```

Godot binary: env var `GODOT_BIN`, default `C:\Program Files\Godot\Godot_v4.7.2-stable_win64_console.exe`.
