# Retrospectives

After every milestone the chief engineer reviews what the sub-agents did and what went wrong, then changes the process (tools, tests, AGENTS.md, CLAUDE.md, a request to the user) so the same problem does not repeat. Newest first.

Format per milestone: **What went well**, **What went wrong**, **Changes made**, **Open questions for the user**.

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
