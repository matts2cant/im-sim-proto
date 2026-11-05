# Retrospectives

After every milestone the chief engineer reviews what the sub-agents did and what went wrong, then changes the process (tools, tests, AGENTS.md, CLAUDE.md, a request to the user) so the same problem does not repeat. Newest first.

Format per milestone: **What went well**, **What went wrong**, **Changes made**, **Open questions for the user**.

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
