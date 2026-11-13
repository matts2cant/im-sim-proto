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

## Running tests

```sh
tools/run_tests.sh                              # all tests: ~60 s on this machine (12 parallel shards, 2263 tests)
tools/run_tests.sh res://tests/core             # a subset (folders and/or suite files)
tools/run_tests.sh -j 1 res://tests/ui          # one Godot process, output streamed as it runs
tools/run_tests.sh -j 1 $(cat reports/shards/3/suites.txt)   # replay one shard of the last run, in order
TEST_FIXED_FPS=0 tools/run_tests.sh ...         # real-time frames instead of simulated time (debugging)
TEST_IMPORT=1 tools/run_tests.sh ...            # force the project import
tools/run_tests.sh --dry-run                    # print the shard split (suite weights, * = estimated) and exit
tools/lint.sh                                   # gdformat --check + gdlint
tools/lint.sh --fix                             # format in place
```

The runner ([ADR 0084](../decisions/0084-parallel-fixed-fps-test-runner.md)):

- **Imports only when needed**: when a file was added, deleted or renamed, a file other than a script or Markdown changed, or a script's `class_name`/`extends`/`@tool`/`@abstract`/`@icon` line changed (the global class cache). Editing a test body skips the import (saves 7-9 s).
- **Splits the suites into parallel shards** (`-j N` or `TEST_JOBS`; default min(12, logical cores / 2)), longest first ([ADR 0132](../decisions/0132-test-suite-speed-pass.md)): each suite weighs its measured share of the wall time (`reports/suite_times.tsv`, rewritten after every run); unmeasured suites are dealt out first, each to the shard holding the fewest of them, then the measured ones go heaviest first to the least loaded shard, so the slowest shard ends close to the others. A suite with no recorded time counts as the median recorded time of the suites of its kind (scene runner or not) under its own folder, else under the nearest ancestor folder that has one, else of its kind, else 3 s / 0.5 s; dealing them out spreads a milestone's new suites side by side in one folder over the shards instead of one shard on a guess (M9f: four new 45-60 s route suites in one shard made the first run 165 s). Each shard runs its suites in serial order and is its own Godot process with its own `user://` (`reports/shards/<n>/appdata`) and report directory. (Until 2026-11-13 shards were contiguous slices of the serial order; after M14 the cap on unmeasured suites per slice left four shards almost empty and four at 90-101 s: 110 s of shards for 545 s of suites.)
- **Runs simulated time** (`--fixed-fps 144`): frames no longer wait for the wall clock. Physics still steps at 1/60 s, so physics-frame tests behave as before.
- Writes Godot's output straight to `reports/shards/<n>/output.log` (never through a pipe) and turns Godot's own log file off (`--log-file NUL`, test runs only).
- Prints the failures with their messages, one `Timing:` line (before shards, shards, after) with the slowest shard's breakdown, then **exactly one `Overall Summary: ... | exit N` line**. It exits non-zero on any failure, error, flaky retry, crashed shard (no summary: its last 30 lines are printed) or error from project code (`tools/test_error_allowlist.txt` lists the known engine noise). An `ERROR:`/`SCRIPT ERROR:` block counts as project code when its message or `at:` line names a `res://` path outside `res://addons/`, or when its `GDScript backtrace` has a frame there: an engine error such as "Removing a CollisionObject node during a physics callback" names only an engine `.cpp` file in its `at:` line, and the project script shows only in the backtrace. `reports/project_errors.log` lists them, one line per block with the project frames after ` | backtrace: ` (`tools/project_errors.awk`). Warnings (`push_warning`) never fail the run.

The Godot binary comes from `GODOT_BIN`, defaulting to `C:\Program Files\Godot\Godot_v4.7.2-stable_win64_console.exe`.

A pre-commit hook (`tools/hooks`, installed by `tools/install_hooks.sh`) runs format and lint. CI is deferred until a GitHub remote exists.

See [../decisions/0011-testing-strategy.md](../decisions/0011-testing-strategy.md).

## Writing fast tests

The full suite went from a 705 s median to ~40 s (1282 tests, [test-speed-kaizen.md](test-speed-kaizen.md)), grew to 110-290 s by M14 (2259 tests) and came back to ~58 s of shards (second pass, same report). These rules keep it there. Numbers were measured on this machine (24 logical cores, Godot 4.7.2).

