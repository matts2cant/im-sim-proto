# 132. Test suite speed pass: longest-first shards, kept navmesh bakes

Status: Accepted

Date: 2026-11-13

## Context

The full suite (2259 tests, 414 suites) took about 50 s of wall time at the start of M13 and 140 to 290 s by the end of M14. Measured on a quiet machine (24 logical cores, 5 % CPU load, the user's Godot editor idle):

- **Shard balance, not the suites, made most of it.** [ADR 0084](0084-parallel-fixed-fps-test-runner.md) cut the sorted suite list into contiguous slices, and a shard took at most ceil(unmeasured / shards) unmeasured suites. M14 added 18 suites, most of them in two folders: the forced breaks left four shards with 2 suites each (under 2 s) and four others with 90 to 101 s. The same suites balanced by recorded time fit in 48 s per shard.
- **Every hub load baked the navmesh again**: about 1 s of Recast voxelisation (cell size 0.05 m over the hub and its eight rooms; collecting the source geometry takes 0.13 s), on top of 0.2 s of set-up. About 80 hub loads run in a full run, and the game pays the same on every level reset, quickload and return from the mission.
- **A few suites simulated the whole hub to test one room**: the movement course walkthroughs loaded the hub nine times (39 s), the barricade burn simulated 31 s of the hub (16 s). An idle hub physics tick costs about 5.4 ms (guards 2.5 ms, character animators 1.1 ms); the course alone costs a fraction.

## Decision

1. **Longest first** (`tools/run_tests.sh`): unmeasured suites are dealt out first, each to the shard holding the fewest of them (heaviest estimate first), then the measured suites go longest first to the least loaded shard (LPT). Each shard still runs its suites in serial order and `reports/shards/<n>/suites.txt` still replays it. Shards are no longer contiguous slices: a suite can follow suites it does not follow in a serial run, so state leaking between suites must be fixed at its source (the existing rule).
2. **`LevelNavigation` keeps its bakes** for the running process: the last 4, keyed by the exact source geometry (vertices, indices, projected obstructions) and the bake settings. A hit assigns a copy of the kept navmesh (a new resource, so the region always registers the update); different geometry (a burnt barricade) bakes anew. This amends [ADR 0041](0041-runtime-navmesh-bake.md): the navmesh still always matches the geometry, it is only not voxelised twice for the same geometry.
3. **Tests about one room load the room**, with a player (and a `LevelNavigation` when they need paths), not the hub; the hub suites keep what is about the hub (the room behind its doorway, walking in from the hub, the hub's navmesh). Long simulations may pause components the game documents as visual only (`CharacterAnimator`) and, in a stripped level, components that cannot act there (body discovery with no bodies left); the measured outcome must not change (the patrol timing test prints the same laps and gaps).
4. Shared test waits: `tests/helpers/wait.gd` (`Wait.frames(tree, count)`) and `PlayerDriver.press(action)` replace the copies in about 50 suites and five helper scripts.

## Consequences

- See the report in [testing.md](../tech/testing.md) "Writing fast tests" for the numbers before and after.
- Order-dependent failures can appear in shard combinations that never ran before; replay the shard (`-j 1 $(cat reports/shards/<n>/suites.txt)`) and fix the leak.
- The bake cache is process-wide memory: four navmeshes (the hub's has about 1100 polygons).
- Not done (measured, too small to matter for the suite or a frame): `Device.graph()` rebuilt per query (0.4 ms in the hub, about 0.1 builds per physics tick at idle), `StimulusSystem._receivers_of()` filtering every receiver per ancestor (0.9 ms per contact or ray delivery in the hub, a few per second), `AwarenessBehaviour._on_navmesh()` asking two closest-point queries every tick (about 50 us per guard in the warehouse, 20 us in the hub).
