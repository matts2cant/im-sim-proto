# Test speed: Kaizen iteration 1 (interim report)

Branch `test-speed`, worktree `agent-ae174401d8817ba67`. Status: **stopped part-way, not merged**.
Most runner changes are committed but have **not yet passed the 3x full-suite rule** (see "Verified vs not").
Goal from the brief: full suite under 1 min (stretch), under 5 min (must).

## 1. Problem

A full `tools/run_tests.sh` run takes 10-12 min of wall time on this machine (user: ~9 min; chief engineer: 12.5 min
and 723 s), while the per-suite times GdUnit reports add up to much less. Every agent pays this at least once per
task, more when it iterates on the full suite instead of a subset.

## 2. Measurements

All runs on this machine (24 logical cores). "Other Godot" = Godot processes not started by the run, sampled every 10 s
with `tasklist` (each Godot run shows up as 2 processes: a console wrapper and the engine).

### Baseline: master `0396bc8`, original runner, measured end to end (3 runs)

| Run | Wall | Result | Other Godot during the run |
|---|---|---|---|
| base1 | 627.5 s | 3 failures (`door_test` noise path `straight_fallback`) | none (one 10 s sample) |
| base2 | 708.3 s | green | another run during ~110 s |
| base3 | 705.1 s | 1 failure (`network_overlay_test`) | another run during ~200 s |

**Median 705.1 s, spread 627-708 s (81 s).** Two of three master runs were red from flaky tests (both explained and
fixed below).

Breakdown of the median run (base3), from per-line timestamps of the runner's output; rows add up to the wall time:

| Part | Seconds |
|---|---|
| import (always run by the original runner) | 7.7 |
| launch (`runtest.sh`, `godot --version`) | 0.3 |
| engine and autoload start-up | 1.9 |
| GdUnit init + scanning `res://tests` (loads every suite script and its preloads, parses it) | 8.5 |
| suite prologues (suite load, `before()`) | 13.4 |
| **test bodies** (STARTED -> PASSED, includes `before_test`/`after_test`) | **562.3** |
| **between tests** (GdUnit gc, orphan checks, reporting) | **82.0** |
| suite epilogues (`after()`, orphan check) | 13.8 |
| between suites | 13.5 |
| reports, shutdown, error scan | 1.0 |
| (unattributed) | 0.7 |
| **total** | **705.1** |

base1 (no other Godot): import 11.0, start-up 1.9, scan 12.5, prologues 13.4, bodies 480.9, between tests 78.8,
epilogues 12.6, between suites 14.4, end 1.1 = 627.5 s.

Top-20 costs (base1, suite wall time, serial real time):

| # | Suite | s | | # | Suite | s |
|---|---|---|---|---|---|---|
| 1 | objects/stack_support_test | 30.9 | | 11 | actors/common/knockback/knockback_test | 8.9 |
| 2 | levels/gallery/movement/movement_course_test | 23.0 | | 12 | actors/player/player_movement_test | 8.8 |
| 3 | levels/hub/hub_start_guards_test (1 test, 60 s simulated) | 20.5 | | 13 | actors/common/body/downed_pose_test | 8.4 |
| 4 | objects/alarm/alarm_devices_test | 19.2 | | 14 | actors/player/player_crate_stack_test | 7.9 |
| 5 | levels/gallery/physics_fire/physics_fire_hub_test | 15.8 | | 15 | scenarios/guard_awareness_test | 7.6 |
| 6 | core/save/saveable_contract_test | 14.0 | | 16 | levels/gallery/physics_fire/physics_fire_scenarios_test | 7.3 |
| 7 | scenarios/alarm_devices_test | 12.7 | | 17 | actors/common/movement/fall_impact_test | 7.1 |
| 8 | objects/door/door_test | 10.2 | | 18 | levels/gallery/ai_arena/ai_arena_hub_test | 7.0 |
| 9 | scenarios/quicksave_hub_test | 9.8 | | 19 | objects/camera/security_camera_test | 7.0 |
| 10 | actors/common/movement/step_climber_test | 9.7 | | 20 | objects/turret/turret_test | 6.8 |

