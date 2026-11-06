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
- Parallel agents sharing a contract: merge whichever finishes first, then message the other to merge master, switch to the real API and write the cross-feature integration test itself (worked well in M7).
- Before giving a room size in a brief, measure the free space between the neighbouring rooms' footprints (the hub tests list them); do not guess.
- After merging, run `git worktree list` and remove every agent worktree and branch, including ones an agent spawned for its own sub-agents.
- Bug-fix briefs ask the agent to reproduce the user's exact actions (what they did in the level, with real in-game values) before testing hypotheses; my guessed scenarios may already pass.
- Split a milestone into parallel briefs when parts are independent (e.g. systems code vs level building) so each agent keeps a small context.
- Briefs describe behaviour in terms of properties (components, tags, stimuli), not specific objects, and diff reviews check for identity branches (names, scene paths, concrete classes): AGENTS.md "Systemic design".
- Briefs point sub-agents at AGENTS.md (definition of done) and ask for a short report: files, verification results, deviations, screenshot paths.

## Playtest gate

After merging a milestone, the user playtests it by hand. Do not start the next milestone until the user says so; do the retrospective while they test and fold their feedback into it.

## Retrospective after every milestone

After merging a milestone, review what the sub-agents did and what went wrong, then fix the process so it does not happen again: improve tools or tests, update AGENTS.md or this file, or ask the user to install something. Record it in [design/retrospectives.md](design/retrospectives.md) (what went well, what went wrong, changes made, open questions). Ask the user for advice when unsure.
