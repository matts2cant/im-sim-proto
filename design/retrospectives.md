# Retrospectives

After every milestone the chief engineer reviews what the sub-agents did and what went wrong, then changes the process (tools, tests, AGENTS.md, CLAUDE.md, a request to the user) so the same problem does not repeat. Newest first.

Format per milestone: **What went well**, **What went wrong**, **Changes made**, **Open questions for the user**.

## M7 — Light and AI (2026-11-07)

Two waves of two agents in parallel worktrees. Wave 1: light level + lamps + breaker + Perception lab (ADR 0065–0066) and guard core: body, vision, hearing, graded awareness, patrols, feedback (ADR 0067–0069). Wave 2: guard combat and loadouts (ADR 0070) and bodies, shouts, radio, level alarm, AI arena, lab guard (ADR 0071–0072; that agent ran its own level sub-agent). Started without the M6 playtest at the user's request (they were travelling). 816 → 1023 tests. ~1.6M sub-agent tokens.

**What went well**
- The shared light contract (group `light_exposure` + `level`) let both wave-1 agents work in parallel; merging the light branch first and messaging the guard agent to merge master, switch to `LightExposure.of()` and write the cross-contract test removed the merge-time integration work. Repeated in wave 2 (loadout scenes, combat vs body discovery).
- No identity branches in review: hostile/ally/body rules are tag lists in `.tres`; waking is a `revive` stimulus; the alarm is a stimulus reaching a group; carrying bodies reuses Carryable with a `carry_mass`.
- The player-is-not-special rule paid off: the weapon path was already generic enough that guards fire the same stimuli through `WeaponHolder` with any eye node; guards reuse MovementNoise, StepClimber, FallImpact, Knockback, BodyParts.
- Agents found and fixed a latent violation: props scanned the actors layer (infinite-mass shoves by guards, ADR 0054). Fixed with `BodyPusher` for every character and a `static_actors` layer for dummies.

**What went wrong**
1. **My lab brief asked for a 20 m room that did not fit** between the neighbouring rooms; the agent measured and shrank it. I had not checked the hub footprints.
2. **Removing the actors layer from props made thrown crates pass through dummies** (wave 1). Caught by the agent and fixed in wave 2, but it shipped to master for a few hours.
3. **Nested agents leave extra worktrees**: the wave-2 agent's own level agent left a second worktree and branch to clean up.
4. **Test isolation**: fixtures freed with `auto_free` lingered into the next suite and answered navigation queries; the first full run of wave 2 had nav failures until helpers waited for old fixtures.
5. One sloppy sentence in the combat brief (a half-edited accuracy requirement). The agent interpreted it sensibly, but briefs should be re-read before sending.

**Changes made**
- CLAUDE.md: merge-first + message-the-other-agent for shared contracts; measure neighbour footprints before sizing a room; `git worktree list` cleanup after merging (nested agents included).
- AGENTS.md gotchas: props' collision masks and the `static_actors` layer; lingering `auto_free` fixtures, `PlayerDriver.place()` clearing the EventLog, the EventLog ring size; guard test helpers; fixtures with guards need lamps.
- metrics.md: new "Light and guards" section (light thresholds, vision cones, hearing, shout and radio ranges, lamps required).

**Open items**
- Guards do not avoid each other (NavigationAgent3D avoidance off); vision cones have no vertical limit.
- Pistol accuracy against a running target is low (10 m: ~21 s to kill); tune after the playtest.
- During the alarm guards search where they stand (no alarm panels until M8). Combat state is not saved (re-engages on sight).
- Jolt warned once "job system exceeded the maximum number of jobs" in a full test run.
- Carried from M6: barrel alley ignition knife-edge, brazier sound leak at exit, mantling still player-only, aug tags without reference counting.

**Open questions for the user (playtest)**
- Guard detection speed and accuracy: too forgiving or too harsh? (Lit at 4 m: alerted in ~0.8 s; dead at 4 m in ~2 s, at 10 m in ~4.4 s standing still.)
- Bodies count as 15 kg so you can carry them without Combat Strength, at 60% speed. OK?
- Shouts, radio and the alarm make guards search, not instantly know where you are. OK?
- Plus the M6 questions (Combat Strength toggle, skill/energy numbers).