**Where the time goes.** The slowest shard sets the pace: the shards are balanced longest first, so the wall time is about (sum of suite times) / shards plus ~5 s of start-up, unless one suite is longer than that. The longest is `hub_start_guards_test` (one test simulating 60 s of the hub: 15-20 s). A shard costs ~3-5 s to start (engine, autoloads, GdUnit scanning its suites) plus ~0.1 s per suite. A pure-logic test costs ~9 ms in total. The hub (2026-11-13): first load 1.1 s (resources, once per process), each load after it ~0.3 s with its navmesh bake kept (1 s more when the geometry changed), then ~5.4 ms per physics tick at rest (7 guards 2.5 ms, 17 character animators 1.1 ms); with 12 shards running, everything takes ~1.5 times as long.

1. **Wait for game time or a condition, never for a count of process frames.** With `--fixed-fps 144` a process frame is 1/144 s of game time (times the time factor), so a time factor `n` gives 2.4 process frames per physics frame at `n` = 1 and 0.27 at `n` = 9. Waiting "30 process frames" for a 0.25 s refresh was 0.21-0.5 s of game time in real-time runs (a coin flip) and is always too short at a fixed 144 fps (`network_overlay_test`). Await physics frames (`await get_tree().physics_frame`), a game-time duration (frames x 1/60 s), or poll a condition with a frame cap (`SaveHelpers.wait_for_load`). Label text refreshed in `_process` lags physics frames: call the component's refresh before asserting. The exception is a wait for a worker thread (a navigation map's asynchronous iteration): it takes real time, and a frame cap is only a few milliseconds at a fixed 144 fps, so a busy machine overran the 120-frame cap of `GuardHelpers.use_sync_iterations()` and a one-process full run failed (M9h). Poll such a condition every physics frame but cap it in real time (`GuardHelpers.async_iteration()`, `KitGeometry.wait_for_navigation()`).
2. **Time factors are safe**: `runner.set_time_factor(n)` keeps the physics delta at 1/60 s and only runs more physics steps per frame. Prefer them for long simulations over shortening the simulated time.
3. **Every frame of simulation costs CPU, even with fixed fps.** An idle hub physics frame costs ~5 ms, ~9 ms with its guards at work: 60 s of hub simulation took 34 s of wall time (`hub_start_guards_test`). Simulate only as long as the behaviour needs, and use a small fixture scene instead of the hub unless the test is about the hub.
4. **Heavy scenes cost per load**: loading the hub with `scene_runner` takes 0.9-1.4 s, then ~5 ms per physics frame. A scene that is still in the tree keeps simulating: with three hubs alive, 60 physics frames took 2.5 s instead of 0.3 s. Let the runner free scenes between tests (do not keep extra references); new heavy suites should keep their test count small or split by concern into several suites (shards can run them in parallel; one suite always runs in one process).
5. **Prints are cheap now, but do not log per frame.** With stdout on a pipe each flushed `print()` stalled Godot (a pure-logic test took 30-90 ms instead of 9 ms); the runner writes to a file, but thousands of prints still fill the shard logs.
6. **Navigation**: bake a `duplicate()` of a fixture's NavigationMesh; switch the map to synchronous iterations only through `GuardHelpers.use_sync_iterations(map, region)` (switching while an asynchronous iteration runs wedges a Godot 4.7.2 map for good: path queries then use a stale map, see `tests/actors/guard/guard_helpers_test.gd`; the helper also waits, capped in real time, for the region's own build on a worker thread, without which the map iterates without the region's polygons), and `GuardHelpers.isolate_region()` against late-freed floors of earlier suites. Place navigation fixtures far from the origin and from other suites' fixtures.
7. **Do not assert on log entries that can happen while a helper clears the log.** `PlayerDriver.place()` clears the EventLog after the 5 frames it waits; an event during those frames (a guard that sees the player at once) is lost. Collect such events from `EventLog.entry_added` before calling the helper (`guard_body_combat_test`).
8. **Parallel safety**: shards are separate processes, so autoload state and node positions never leak between shards, but within a shard suites still run one after another in one process. Write files only under `user://` (each shard has its own; never into `res://`, which all shards share), reset autoload state (`EventLog.clear()`, `StimulusSystem.clear()`, `DebugPanel.set_open(false)`) in `before_test`, restore engine-wide settings you change (map async iterations, `Engine.time_scale`, `Input.mouse_mode`) in `after_test`, and never open fixed network ports. Shards are filled longest first, so a suite can follow suites it never follows in a serial run (or in the last run): a suite must leave nothing behind for the next one (free its scenes, restore what it changed).
9. **Iterate on a subset** (`tools/run_tests.sh res://tests/<area>` or the suite files you touched, 4-15 s) and run the full suite once at the end. Never stop a running suite mid-way; it leaves Godot processes and half-written reports.
10. **A test that fails only in a full run** is order-dependent: replay its shard in order (`tools/run_tests.sh -j 1 $(cat reports/shards/<n>/suites.txt)`), then bisect that list. Fix the leak or the race at its source (it was a wedged navigation map or a frame-exact race every time so far), never with retries: GdUnit's flaky retry must stay off and the runner fails a run that reports flaky tests.
11. **Load a heavy level once per suite when its tests only query it** (navmesh paths, rays, light levels, node checks): load it in `before()` and free it with the suite (`WarehouseHelpers.load_for_queries()`); a test that changes the level (opens a door, cuts a breaker) runs last or restores what it changed. Skip `LevelNavigation`'s bake at load (`bake_on_ready = false` before adding the level) when no test walks a path, and bake once on the synchronous map when they do. A map without polygons answers `map_get_closest_point()` with the origin, so wait for `map_get_closest_point_owner()` to be valid, not for a probe at the origin. The warehouse suites went from about 126 s to 58 s this way ([ADR 0092](../decisions/0092-warehouse-polish.md)).
12. **Check a timing-sensitive test under both clocks** when it waits on process frames, UI refreshes or timers: `TEST_FIXED_FPS=0 tools/run_tests.sh <suite>` as well as the default.
13. **A test about one gallery room loads the room, not the hub**: the room scene with a player (and a `LevelNavigation` when it needs paths) in a small fixture (`tests/levels/gallery/movement/fixtures/course_with_player.tscn`, `tests/levels/gallery/physics_fire/fixtures/room_with_player.tscn`). Keep in the hub suite only what is about the hub: the room behind its doorway, walking in from the hub, the hub's navmesh. The movement walkthroughs went from 39 s (nine hub loads) to 7 s, the barricade burn (31 s simulated) from 16 s to 2 s.
14. **Long simulations pause what cannot change the outcome**, and say why in a comment: components the game documents as visual only (`CharacterAnimator`), and in a stripped level, components with nothing to act on (body discovery with no bodies, light exposure with no one looking). Check that the measured outcome stays the same (`warehouse_patrol_timing_test` prints the same laps and gaps at 8 s instead of 14 s). A simulation that waits for something to settle asserts that it did settle at the end (`hub_start_guards_test`: every guard unaware again), so a longer opening fails instead of passing unseen.
15. **Share the waits**: `Wait.frames(get_tree(), n)` (`tests/helpers/wait.gd`) and `PlayerDriver.press(action)` (hold 2 frames, wait 1); do not copy a `_frames()` or `_press()` into a new suite.
16. **Probes with a time factor set both** `Engine.physics_ticks_per_second` and `Engine.time_scale`, as `runner.set_time_factor()` does: `Engine.time_scale` alone makes every physics tick 4/60 s of game time, and a probe of 3600 ticks then measures 240 s of the level, not 60.

