# 84. Test runner: parallel shards, simulated time, output to files

Status: Accepted (amends [ADR 0011](0011-testing-strategy.md))

Date: 2026-11-09

## Context

A full `tools/run_tests.sh` took 10-12 min on this machine (median 705 s, 627-708 s, master `0396bc8`), and two of three master runs were red from order-dependent tests. Every agent runs the full suite at least once per task. Measured causes: test bodies waited for the wall clock (a headless Godot sleeps ~6.9 ms per frame, so 300 physics frames at time factor 1 took 5 s); one Godot process ran 1200+ tests in series; every flushed `print()` into the MSYS pipe that read Godot's output stalled the process (a pure-logic test took 30-90 ms instead of 9 ms); the import ran on every run (7-11 s).

## Decision

`tools/run_tests.sh` keeps its interface (`[res://path ...]`, one `Overall Summary` line, non-zero exit on any failure) and changes how it runs GdUnit4:

- **Simulated time**: Godot runs with `--fixed-fps 144` (`TEST_FIXED_FPS`, 0 = real time). Each frame advances 1/144 s of game time (times `Engine.time_scale`) without waiting for the clock; physics still steps at 1/60 s, so physics-frame tests and time factors behave as before. 144 keeps the process/physics frame ratio of a lightly loaded real-time headless run (2.4 at time factor 1, 0.27 at 9). Tests must wait for game time or conditions, never for a number of process frames standing in for time.
- **Parallel shards**: the suites (sorted as GdUnit sorts a folder) are cut into `-j N` contiguous slices (default min(12, logical cores / 2)), balanced on each suite's measured share of a shard's wall time (`reports/suite_times.tsv`: GdUnit's suite time plus the per-suite overhead fitted across the shards of the last run; unknown suites count as the median of their kind). Contiguous slices keep every shard a run of the serial order, so a suite never meets predecessors it does not meet in a serial run. Each shard is its own Godot process with its own `user://` (APPDATA) and report directory.
- **Output to files**: each shard writes stdout and stderr straight to `reports/shards/<n>/output.log`; nothing pipes Godot's output. `-j 1` streams the file with `tail`. Godot's own log file is off for test runs (`--log-file NUL`; on other systems `/dev/null`); `project.godot` and the game's logging are unchanged.
- **Import only when needed**: a stamp of every file's path, the size and mtime of every file except scripts and Markdown, and each script's `class_name`/`extends`/`@tool`/`@abstract`/`@icon` lines (what the global class cache is built from); `TEST_IMPORT=1` forces it.
- **Results**: one gawk pass merges the shards (`tools/test_results.awk`): failures with messages, a line per shard, totals. A shard without GdUnit's summary crashed and fails the run with its last 30 lines; a flaky count fails the run (GdUnit's retry must stay off); script errors from project code fail it as before. `tools/test_timing.awk` prints the `Timing:` breakdown from GdUnit's XML reports and records the suite times.

Tests that switch a navigation map to synchronous iterations do it through `GuardHelpers.use_sync_iterations()`: switching while an asynchronous iteration runs wedges a Godot 4.7.2 map for good (it never iterates again, path queries use the stale map). This made `door_test` and `barrel_chain_test` fail depending on the previous suite; the helper detects the wedge and lets the pending iteration land first.

## Consequences

- Full suite: ~36-41 s without an import, ~43 s with one, green in 4 consecutive runs (from a 705 s median, often red). Real time (`TEST_FIXED_FPS=0`) with the same shards: 137 s. The slowest shard is now bound by the two biggest suites (`movement_course_test` 35 s, `hub_start_guards_test` 34 s).
- A test that counts process frames to wait out game time fails deterministically at fixed fps instead of at random (`network_overlay_test` was fixed this way). UI and HUD suites were run 3x at fixed and real-time fps, green both ways.
- Godot prints one `ERROR: Failed to open log file for writing: NUL` (and a WARNING) at start-up of every shard; the error scan ignores lines without a `res://` path.
- Up to 12 Godot processes run at once; other agents' runs on the same machine slow each other more than before.
- `reports/suite_times.tsv` is machine-local and rewritten after every run; it is not committed. Without it the first run balances on fallback weights and is a few seconds slower.
- Guidelines for writing fast, parallel-safe tests: [testing.md](../tech/testing.md) "Writing fast tests".