Most of the bodies were real-time waits: a test that steps 300 physics frames at time factor 1 took 5.0 s
(`stack_support_test`: six such tests). Overhead outside the bodies was ~123 s (between tests, prologues, epilogues,
between suites), i.e. ~100 ms per test.

### Current runner (branch, after merging master), 1 full run so far

`cur1`: **140.4 s wall**, 1222 tests, 1 failure (order-dependent test, fixed afterwards, see below), 11 shards,
no other Godot at the start, another run at the end.

| Part | Seconds |
|---|---|
| before shards (import: yes, the project had changed) | 9.0 |
| shards (the slowest shard sets the pace) | 125.7 |
| after shards (result merge, error scan) | 3.4 |
| **total** (runner's own clock) | **138.1** |

Slowest shard (shard 0, 63 suites, 458 mostly unit tests): start-up 2.8 + scan 3.8 + suites 112.2 (test bodies 53.5,
**around tests 58.7**) + between suites 6.1 + reports/shutdown 0.6 s. The other shards took 17-74 s: the shards were
badly balanced because `reports/suite_times.tsv` held stale real-time suite times from before the merge (it is
rewritten after every run, so the next run balances on fixed-fps times).

### What the per-test overhead is (probes, not yet acted on)

- An empty test costs ~80 ms and a pure-logic test ~170 ms in a GdUnit run, with or without `--fixed-fps`. Marks
  printed from `before_test`, the body and `after_test` were 15 ms apart while `Engine.get_process_frames()` did not
  change: the time goes into **`print()` itself**, not into frames.
- 500 `print()` calls from a headless Godot (ms, 3 runs each):

  | stdout goes to | Godot log file on (default) | `--log-file NUL` (no log file) |
  |---|---|---|
  | `/dev/null` | 1.6 | 0.5 |
  | a file | 535-613 | 538-554 |
  | a pipe into `cat` | 2301-3334 | 13-78 |
  | a pipe into `gawk` (what the runner does) | 58-1244 (other runs: up to 6447) | 5-22 |

  So with stdout on a pipe and Godot's own log file (`user://logs/godot.log`, on by default on desktop and flushed
  every line in debug builds), each print costs 2-13 ms. GdUnit prints several lines per test (STARTED, PASSED, blank
  lines), and the original runner piped through `tee` too, so this cost is in the baseline as well. The log file is a
  duplicate of what the runner already saves (`output.log`); GdUnit collects errors through `OS.add_logger`, not from
  that file. `--log-file NUL` makes Godot refuse the reserved device name (one `ERROR: Failed to open log file for
  writing: NUL` line at start-up, no `res://` path, so the error scan ignores it) and log to stdout only.
- With `--fixed-fps` a headless frame no longer sleeps: 0.05 ms per idle frame vs 6.84 ms in real time
  (Godot sleeps `low_processor_usage_mode_sleep_usec` = 6900 us per headless frame otherwise). Confirmed by probe.

## 3. Goal

- **Under 5 min: reached** (140 s on the first run of the current runner, from a 705 s median).
- **Under 1 min: realistic, not reached yet.** Estimate (not measured): removing the print cost should cut most of the
  ~59 s "around tests" of the heaviest shard and part of every test body; with balanced shards the slowest shard
  should drop to ~30-40 s, bounded below by the biggest single suites (`movement_course_test`, `hub_start_guards_test`:
  20-30 s each, one 60 s simulation in the latter) plus ~6 s of start-up and scan; with the import skipped (nothing
  changed) the total would be ~40-50 s. A run right after a merge adds the import (8-11 s).

## 4-5. Changes and measured impact