## Route scenario tests (dropped)

Scripted end-to-end routes through a whole populated level were dropped ([ADR 0106](../decisions/0106-drop-scripted-warehouse-route-tests.md), superseding [ADR 0093](../decisions/0093-warehouse-route-tests.md)): they drove the player through every area with live guards and combat, broke on almost every tuning change and cost hours to repair. Test the level in pieces instead: passage tests that step off every climb onto the destination floor, noise spot checks (one entry, one guard set), and each system in isolation. Full routes are checked by hand ([playtest-checklist.md](playtest-checklist.md) "Warehouse routes (by hand)"). `tests/levels/mission/warehouse_route_driver.gd` and `warehouse_route_hands.gd` stay as the helpers of the remaining warehouse suites that drive the real player (waypoint moves, climbs, carrying, aiming the camera ray and pressing E).

## Deterministic physics tests

- Drive physics with a fixed number of physics frames (`await get_tree().physics_frame`), never wall-clock time. `runner.set_time_factor(n)` is safe (delta stays 1/60). The runner simulates time (`--fixed-fps 144`): see "Writing fast tests".
- Reset suite member fields in `before_test`; call `EventLog.clear()` before asserting on the log.
- Fixture scenes live next to the tests (`tests/<area>/fixtures/`). Wait a few frames after loading CSG before relying on its collision.
- Reuse drivers: `tests/actors/player/player_driver.gd` presses actions and steps frames for the player.
- See the gotcha list in [AGENTS.md](../../AGENTS.md).
