# Retrospectives

After every milestone the chief engineer reviews what the sub-agents did and what went wrong, then changes the process (tools, tests, AGENTS.md, CLAUDE.md, a request to the user) so the same problem does not repeat. Newest first.

Format per milestone: **What went well**, **What went wrong**, **Changes made**, **Open questions for the user**.

## M2 — Stimulus framework + graybox kit (2026-11-06)

**What went well**
- First milestone split into two parallel briefs (framework in the main checkout, kit in an isolated worktree). Zero file overlap; the merge was conflict-free.
- Framework: 194 tests including a scenario test asserting a fire → burn → noise → heard chain by tick; noise now travels along the navmesh around walls. Kit: 7 parametric parts with metric warnings, grid materials, runtime navmesh, hub and course converted with all tests intact. 243 tests after merge.
- Both agents reported useful deviations (navmesh max climb 0.05, CSG baked from an out-of-tree copy, log ordering for tick determinism) and self-retrospectives.

**What went wrong**
1. **Stale class cache after merge**: new `class_name`s were unknown to the existing `.godot/` cache; the test run segfaulted (exit 139) and printed no summary. My first check almost read "no summary" as nothing.
2. **Leaked processes**: the kit agent left two hung headless `--script res://_probe.gd` Godot processes, which locked its worktree folder.
3. **Cost**: ~620k tokens across the two agents (kit ~364k / 38 min / 173 tool calls; framework ~257k / 20 min). Main drivers, self-reported: undocumented engine behaviour (CSG collision empty/stale right after load, navigation map async iterations, `await physics_frame` timing) discovered by trial inside full features; worktree shell restrictions causing retries.
4. **Worktree inside the project** broke `gdformat` (argument list too long) until lint skipped hidden folders and `.gitignore` ignored `.claude/worktrees/`.

**Changes made**
- `tools/run_tests.sh` always re-imports before running (fixes 1). Chief engineer: always check the test summary line exists, not just the absence of failures.
- AGENTS.md "Engine probes" section: probe uncertain engine behaviour with a small script first, probes live outside `res://` with `quit()` and `timeout`, no leftover Godot processes, class-cache refresh, scratch scripts in worktrees (fixes 2, 3).
- Lint skips hidden folders; `.claude/worktrees/` ignored (fixes 4, done by the agents during M2).

**Notes for later milestones**
- Components that re-emit on their own timer (M3 fire spread) must pass the parent stimulus to keep chain depth.
- Hearing distance is measured to the receiver node: a receiver at head height adds ~1.6 m (tune in M7).
- The concrete strip in the course uses the same material as the hall floor (only its floor sign distinguishes it).

**User playtest feedback**
- Pending.

**Open questions for the user**
- M2 cost ~620k sub-agent tokens. Is that acceptable per milestone, or should I trade some verification depth / use Sonnet more for level work to cut it? → **Keep quality** (user, 2026-11-06): keep full verification and the stronger model for system and level work; keep cutting waste through probes, gotchas and better briefs.

## M1 — Player controller (2026-11-06)

**What went well**
- Clean split: thin `Player` node over pure, unit-tested rules (`PlayerMotion`, `MantleRules`, `PlayerNoiseRules`, `FootstepTracker`). 88 tests, lint clean, one noise emit point ready for M2.
- The agent used screenshots and fixed three visual problems itself (floor contrast, black vent, hidden signs).
- Deviations were reported with reasons, and the agent caught three errors in the brief.

**What went wrong**
1. **Cost**: ~32 min, ~330k tokens, 128 tool calls for one agent. Self-reported split: level building 35%, integration-test harness 25%, controller edge cases 20%.
2. **Brief errors (chief engineer)**: crouched capsule = vent height (no margin); "one gap infeasible" was false (sprint jump 5.4 m); mantle height measured only from the feet let jump-and-hold climb 2.3 m. Unspecified: hold vs toggle crouch, reach reference, mouse release, vent width.
3. **Hand-placing CSG in `.tscn` text** was slow and error-prone (transform order, lips, missing parents).
4. **Test harness learning curve**: process vs physics frames, suite state across tests, EventLog leaking between tests, float32 sizes, gdlint public-method cap.