| Commit | Change | Impact (measured) | Verified? |
|---|---|---|---|
| fbdb681 (previous agent) | `--fixed-fps 144`: simulated time no longer waits for the wall clock (physics delta stays 1/60 with any time factor; 2.4 process frames per physics frame at time factor 1, as in a lightly loaded real-time headless run) | Test bodies: 481-562 s serial -> ~300 s summed over shards (cur1); frame sleep 6.84 -> 0.05 ms | 1 full run (cur1) only |
| fbdb681 | Import only when a project file changed (stamp of paths, sizes, mtimes, Godot path; `TEST_IMPORT=1` forces) | -7.7 to -11 s on runs with no change | not measured on a full run yet |
| fbdb681, c6f2be2 | Contiguous parallel shards (`-j N`, `TEST_JOBS`; auto = min(12, cores/2)), each with its own `user://` (APPDATA) and report dir, balanced on last suite times; one merged "Overall Summary"; a shard without a summary counts as crashed and fails the run | 705 s -> 140 s together with fixed fps (cur1) | 1 full run |
| 4ab3782 | Navigation maps switched to synchronous iterations safely (`GuardHelpers.use_sync_iterations`): Godot 4.7.2 wedges a map switched while an async iteration runs | Fixes `door_test` failing ~50% when first in a process; this is the base1 failure on **master** | targeted runs by the previous agent; not 3x full |
| 3852681 | `network_overlay_test` waits 1.5 refresh periods of game time instead of 30 process frames | Fixes the base3 failure on **master** (30 headless frames = 0.21-0.5 s vs a 0.25 s refresh; always failed at fixed 144 fps) | `res://tests/ui/debug_panel` green once |
| 77e8101 | `guard_body_combat_test`: the woken guard's engagement is collected from `EventLog.entry_added`, because it can engage during the 5 frames `PlayerDriver.place()` waits and `place()` then clears the log | Was red alone and after `guard_awareness_test` in both fixed and real-time mode (4/4 runs), green only after the earlier suites of a serial run; now green 3/3 (alone and in the pair) | targeted 3x |
| 8a80dbd | Runner timestamps every shard's output (`timed.log`, gawk `gettimeofday`) and prints a breakdown per shard (`tools/test_timing.awk`, `reports/shards/<n>/timing.txt`) | Measurement only; cost not measurable | used on cur1 and subsets |

Rejected or parked ideas:

- `override.cfg` in the project root to turn off the log file or stdout flushing for test runs: Godot also reads it
  when the user starts the game from the editor in the same checkout, and a crashed run could leave it behind.
- Turning off `debug/file_logging/enable_file_logging.pc` in `project.godot`: also works, but the game would lose its
  `godot.log` too. Needs the user's OK; `--log-file NUL` does the same for test runs only.
- `--quiet`: silences GdUnit's own output, including the summary the runner needs.
- A lower fixed fps (60): fewer process frames per physics frame than a real-time run; changes what UI tests prove.
- Re-using one loaded hub across the tests of a suite: big gain for hub suites but changes test isolation; ask first.

## Verified vs not

- **Not yet verified by the 3x full-suite rule:** everything in the runner (fixed fps, sharding, import stamp,
  timestamps) and the two navigation/overlay fixes. Only one full run (cur1) exists after the merge, and it was red on
  the order-dependent test fixed since.
- **Not done:** targeted 3x runs of the suites that rely on process frames under `--fixed-fps` (HUD tests,
  `tests/ui/`, `player_test`, `security_wing_test`, `quicksave_hub_test`, `save_test_helpers` users,
  `spawn_tab_test`, `game_menu_test`), each also with `TEST_FIXED_FPS=0` to compare.
- Fixed fps makes the process/physics frame ratio deterministic (real-time headless runs gave fewer process frames per
  physics frame under load), so a test that passes at fixed fps should keep passing; a test counting process frames to
  wait out game time (like the overlay test) fails deterministically instead of at random.
- **Open question:** `guard_body_combat_test` passing only after the earlier suites of a serial run means some earlier
  suite leaks state that slows a guard's engagement (a mutated shared resource, a static, an autoload). Not found yet.