## M6 — Abilities and saving (2026-11-07)

Two agents in parallel worktrees (abilities: skills, energy, augmentations, Stats tab, HUD, room 7 station, ADR 0061; saving: F5/F9, JSON quicksave, removed/spawned records, project-wide saveable contract test, ADR 0063), then one agent for the merge, a design amendment and the integration test. 702 → 807 tests. ~870k sub-agent tokens.

**What went well**
- The systemic rule held: skills and augmentations are attribute modifiers read by consumers with their config as base (`Attributes.read`), plus one generic "scale outgoing stimulus by a source attribute" mechanism for pistol damage, baton damage and medkit healing. Any actor can carry them.
- The saving agent probed `var_to_str` first and found `str_to_var` instantiates objects (code execution from a save file); chose `JSON.from_native` with objects off.
- The project-wide saveable contract test caught a real orphan after the merge (HUD chips freed with `queue_free`).
- Agents flagged a design side effect as a decision instead of silently changing tests' meaning.

**What went wrong**
1. **My brief changed the baseline**: "all augmentations installed" + "Combat Strength passive" made the default player lift 60 kg and knock out in 2 hits, contradicting gallery signs; the agent added test workarounds to keep old numbers. Fixed by making Combat Strength an F6 toggle (1 energy/s), as in Deus Ex.
2. **I named input actions as new without grepping**: F1–F6, F5/F9 were already in the input map (planned in M0). Harmless, but a breach of the "grep before naming" rule.
3. **`.tscn` ext_resource id clash at merge** (both sides appended id `35_…` to player.tscn); the merge agent renumbered. The scene-load smoke test would have caught a broken file.

**Changes made**
- CLAUDE.md: a brief that adds an always-on or default-on modifier source must check it against the baselines that signs and tests encode (default player behaviour must not change unless intended). Grep the input map (project.godot) before naming input actions.

**Open questions for the user (playtest)**
- Combat Strength as an F6 toggle (Deus Ex) rather than passive: OK?
- Per-tier skill numbers and drain rates: first-pass values in `actors/common/abilities/`.

## Systemic cleanup and second feedback batch (2026-11-07)

User feedback after the retest: crates floating when the bottom of a stack burns, step climbing, belt mouse wheel + H holster, datapads read in place with a personal log, the baton pose. The user also asked to make the systemic principle explicit; an audit found no identity branching but several player-only behaviours and direct calls, fixed in two refactors (ADR 0056 characters, 0057 forces/items/heat). 559 → 702 tests. Eight agents, mostly in parallel worktrees.

**What went well**
- The "systemic design" section in AGENTS.md changed agent output immediately: new features (StepClimber, PersonalLog/Readable, Knockback) landed as generic components tested on minimal fixtures, and agents reported where they still had to special-case.
- Assigning ADR numbers up front avoided the duplicate-number problem; only the index rows conflicted.
- Agents ran engine probes before building (Jolt slide collisions, body_test_motion, sleeping bodies) and reported measured values.
- Splitting by ownership ("do not build" lists) kept merges to ADR index rows plus two small `player.gd`/`.tscn` hunks.

**What went wrong**
1. **Parallel test runs confuse process checks**: agents saw each other's (and my) Godot processes and reported them as strays; one claimed a 15-min suite (it is ~3.5 min alone, slower when runs overlap).
2. **Two refactors built against an agreed contract were never run together** until the merge (force stimuli emitter vs receiver). Caught because I asked the merge agent for an integration test; it passed.
3. **A level knife-edge survives**: the barrel alley's top crate gets fire 6.1 vs a 6.0 ignition threshold; behaviour changed with the force refactor and the agent updated the doc instead of the layout.
4. **Recurring engine exit leak** ("Stoke Coal Oven.wav" playback) reported by every agent; never traced.

**Changes made**
- AGENTS.md: check only the Godot processes you started (by PID); other agents' runs may be in progress. (Fix 1.)
- CLAUDE.md already requires contracts in parallel briefs; added practice: when two parallel agents share a contract, the merge step adds an integration test across it. (Fix 2.)
- Open items for the next level pass: move the barrel alley top crate off the knife-edge (fix 3); trace the crackle audio leak (fix 4).

