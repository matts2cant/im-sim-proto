# Retrospectives

After every milestone the chief engineer reviews what the sub-agents did and what went wrong, then changes the process (tools, tests, AGENTS.md, CLAUDE.md, a request to the user) so the same problem does not repeat. Newest first.

Format per milestone: **What went well**, **What went wrong**, **Changes made**, **Open questions for the user**.

## M9 — Warehouse mission (2026-11-09, autonomous night)

Six agents in four waves, from the grilled design (3 rounds, ADR 0086, design/levels/mission-warehouse.md):
- M9a: mission systems (level change, briefing, objectives, summary and badges, weapon drops, rifle guard, reinforcements; ADR 0087, 0088).
- M9b: layout, night lighting, routes, navigation, built from a Python generator (`tools/level_gen/`; ADR 0089).
- M9c and M9d in parallel: doors, locks, keys and the security network with generic door sizes and free-side locks (ADR 0090), and guards, patrols, items and mission props (ADR 0091).
- M9e: a design review from screenshots, with polish (ADR 0092).
- M9f: end-to-end route tests, the two missing system uses, and the level-change warning (ADR 0093).

Final suite: 1400 tests, 0 failures, 76 s.

**What went well**
- Shared contract names in the wave briefs (`PlayerSpawn`, `ReinforcementSpawn`, `Extraction`, `Mission`, `Population/People`, `Population/Security`) let layout, people and security be built in parallel. Merging the first finisher and messaging the other worked again.
- **Generated level.** Every area and population scene comes from `tools/level_gen/*.py`, so moving a railing, adding a window or two patrols is a one-line change, regenerated and diffable.
- **The fresh-eyes review (M9e)** walked each route at eye height with the starting kit. It found 11 issues that no test would have:
  - one switch silenced every device;
  - long unwatched gaps in the patrols;
  - the manager office was unreadable at night;
  - guards could not follow through one-sided doors;
  - a solid gate hid the yard.
- **The route tests (M9f)** drive the real player through the populated level and assert the summary. They found a real blocker: the office stair's top was 0.65 m wide for a 0.7 m capsule. Saving a snapshot between segments keeps each test under 15 s while the badges count the whole route.
- **Systemic fixes stayed generic:**
  - free-side navigation links and door sizes work on every door;
  - the deferred level change applies to every trigger;
  - the perception scan is shared by every sensor.
  No identity branches in any diff.
- **Suite time held** despite four heavy level suites per wave. M9e loads each level once per suite and bakes the navmesh once (`LevelNavigation.bake_on_ready`): 144 s back to 54 s. M9f's routes added about 22 s.

**What went wrong**
- **Suite time.** The warehouse suites tripled it (45 s to 144 s) before anyone looked; the briefs gave no time budget for new suites.
- **The office stair's top was impassable** through four waves. The passage tests climbed every stair to its top step but never stepped off onto the destination floor.
- **An engine ERROR went unnoticed until M9f** ("Removing a CollisionObject node during a physics callback", on the hub-to-warehouse change). The runner's error scan only matched project files in the error's own location line. The project code was in the GDScript backtrace below it.
- **The first full run after merging M9f took 165 s.** The four new route suites had no recorded time, got the global median estimate, and, being adjacent alphabetically, all landed in one contiguous shard. The next run took 76 s.
- **Ten guards cost 7.1 ms per physics frame:** each guard scanned every tagged node twice per frame. It surfaced only because route tests were slow. No level brief asked for a frame-cost measurement.
- **Loud play can't be completed as the design describes** ("hold the gate lane"). Every guard converges by radio in seconds. The test had to take a hold-on-the-containers route instead. That is a balance question for the playtest.
- **The M9f worktree was cut from an old commit again.** The agent noticed and reset (the CLAUDE.md rule worked).
- **My slip:** I deleted a `worktree-agent-*` base branch while its agent was still running (harmless, the agent worked on its own branch).

**Changes made**
- Runner (merged `runner-gaps`):
  - An engine ERROR whose GDScript backtrace has a project frame (outside `addons/`) fails the run. It caught no existing test.
  - An unmeasured suite is estimated from its folder's median, and unmeasured suites are spread over shards. A folder median alone still put all four route suites in one shard.
  - `--dry-run` prints the shard split.
  - Full suite now 66 s; its floor is `warehouse_route_vault_test.gd` alone (about 60 s under load). Splitting or speeding it up is the next kaizen item.
- CLAUDE.md:
  - Level briefs ask passage tests to step off every climb onto the destination floor.
  - Briefs that add suites give a time budget and ask for the suite's wall time in the report.
  - Briefs that populate a level ask for the physics-frame cost measured with every actor active.
  - Judge suite time on the second full run after merging new suites.