## Current state of the runner (`tools/run_tests.sh` on `test-speed`)

```sh
tools/run_tests.sh [-j N] [res://path ...]   # N parallel shards, default min(12, logical cores / 2)
TEST_JOBS=N                                    # same as -j
TEST_IMPORT=1                                  # force the import (else only when files changed)
TEST_FIXED_FPS=144                             # simulated frames per second; 0 = real time
```

Prints the failed tests with messages per shard, one `Timing:` line (before shards + shards + after), the slowest
shard's breakdown, then one `Overall Summary: ... | exit N` line; exits non-zero on any failure, crashed shard or
project script error. `tools/run_tests.sh -j 1 $(cat reports/shards/<n>/suites.txt)` replays one shard in order.

## Todo for the next iteration (ordered by gain / effort)

1. **`--log-file NUL` on the shard command (and the import).** Gain: estimated 30-60 s off the slowest shard as it
   stands (its 58.7 s "around tests" plus part of the bodies), ~100 ms per test everywhere; probe measured 50-500x
   cheaper prints. Risk: low; the one start-up `ERROR` line must stay out of the error scan, and nothing may read
   `user://logs/godot.log`. Check: 3x full green, a crashing shard still fails the run with its last lines shown.
2. **Run the 3x full-suite check** of the current branch (after item 1) with fresh `suite_times.tsv`, recording wall
   time, `Timing:` lines and other Godot processes; plus the targeted 3x runs of the process-frame suites listed above
   with `TEST_FIXED_FPS=144` and `0`. Gain: none directly; it is the gate for merging. Effort: ~15 min of runs.
3. **Balance shards on wall time** (`timed.log` suite wall incl. overhead, which `tools/test_timing.awk` can emit)
   instead of GdUnit's suite time, and check the slowest shard is not more than ~10% over the average. Gain: estimated
   20-80 s (cur1's slowest shard was 125.7 s with others at 17-74 s). Risk: low. Check: per-shard `timing.txt`.
4. **"Writing fast tests" section in `design/tech/testing.md`, a short checklist in AGENTS.md, ADR 0084, Commands
   section update.** Content: what costs most (prints with a log file, real-time waits, hub loads per test, scans);
   fixed fps and time factors keep the 1/60 delta; wait for conditions or game time, never for a count of process
   frames standing in for time; navmesh: `GuardHelpers.use_sync_iterations` and bake a `duplicate()`; parallel safety
   (each shard has its own `user://`, fixtures far apart, autoload state reset in `before_test`, `place()` clears the
   EventLog); iterate on subsets, run the full suite once at the end; pitfalls found here. Gain: prevents regressions.
5. **Find the state leak behind `guard_body_combat_test`'s order dependence** (bisect the suites before it in serial
   order with `-j 1`). Gain: correctness, not speed. Risk: may reveal more order-dependent tests.
6. **Heaviest suites** (`movement_course_test` 14 tests each loading the hub, `physics_fire_hub_test`,
   `hub_start_guards_test` 60 s of simulated hub): load the hub once per suite or use smaller fixtures. Gain: estimated
   10-20 s of the critical path once shards are balanced (these bound the slowest shard). Risk: changes isolation; ask
   the chief engineer first.
7. **GdUnit scan** (8.5-12.5 s serial; spread over shards now, 0.3-3.8 s each) and **start-up** (~2.1-2.8 s per shard,
   in parallel): small; leave unless the goal is missed by a few seconds.
8. **Import stamp**: confirm with a full run that an unchanged project skips the import and a new `class_name` after a
   merge still triggers it. Gain: 8-11 s per run without changes (measured import time).

## Measurement tools used

Scratch (not committed): `bench.sh` (wall time, per-line timestamps, Godot process samples) and `analyze.py` (the
breakdown table above). The runner now writes `reports/shards/<n>/timed.log` and `timing.txt` itself.