## M3–M5 playtest feedback fixes (2026-11-07)

User feedback: the health silhouette stayed green, the settled aim was too wide, crate stacks went unstable when jumped on, and carrying should be closer, see-through, collision-free and upright. Three agents in parallel worktrees (HUD + aim on Sonnet, stacking and carry on the stronger model). 503 → 549 tests.

**What went well**
- Every agent reproduced its bug in a failing test before fixing it, and reported before/after numbers (stacking: walking across a 2-crate column drifted 3.9 m and tipped 172°, now 0.5 mm).
- The parallel split held: the only merge conflict was the ADR index.
- The carry agent found a Jolt quirk by probing (`cast_motion` ignores a start overlap) instead of guessing.

**What went wrong**
1. **HUD "bug" was tuning**: the silhouette did update, but green only gave way at 50% health, so typical hits (80–90%) looked untouched. The M4 tests checked the ramp's endpoints, not whether a real hit is visible.
2. **My stacking scenarios already passed**: the real failures were walking across the top, mantling and teleporting next to crates, which the agent found on its own. My brief guessed the cause instead of asking for the user's exact actions to be replayed.
3. **ADR number collision**: both parallel agents took 0053; renumbered the stacking ADR to 0054 at merge.
4. **`.venv` junctions in worktrees**: two agents linked the main `.venv` into their worktree to run lint; removing such a worktree could have deleted the real venv (I removed the links by hand first).

**Changes made**
- CLAUDE.md: parallel briefs assign ADR numbers; bug-fix briefs replay the user's exact actions with real values first. (Fixes 2–3.)
- `tools/lint.sh` falls back to the main checkout's `.venv` from a worktree; AGENTS.md forbids linking it. (Fix 4.)
- AGENTS.md gotchas: kinematic bodies vs props in Jolt (ADR 0054, applies to guards in M7) and the `cast_motion` start overlap.
- HUD test now asserts a real graze changes the colour (fix 1 is covered by the test, no process change beyond rule 2).

**Trade-offs to playtest**
- Props no longer hit the player (falling crates, thrown bottles pass through); the player now pushes small crates at up to 2 m/s, the large crate stays fixed. Prop friction 0.5 (was 1.0).
- Moving aim cones are 1° tighter than before (base 0.5° under every stance).
- Stacking by putting a crate down works best ~0.9 m from the lower crate; "place where you look" is the fallback if it feels fiddly.

## M5 — Inventory, belt, items + gallery rooms 4 & 7 (2026-11-07, autonomous night)

**What went well**
- Pipeline: M5 systems ran in a worktree (on top of the finished M4 systems) while the shooting range was built in the main checkout; a final agent finished the merge and did the level pass. 502 tests after M5, all gallery rooms 1, 3, 4 and 7 built.
- Agents generated item resources and room layouts from scratch scripts: consistent and quick to redo after screenshot reviews.
- A headless-GUI probe settled early that pushed mouse events don't reach Controls headless; drag tests call `_gui_input` directly instead of failing mysteriously.
- The new "fail on script errors" runner caught a parse error immediately.

**What went wrong**
1. **Cross-branch breakage**: M5 deleted `objects/medkit/` (medkits became inventory items) while the range, built in parallel, placed those objects. Caught only because I grepped after the merge.
2. **Encoding slip**: Python edits defaulted to cp1252; text with `·`/`×` silently didn't match and a sign text missed the merge commit.
3. **Windowed screenshots** may still open at 840×648 despite `--resolution`; agents worked around it in fixtures.
4. **Cost**: the night (M3–M5, 10 agents) used ~2.1M sub-agent tokens, ~3–4 h of agent time, about 690k per milestone, in line with M2.

**Changes made**
- `tests/smoke/scenes_load_test.gd`: every scene in the game folders must load and instantiate (catches dangling references after merges). AGENTS.md: grep for references when deleting/moving resources; UTF-8 for Python edits; window size in screenshot fixtures. (Fixes 1–3.)

