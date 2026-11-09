# Test speed: Kaizen report

Branch `test-speed`. Goal: the full suite reliably green in 2-3 min of wall time (stretch: under 1 min), measured end
to end on this machine (24 logical cores), without weakening any test. Result: **705 s median (often red) -> ~37 s
median, green in every full run since the fixes.** Runner design: [ADR 0084](../decisions/0084-parallel-fixed-fps-test-runner.md);
guidelines for agents: [testing.md "Writing fast tests"](testing.md#writing-fast-tests).

## Before and after

Wall time from the start of `tools/run_tests.sh` to its exit. "Other Godot" = Godot processes not started by the run
(sampled every 10 s).

| | Runs | Wall (median, spread) | Result | Other Godot |
|---|---|---|---|---|
| Before: master `0396bc8`, original runner (serial, real time, `tee`) | 3 | **705.1 s** (627.5-708.3) | 2 of 3 red (`door_test`, `network_overlay_test`) | none / another run for 110 s / 200 s |
| After: `test-speed`, final runner, no import needed | 4 | **36.9 s** (36.0-41.2) | 4 of 4 green, 1282 tests | none |
| After, with an import (first run after a merge) | 1 | 43.3 s | green | none |
| After, `TEST_FIXED_FPS=0` (real time, same shards) | 1 | 136.9 s | green | none |

Breakdown, before (base3, serial): import 7.7 + start-up 1.9 + scan 8.5 + suite prologues 13.4 + **test bodies 562.3** +
**between tests 82.0** + suite epilogues 13.8 + between suites 13.5 + end 1.0 + unattributed 0.7 = 705.1 s.

Breakdown, after (gate2, the runner's own `Timing:` line): total 36.2 s = before shards 1.3 s (import check, no import)
+ shards 34.5 s + after 0.4 s. The slowest shard (34.0 s) holds one suite: 30.9 s of suite + 3.1 s of start-up, scan
and shutdown. Fit over the 12 shards: ~3.5 s per shard + ~0.07 s per suite outside the suites. The critical path is now
the two biggest suites: `movement_course_test` (14 tests, each loading the hub, 35 s) and `hub_start_guards_test` (one
test simulating 60 s of the hub, 34 s).

## Actions and measured impact

| Action | Commit | Measured impact |
|---|---|---|
| Simulated time: `--fixed-fps 144` | fbdb681 | Idle headless frame 6.84 ms -> 0.05 ms (200 frames: 1366 ms -> 1.3 ms). Same final runner and shards in real time: 136.9 s vs 36-41 s |
| Parallel contiguous shards, own `user://` per shard, one merged summary, crashed shard fails the run | fbdb681, c6f2be2 | With fixed fps: 705 s -> 140 s on stale balancing; 68.4 s once balanced on fresh times (incl. a 9.4 s import) |
| Import only when a project file changed | fbdb681 | -7.2 to -11 s on runs without changes |
| Import stamp ignores script bodies and Markdown (only `class_name`/`extends`/`@tool`/`@abstract`/`@icon` lines of scripts) | this iteration | -7.2 s on every subset or full run after editing a test or a doc (verified: body edit and doc edit skip, a new `class_name` imports) |
| `--log-file NUL` for shards and import (test runs only) | 30a6666 | 68.4 s -> 66.0 s full run (within noise once output went to files; probe with stdout on a pipe: 500 prints 2.3-3.3 s -> 13-78 ms) |
| Shard output straight to a file instead of a pipe into gawk | 30a6666 | Pure-logic test 30-90 ms -> 9 ms (probe, same suite); full run 66.0 s -> 50.4 s on unchanged shard balancing |
| Balance on each suite's share of the wall time (GdUnit time + fitted per-suite overhead), median fallback | 30a6666 | 50.4 s -> 36-41 s (no import); slowest shard now bound by single suites |
| Results merged in one gawk pass, fork-free timestamps | 30a6666 | After-shards phase 3.5-5.5 s -> 0.3-0.4 s (each process costs ~50 ms in Git Bash) |
| `GuardHelpers.use_sync_iterations` (navigation map wedge) | 4ab3782 | Fixed `door_test` (~50 % red first in a process) and `barrel_chain_test` (see below) |
| `network_overlay_test` waits game time, not 30 process frames | 3852681 | Fixed the master failure (base3) |
| `barrel_chain_test` isolates its navmesh; regression suite `guard_helpers_test` | 11a56ff | Master's failure reproduced in 2 of 3 long serial runs with master's test files; 0 failures in 5 long serial runs and 9 full sharded runs on the branch |
| `guard_body_combat_test` collects the engagement from `EventLog.entry_added` | 77e8101 | Was a frame-exact race; green in every run since |

## Flaky tests: root causes

- **`barrel_chain_test`** (master: "index out of bounds at line 70", only in full runs). The previous suite left the
  navigation map asynchronous with an iteration running; switching it to synchronous at that moment wedges a Godot
  4.7.2 map (it never iterates again). The fixture's region never joined the map, so the noise path ran to the previous
  suite's floor 200 m away (`alarm_devices_test`'s yard) and back: longer than the 60 m noise, heard by nobody.
  Probe with a forced wedge: master's set-up 0/5 heard, `use_sync_iterations` 5/5. Natural reproduction with master's
  test files: 2 of 3 long serial runs failed exactly like master. The branch also isolates the region from late-freed
  floors. `tests/actors/guard/guard_helpers_test.gd` fails without the helper (3/3) and passes with it.
- **`guard_body_combat_test::test_a_woken_pistol_guard_engages_the_player`**: not a state leak. The woken guard sees
  the player 0-5 physics frames after `PlayerDriver.place()` starts, and `place()` clears the EventLog on frame 5. With
  master's helpers the engagement landed on frame 5, just after the clear (pass); the branch's `use_sync_iterations`
  adds two set-up frames and moved it to frame 3, before the clear (fail, alone and after any prefix: 8 bisection chunks
  and the full serial prefix, fixed and real time). Which side of the boundary it landed on depended on set-up frame
  counts, which depended on the previous suite (a wedge recovery adds frames). Collecting the entry from the signal
  removes the window.
- **`door_test`**, **`network_overlay_test`**: see the table (previous iteration).

## Verification

- Full suite with the final runner: 4 consecutive green runs (`Overall Summary: 1282 test cases | 0 errors | 0 failures
  | 0 flaky | 1 skipped | 0 orphans | 0 crashed shard(s) | 210 suites in 12 shard(s)`; the skip is
  `debug_panel_test`'s headless mouse-mode test, as on master), plus one green real-time run.
- Process-frame suites (`tests/ui`, `player_test`, `player_damage_test`, `augmentations_test`, `body_sight_test`,
  `security_wing_test`, `body_discovery_test`, `guard_body_combat_test`, `quicksave_hub_test`,
  `saveable_contract_test`): 3x green at `TEST_FIXED_FPS=144` (13.7 s each) and 3x green at `0` (19.4 s each).
- Runner behaviour: a failing test exits 100 with its message; a crashing shard (`OS.crash`) is reported with its last
  30 lines and exits non-zero; `-j 1` streams the output and prints one `Overall Summary`; subsets work.

## Open questions

- **Biggest suites bound the run** (~31-35 s of the ~37 s). Splitting `movement_course_test` (14 tests) into two suites
  by concern would let two shards share it (pure file split, no isolation change), but `hub_start_guards_test` (one
  60 s hub simulation) would still bound the run at ~34 s; going lower needs a shorter or smaller simulation, i.e. a
  test design decision. Left as is.
- **Re-using one loaded hub across a suite's tests** would cut ~1 s per hub test but changes test isolation: not done.
- `reports/suite_times.tsv` is machine-local: on a fresh checkout the first run balances on fallback weights (a few
  seconds slower).
- Up to 12 parallel Godot processes: two agents running full suites at the same time slow each other down more than
  with the serial runner.
