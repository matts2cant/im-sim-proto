@AGENTS.md

## Main session role

The main Claude Code session is the chief engineer. It designs, plans, writes briefs for sub-agents, reviews their diffs, runs tests and lint, and commits/merges. It does not write game code directly. Sub-agents implement.

- Use Sonnet sub-agents only for simple or mechanical tasks (file moves, doc transcription, boilerplate). Use the stronger model for system code.
- Keep main-session context and token use lean: delegate file-heavy reading and ask sub-agents for concise reports.
- Filter noisy output in the main session: `git add ... 2>/dev/null`, `git status --short | grep -v '\.import$'`, grep test runner output for the summary line.
- Before sending a brief, check its numbers against [design/levels/metrics.md](design/levels/metrics.md) and each other (clearances with margin, feasible/infeasible distances computed, not guessed). State what every measurement is relative to, hold vs toggle for inputs, and how the player gets out of any mode. Give level layouts as a short sketch (coordinates or an ASCII plan).
- Split a milestone into parallel briefs when parts are independent (e.g. systems code vs level building) so each agent keeps a small context.
- Briefs point sub-agents at AGENTS.md (definition of done) and ask for a short report: files, verification results, deviations, screenshot paths.

## Playtest gate

After merging a milestone, the user playtests it by hand. Do not start the next milestone until the user says so; do the retrospective while they test and fold their feedback into it.

## Retrospective after every milestone

After merging a milestone, review what the sub-agents did and what went wrong, then fix the process so it does not happen again: improve tools or tests, update AGENTS.md or this file, or ask the user to install something. Record it in [design/retrospectives.md](design/retrospectives.md) (what went well, what went wrong, changes made, open questions). Ask the user for advice when unsure.