**Open questions for the user** (also in mission-warehouse.md):
- Is a first ghost run fair with ten guards (gaps 6-39 s)? Is the upper corridor (camera, G7, a lit 1.5 m corridor) too tense on a first visit?
- Loud with the starting kit can't hold ground: intended "tight", or too hard?
- Should duct B's roof mouth be marked, or found by exploring?
- Guards now follow the player out through free-side doors everywhere in the game. Intended?
- Are the annex window (two stacked crates) and the cache shed (Combat Strength) found without a hint, and worth the detour?
- Dropping out of duct B onto the cabinet makes four guards suspicious. Should it be quieter?
- Still open from M8: keypad pauses but terminal does not; Searching guards alert on any glimpse (suspicion meter instead?); a remote "open" leaves a locked door locked.

### Playtest feedback (2026-11-09)

"Pretty cool", with four points. They are being fixed in M9g (ADR 0094-0097):
- **One guard alerted on entering the manager office through duct B.**
  - Cause: a defect in noise propagation. When the navmesh path from a noise did not reach a listener, `StimulusSystem._reach()` closed the gap with a straight line through walls and floors. The landing snapped to a navmesh island on the cabinet top, so G5, G6 and G7 heard it through the walls.
  - G7 then looked around just outside the door and saw the player open it. M9f's "four guards suspicious" note was this bug, not intended noise.
  - Fix: the path is queried from the listener when it stops short, and a straight gap is accepted only if no wall is in the way. Investigation arrival also checks height (ADR 0094).
- **Darkness too strong.** Below light 0.1 the sight gain was 0 beyond 2 m. Moving targets now keep a small light factor in the dark, and guards carry flashlights: yard patrols always, and every guard while Searching or Alerted (ADR 0095).
- **Rush run in 1:30** (crates to the roof, duct B, manifest, boat). The roof was a safe layer with no threat. Laser tripwires as network devices (ADR 0096), then roof lasers and a roof camera or patrol in the warehouse (ADR 0097).
- **Process:**
  - The route tests passed with Ghost while three guards went Suspicious on every duct B entry. Ghost only counts alerts, and no test checked who heard what.
  - Lesson: scenario tests on a stealth route also assert that no guard becomes Suspicious where the design says the route is quiet.
  - The reproduction-first bug brief found the real cause again. My guess (cabinet noise) was wrong.

### Character models and their playtest fixes (2026-11-10)

Two agents, one after the other:
- Kenney blocky characters for guards and dummies, with a layered `CharacterAnimator` (ADR 0103). Baton breaks devices (ADR 0104).
- The user's six remarks after playing with the models (ADR 0105):
  - The models were unshaded.
  - The baton was held flat.
  - Two-handed holds looked wrong.
  - The flashlight had no model in the hand.
  - Dummies moved with the idle animation.
  - The head hit zone was too small.

Final suite on master: 1577 tests, 0 failures, 2 skipped (headless mouse mode, loud route segment 3), lint clean. It took 182 s, but other Godot processes were running, so the time needs a second run.

- **Went well:**
  - The shading agent found the real cause instead of tweaking light levels. The GLBs declare `KHR_materials_unlit`, so the fix is an external shaded material in the import settings, with no code.
  - The flashlight's beam direction is decoupled from the animation, so a test holds its direction at 0° from the old beam in every state. The ADR 0095 detection times are unchanged.
  - The dummy's static pose is data (an animation config), not a dummy branch.
  - Time-to-kill was measured before and after the head change: a new pistol test, plus the shotgun's existing one.
- **Went wrong: the scripted warehouse route tests.**
  - The 7 route suites are about 1,800 lines. They were edited in 6 of the 8 batches since M9f, almost never because the level broke. Each time a rule elsewhere moved under them:
    - the searching-guard alert threshold;
    - guard speeds;
    - where locks sit on doors;
    - the roof lasers;
    - the leg hit zones;
    - the head hit zone.
  - Both character agents spent a long stretch on the loud route:
    - The first made it accept a gate the guard had opened.
    - The second bisected a death at 99 s: the bigger head means the segment 1 fight also kills G2. The searching guards then reach the roof and find the player waiting there.
    - Neither was a level bug. Both were emergent behaviour, which an immersive sim is meant to produce.
  - Scripted end-to-end runs with live guards, combat and patrol timing are brittle by nature, so tuning changes keep breaking them.
  - The bugs they found are caught more cheaply by targeted tests:
    - The office stair top only 0.65 m wide: a passage test that steps off every climb.
    - Duct B noise heard through walls: a noise spot check at each quiet spot. The user found this one by playing; the route test only encoded it afterwards.
  - I stopped the second agent on the user's call. It skipped the failing segment 3 of the loud route, with a reason pointing to the replacement.
