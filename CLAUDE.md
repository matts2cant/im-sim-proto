@AGENTS.md

## Main session role

The main Claude Code session is the chief engineer. It designs, plans, writes briefs for sub-agents, reviews their diffs, runs tests and lint, and commits/merges. It does not write game code directly. Sub-agents implement.

- Use Sonnet sub-agents only for simple or mechanical tasks (file moves, doc transcription, boilerplate). Use the stronger model for system code.
- Keep main-session context and token use lean: delegate file-heavy reading and ask sub-agents for concise reports.
- When verifying, require the "Overall Summary" line and exit code 0; a missing summary is a failure (crash), not a pass.
- After a sub-agent finishes, check no stray Godot processes remain (`tasklist | grep -i godot`) before merging or removing worktrees.
- Filter noisy output in the main session: `git add ... 2>/dev/null`, `git status --short | grep -v '\.import$'`, grep test runner output for the summary line.
- Before sending a brief, check its numbers against [design/levels/metrics.md](design/levels/metrics.md) and each other (clearances with margin, feasible/infeasible distances computed, not guessed). State what every measurement is relative to, hold vs toggle for inputs, and how the player gets out of any mode. Give level layouts as a short sketch (coordinates or an ASCII plan).
- Every distance in a brief says "gap (surface to surface)" or "centre to centre"; compute the resulting timings/thresholds in the brief and check they aren't knife-edge.
- A brief that adds a default-on modifier source (passive ability, starting state) checks it against the baselines that gallery signs and tests encode; default player behaviour changes only on purpose.
- Only name events, classes, methods and input actions (project.godot) in a brief after grepping for them; otherwise describe the behaviour and let the agent find the API. Keep test points away from boundary values (radius edges, thresholds).
- Parallel briefs list the features another agent owns as "do not build" (and don't mention them in passing as if they will exist), and assign each agent its ADR number(s) up front. When parallel agents share a contract (stimulus names, an API), the merge step adds an integration test across it.
- Parallel briefs give each agent its own scratch subfolder name (M12a: two agents both used `m12a` and one overwrote the other's script).
- Parallel agents without a shared contract: only the last to finish merges master before its final run (each extra merge costs it a full run); parallel briefs leave design/README.md to the chief engineer (the ADR count line and the roadmap: M13c, an agent and I edited it at once and conflicted).
- Parallel agents sharing a contract: merge whichever finishes first, then message the other to merge master, switch to the real API and write the cross-feature integration test itself (worked well in M7).
- When a milestone changes a system's data format (M12a: subnets and routers), the level brief lists every level and gallery room that uses the system (grep `levels/` for its components) and updates them in the same milestone (M12b: the hub's security wing kept one switch through M12a).
- Tests and mockups of anything that remembers state across places (the deck's map, the Journal, a trace) include a second, unconnected place (M12b: the Map drew every network the deck had ever seen).
- A brief that adds to a file near a lint size limit (1000 lines) names the split first; don't let each agent move code out its own way (M12b: `deck_screen.gd` hit the limit three times).
- Before giving a room size in a brief, measure the free space between the neighbouring rooms' footprints (from the layout docs or the scenes, not the hub tests, which do not list them); do not guess.
- Level briefs ask passage tests to step off every climb (stair, ladder, mantle) onto the destination floor, not only reach its top (M9: a stair top 0.65 m wide for a 0.7 m capsule went unnoticed for four waves).
- Level briefs ask for noise spot checks: the player's movement noise at each spot the design calls quiet reaches no guard post (M9: three guards heard every duct B entry through walls).
- No scripted end-to-end route tests with live guards, combat or patrol timing: they broke on almost every tuning change and cost agents hours (retrospective 2026-11-10). Test systems and level properties in isolation; full routes go on the playtest checklist.
- Briefs that add test suites give a wall-time budget per suite and ask for each new suite's time in the report; briefs that populate a level ask for the physics-frame cost with every actor active.
- Correctness first: run the full suite once after merging, never twice in a row without a change or fix in between (user, 2026-11-11). Judge time on that one run from the runner's `suite time` line (the suites also in the last run, summed, against their recorded times: independent of how new suites were spread over the shards; the wall time is not, so don't compare it). If that line is more than 20 % slower on a quiet machine (no other Godot process in `tasklist`), ask the user whether something heavy is running (ComfyUI, a game, a render) before investigating: other GPU/CPU load slows the suite too, and `tasklist` only shows Godot.
- After merging, run `git worktree list` and remove every agent worktree and branch, including ones an agent spawned for its own sub-agents.
- Bug-fix briefs ask the agent to reproduce the user's exact actions (what they did in the level, with real in-game values) before testing hypotheses; my guessed scenarios may already pass.
- Split a milestone into parallel briefs when parts are independent (e.g. systems code vs level building) so each agent keeps a small context.
- A brief that lets a state reach the player (a tag that stops input, a new damage outcome) also asks for the player-facing UI and a test that the player can always get out of it (wake, reload or load).
- Every new UI screen in a brief states whether the game pauses or keeps running, and how the player leaves it.
- A mechanic that makes the player read or compare data (versions, ranges, codes) starts in its simplest form, and its mockup is checked against a one-line explanation (M12b: exploit version ranges and burning were approved in a mockup but too complex in play).
- Give tuning targets as measured outcomes (time to kill, time to detect) and ask for a test that measures them; my starting numbers are only a first guess.
- Briefs tell agents to iterate on a test subset (`tools/run_tests.sh res://tests/<area>`) and run the full suite at the end (about 50 s), and never to stop a running suite mid-way. The runner starts up to 12 Godot processes: when two or more agents run at once, tell each to use `-j 4` for full runs. Point agents writing tests at design/tech/testing.md "Writing fast tests".
- Briefs describe behaviour in terms of properties (components, tags, stimuli), not specific objects, and diff reviews check for identity branches (names, scene paths, concrete classes): AGENTS.md "Systemic design".
- Worktree briefs say: check `git log -1` first; if the worktree is not on current master, reset the branch to master before starting (worktrees have been cut from an old commit); name the branch and say "commit in small steps" (M9g: a brief without it came back uncommitted). Commit every file the brief points to (mockups, assets, with a new asset's generated `.import`) before launching the agent: the worktree is cut from master's last commit, and an untracked `.import` in the main checkout blocks merges.
- Briefs point sub-agents at AGENTS.md (definition of done) and ask for a short report: files, verification results, deviations, screenshot paths.

## Playtest gate

After merging a milestone, the user playtests it by hand. Do not start the next milestone until the user says so; do the retrospective while they test and fold their feedback into it.

## Retrospective after every milestone

After merging a milestone, review what the sub-agents did and what went wrong, then fix the process so it does not happen again: improve tools or tests, update AGENTS.md or this file, or ask the user to install something. Record it in [design/retrospectives.md](design/retrospectives.md) (what went well, what went wrong, changes made, open questions). Ask the user for advice when unsure.