**Open questions for the user (morning)**
- See the M3/M4 questions (fire spread speed, pistol sound).
- Items currently have graybox icons (coloured tiles with names). Fine until an art pass?

## M3 — Physics objects & fire, M4 — Body damage & weapons (systems) (2026-11-06/07, autonomous night)

The user authorised autonomous work on M3–M5 overnight with retrospectives, stopping at M5 for a morning playtest. M3 and M4 systems ran as three agents: M3 systems, then the M3 room (main checkout) in parallel with M4 systems (worktree based on the committed M3 systems). The M4 shooting range is built with the M5 levels.

**What went well**
- Parallel pipeline kept work flowing: M4 systems ran while the M3 room was built; one small conflict (see 2), resolved by a Sonnet agent in 2.5 min.
- Probes paid off (M3 contact-speed probe); pure models first made M4's dummy integration suite pass first time.
- In-room scenario tests (fire row, barrel chain, barricade burn-out, Reset) test the actual gallery content, not just fixtures.
- First-person screenshots caught occlusion problems in the room that no layout test would.
- 416 tests after merging M3 + M4 systems.

**What went wrong**
1. **Ambiguous distance in my brief (again)**: "a crate 0.6 m from a burning crate ignites in ~3 s" didn't say gap or centre-to-centre. With 0.6 m gaps (1.2 m centres) each crate took ~19 s and the chain was knife-edge; the room agent tightened the row to 0.3 m gaps (~5 s per ignition). I had already written a rule to state measurement references; I didn't apply it to object spacing.
2. **Duplicate feature**: "Reset level" was built twice: I assigned it to the M3 room agent while the M4 brief mentioned it in passing ("the Spawn tab will have a Reset level button"), so the M4 agent built it too.
3. **Shared scratchpad collision**: two agents wrote scripts with the same name in the shared scratchpad; one overwrote the other.
4. **Script errors invisible to tests**: errors from freed stimulus sources only showed in windowed runs; GdUnit passes even when Godot prints `SCRIPT ERROR`.
5. **Screenshot UI cropping**: this machine opens an 840×648 window, cropping the 2D layer in screenshots.
6. **Range brief errors (M4 room)**: blast-lane stripes at 2/4/6 m with a 4 m blast radius → the 4 m line deals 0 (boundary value); the brief also asked tests to assert a `weapon.hit` event that doesn't exist (I named an API from memory instead of the code). Follow-up: move the middle stripe to 3 m in the M5 level pass.
7. New gotchas: a static method named `reload` collides with `GDScript.reload`; consecutive simulated presses of the same action need a released frame between them; check view-model scale in a screenshot before writing tests.

**Changes made**
- CLAUDE.md brief checklist: every distance says "gap (surface to surface)" or "centre to centre", with the expected timing computed in the brief; parallel briefs list features owned by other agents as "do not build". (Fixes 1, 2.)
- `tools/run_tests.sh` fails on `SCRIPT ERROR`/`ERROR` lines from project code (allowlist for engine noise); `tools/screenshot.sh` forces 1152×648. AGENTS.md: private scratch subfolder per agent; new gotchas. (Fixes 3–6.)

**Questions for the user (morning)**
- Fire spread speed: ~5 s per crate with 0.3 m gaps. Should heat be measured to the receiver's nearest surface instead of its centre (more intuitive for level design, faster spread for big objects)?
- Pistol sound is a muffled kenney impact thud: does it read as a suppressed shot?

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
- Dark striped slab above the "1 Movement" doorway → z-fighting: the `Room` ceiling slab covered the walls too, so a corridor's ceiling ended exactly on the hub wall face. Fixed in the kit part (walls full height, slabs interior only, [ADR 0043](decisions/0043-room-connections-share-a-wall.md)); regression guard `KitGeometry.coplanar_material_overlaps()` fails on coplanar overlapping faces with different materials (hub + course).
- Floor threshold strips and corridor alignment: not bugs (my screenshot reading over-reported; the user corrected it).
- Lesson: agent screenshots were taken from overview cameras, never at player eye height near seams. Screenshot reviews should include first-person views at connections.
- Follow-up: `kit_showcase.tscn` still has same-plane overlaps with its ground slab (not covered by the guard).

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