- **Changes:**
  - The user's decision: test individual features and systems well, not full routes.
  - CLAUDE.md: level briefs ask for passage tests and noise spot checks, and no new scripted full-route tests.
  - The user then dropped every scripted warehouse route suite outright, with no replacement batch (ADR 0106).
  - Full suite after the drop: 1563 tests in 48 s on the second run (was 99 s). The existing passage test and duct B noise test stay, and the routes move to the playtest checklist.
- **Open for the user:**
  - Shotgun at 15 m: upper pellets now land on the bigger head. It kills in 1-3 shots (median 2), not ADR 0085's 3 or more. Keep it, or weaken the shotgun? → **Keep it** (user, 2026-11-10).
  - The off-hand flashlight's lens sits 0.40-0.52 m from the old beam origin (about 0.4 m was asked). Closer puts the arm through the head.
  - Frame rate is about 5% lower (shaded models, the hand-held beam's moving shadow), up to 11% with every flashlight lit.

### M9h — playtest batch 2 (2026-11-09/10)

Seven agents, all merged on green full runs:
- Wave 1, four in parallel:
  - doors: lock hardware on the leaf and wall boxes, keycards needed every time (ADR 0098);
  - network map: comb layout, pan, zoom, fit (ADR 0099);
  - laser arrays, a 45 s alarm, downed hostiles not sightings (ADR 0100);
  - Rifles and Sniper skills, ammo colours, lower view models (ADR 0101).
- Wave 2: guard speeds (ADR 0102), plus test and level fixes.
- Map node colours (an ADR 0099 amendment), asked for mid-batch.

Final suite: 1542 tests, 84 s, 1 skipped. The user chose to leave the headless mouse-mode test skipped.

- **Went well:**
  - Reproducing the user's exact steps found the turret beep loop's real cause: a downed hostile was still a sighting, so the turret re-engaged every frame. It was fixed in perception for every sensor, not only the turret.
  - The flaky-test agent did not take "navigation leak" for granted. It reproduced worker-thread starvation instead (a frame-capped wait is only 30 ms at 144 fps) and recorded the rule: waits for worker threads get real-time caps.
  - A generic wall-device check now catches devices in doorways or over signs.
  - Splitting files between agents kept conflicts to the ADR index.
- **Went wrong:**
  - Asking every running agent to merge master after each merge cost each of them two or three extra full runs. One agent finished before the message arrived and had to be resumed.
  - I ran `rm -rf` on a worktree still locked by its finished agent. It was harmless, but use `git worktree remove -f -f` once the agent's final notification arrives.
  - Parallel agents all left the ADR count line to me, which is the right call; briefs now say so.
- **Changes:** CLAUDE.md:
  - With parallel agents, only the last one to finish merges master before its final run, unless a merged change touches code it uses.
  - Parallel briefs leave the ADR count line to the chief engineer.
- **Open for the user:**
  - Warehouse crossing gaps are now 4.9-43.8 s, close to the 4-45 s targets; the next slow-down needs a route change.
  - Alert words on the map are amber now, because red means disabled.

### M9g — playtest fixes (2026-11-09)

Four agents in two waves, each merged on a green full run:
- Noise reach on partial paths and investigation arrival (ADR 0094).
- Darkness floor for moving targets, flashlights, and a searcher meter threshold (ADR 0095).
- The laser tripwire device and the gallery laser hall (ADR 0096).
- Roof security: high beams at both stair arrivals and a camera mast with a flood lamp over duct B's forecourt, on the yard network (ADR 0097).

Final suite: 1461 tests, 80 s.

- **Went well:**
  - The bug agent, resumed with its own context, fixed the defect it had found.
  - Merging the first finisher and messaging the others to merge master worked across three parallel agents. Only the ADR index conflicted.
  - No game-code change was needed for the roof: two new devices composed into the level.
- **Went wrong:**
  - My roof brief left out "commit in small steps", so the work came back uncommitted. CLAUDE.md's worktree line now asks for it.
  - The darkness agent added a rule I had not briefed (searchers need meter 0.2). It was justified, but it is a behaviour change the user must confirm.
- **Open for the user:**
  - Is the searcher threshold right?
  - The lit forecourt is visible from the north catwalk through the east skylight: keep it as design?
  - A Speed Enhancement jump over a 1.3 m beam is untested.

## M8 — Security (2026-11-08)

Four agents in three waves: M8a devices, cable graph, remote commands and alarm devices (ADR 0077, replacing the global LevelAlarm per ADR 0075); M8b doors, locks, keypads, multitool removal, Computer skill (ADR 0078, 0076); M8c cameras, turret, terminal (ADR 0079, 0080); M8d the security wing (gallery room 5). A Sonnet agent fixed a flaky HUD test before the last merge. Final suite: 1188 tests, 0 failures.

**What went well**
- Naming the shared contract in both wave-1 briefs (command stimulus types, the `state.unpowered`/`state.broken` tags) let devices and doors be built in parallel; merging M8a first and messaging the doors agent to switch to the real `Device` API and write the cross-feature test worked again (third time).
- Starting wave 2 as soon as its only dependency (M8a) merged, instead of waiting for the whole wave, overlapped M8b and M8c.
- No identity branches: the terminal's buttons come from which command receptrons each reached device has; the controller finds sirens and base stations the same way. The door appeared on the terminal with no door code.
- Agents probed navigation before building door passage (carving obstacle + NavigationLink3D on access layers).
- Asking for a measured outcome (turret time to kill 3-5 s) instead of trusting my numbers caught a bad value: 8 damage gave 7 s; the agent raised it to 15 and wrote the measurement as a test.
- The room needed zero new system code.

**What went wrong**
- HUD asserts flaked under the time factor (labels refresh in `_process`), first in my knockout fix, then in two other suites; three agents hit it and one full run failed because of it.
- Fixtures whose navmesh overlapped the origin broke unrelated suites through late-freed regions; agents worked around it by moving fixtures 200 m away, each rediscovering it.
- Parallel briefs did not say whether UI screens pause: the keypad pauses the game, the terminal does not.
- Full-suite runs are long and agents ran them several times; one agent stopped a run mid-way to merge and could not kill its own leftover Godot processes (auto-mode refused), so it waited.

**Changes made**
- AGENTS.md: assert on HUD/UI state only after calling the component's refresh (never a bare process-frame wait); place test fixtures with navigation far from the origin and from each other.
- CLAUDE.md: briefs state pause vs. running for every new UI screen; tuning targets are given as measured outcomes with a test; agents iterate on a test subset and run the full suite once at the end; never stop a test run mid-way.
- Test speed: options given to the user (skip re-import when unchanged, dummy audio driver, parallel shards, slow-suite fixes); to schedule after the playtest.

**Open questions for the user**
- Keypad pauses the game, the terminal does not: make them consistent (which way)?
- A remote "open" opens a locked door but leaves it locked; guards leave doors they open open. OK?
- Turret 15 damage a hit (about 4 s to kill a standing player at 6 m); camera spots a lit player at 4 m in about 1.25 s. Feel right?

### Playtest feedback (2026-11-08/09)

- Walk over bodies: downed characters move to a `downed` layer no character scans (ADR 0082).
- Arena guards rushing the idle player: latent since M7, not M8. The baton post's glance found the downed guard, its shout (from its post, 4 m from the hub door) sent searchers to the doorway, and one saw the player at spawn (any sighting while Searching alerts). Fixed in level data (post turned 30°) with a hub-start regression test. Open: Searching still alerts on any glimpse through a doorway (question to the user).
- Terminal too rough: redesigned with Camera and Network tabs, statuses from components, offline instead of broken, Esc only; network debug overlay (ADR 0083). Booth devices labelled.
- Process: the bug brief's "reproduce the exact situation first, record the EventLog" found the real cause (my guesses, the new base station and DoorOpener, were wrong). Worktrees for three agents were cut from an old M1 commit; each agent noticed and reset to master. Briefs should say "branch from master" and agents should check `git log -1` first (added to CLAUDE.md).
- Full suite on master after all merges: 1222 tests, 0 failures, 723 s wall with another agent running Godot.

### Test speed kaizen (2026-11-09)

- Full suite from a 705 s median (2 of 3 baseline runs red) to about 41-45 s, green 3x in a row (ADR 0084, design/tech/test-speed-kaizen.md): simulated fixed-fps time instead of real-time frame sleeps, 11-12 parallel shards balanced on measured wall time, Godot output to a file instead of a pipe (each print cost 2-13 ms through the pipe), import only when class declarations or non-script files change. Root-caused two flaky tests (a navigation map switched to synchronous mid-iteration; an EventLog clear racing a guard's engagement). Guidelines for agents: design/tech/testing.md "Writing fast tests"; AGENTS.md checklist.
- What went wrong: the first agent was cut off when the session restarted (in-process agents die with it); a second resumed from its worktree commits. Lesson: long agents commit in small steps so a restart loses little (they did).
- Open: `hub_start_guards_test` (34 s, one 60 s simulation) and `movement_course_test` set the floor; reusing a loaded hub across tests would change isolation. Not done.

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

### Playtest feedback (2026-11-08)

- Bug: baton hits knocked the player out (stun 60 after three hits) with no screen and nothing to wake them: stuck. Fixed with a "Knocked out" losing screen driven by `state.unconscious` (ADR 0071 amendment). The pistol only kills (no stun).
- Why it slipped: the player-is-not-special rule gave the player the NPC knockout, but the HUD only listened to `died`. Tests covered guard knockouts, never the player's. Process change: a brief that lets a new state reach the player (a tag that stops input) also asks for the player-facing UI and a test that the player can always leave it (wake, reload or load).

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