**Changes made**
- AGENTS.md: "Godot 4.7 / GdUnit4 gotchas" list (13 items) and a pointer to the reusable `player_driver.gd`. (Fixes 4.)
- design/tech/testing.md: "Deterministic physics tests" section. (Fixes 4.)
- design/levels/metrics.md: player size, clearances, jump/mantle limits, noise numbers; AGENTS.md requires levels to respect it. (Fixes 2, 3.)
- CLAUDE.md: brief checklist (verify numbers against metrics, state measurement references, input modes, exits, layout sketch) and split milestones into parallel briefs (systems vs level building). (Fixes 1, 2.)

**User playtest feedback** (fixed on `m1-feedback`, merged)
- Gravity felt floaty → player gravity scale 2.0, apex kept at 1.0 m ([ADR 0036](decisions/0036-player-gravity-scale.md)); sprint gap 4 m → 3.3 m.
- Mantle triggered on low steps → minimum 1.0 m above the last ground ([ADR 0035](decisions/0035-mantle-rules.md)).
- Metal footsteps sounded like a spoon on glass → `impactPlate_light` at pitch 0.8.
- Ledge catch and landing noise accepted as is.
- Lesson: feel numbers (gravity, step heights, sounds) can't be validated by tests; keep them in `.tres` and expect a tuning pass after each playtest.

**Open questions for the user**
- Level building approach? → **Kit of parametric graybox parts** with CSG Blockout's grid shader copied into `assets/materials/graybox/` ([ADR 0037](decisions/0037-graybox-kit.md)), built during M2.

## M0 — Skeleton (2026-11-06)

**What went well**
- Docs and tooling agents ran in parallel on disjoint files; no conflicts, no docs/code drift found in review.
- Tooling agent verified everything it shipped (import from empty cache, tests, lint, main scene run) and reported deviations instead of hiding them.
- 16 tests (15 pass, 1 skipped headless by design), lint clean, merged with `--no-ff`.

**What went wrong**
1. **Engine-version drift.** `debug/gdscript/warnings/exclude_addons` no longer exists in Godot 4.7 (replaced by `directory_rules`). Agents' training data mixes Godot versions; the agent only caught it by trial.
2. **No visual verification.** Scenes were generated and tested structurally, but nobody looked at them. Layout, lighting and readability problems would only surface when the user opens the editor.
3. **Windows quirks** cost agent time: gdformat writes CRLF; the executable bit isn't stored (`core.filemode=false`). Both fixed in M0 (lint.sh strips CR; `git update-index --chmod=+x`).
4. **Main-session context waste.** Unfiltered `git add` (hundreds of CRLF warnings from addons) and `git status` (400+ generated `.import` files) flooded the chief engineer's context.
5. Scenes written via `ResourceSaver` lack `uid=` headers; the editor adds them on next save (expect a one-time diff).

**Changes made**
- `tools/gen_api_docs.sh`: dumps the exact local engine API reference (`--doctool`) into `.api-docs/` (gitignored). AGENTS.md now requires checking it for any engine API or project setting not already used in the codebase. (Fixes 1.)
- `tools/screenshot.sh`: renders a scene in a real window and keeps the last frame (`--write-movie`). AGENTS.md now requires a screenshot check for any scene or visual change, and agents attach the PNG path in their report. (Fixes 2.)
- AGENTS.md gains a **Definition of done** and a **Windows notes** section. (Fixes 3, makes review criteria explicit.)
- CLAUDE.md: retrospective after every milestone; filter noisy command output in the main session. (Fixes 4.)

**Open questions for the user**
- `tools/screenshot.sh` opens a game window for about a second. OK for agents to do that while you work? → **Yes** (user, 2026-11-06).
