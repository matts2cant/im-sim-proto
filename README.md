# ImSimProto

A first-person immersive sim prototype inspired by Deus Ex (2000), built around systemic, emergent gameplay. v0 is a hub, a test gallery (one room per system) and one small mission area where the systems combine.

## Requirements

- Godot 4.7.2, standard build (not .NET)
- Python 3.12 (dev tooling only, not a game dependency)

## Open and run

Open the project folder in Godot 4.7.2 (`project.godot`) and press F5, or import it from the Godot project manager.

The Godot binary used by the scripts is read from the `GODOT_BIN` environment variable. If unset, it defaults to `C:\Program Files\Godot\Godot_v4.7.2-stable_win64_console.exe`.

## Dev tooling setup

```sh
py -3.12 -m venv .venv
.venv/Scripts/pip install -r tools/requirements-dev.txt
tools/install_hooks.sh
```

`tools/install_hooks.sh` sets git `core.hooksPath` to `tools/hooks` (format + lint pre-commit hook).

## Tests and lint

```sh
tools/run_tests.sh                       # all GdUnit4 tests, headless
tools/run_tests.sh res://tests/core      # a subset
tools/lint.sh                            # gdformat --check + gdlint (addons excluded)
tools/lint.sh --fix                      # format in place
tools/gen_api_docs.sh                    # Godot 4.7.2 API reference into .api-docs/ (for agents)
tools/screenshot.sh res://levels/hub/hub.tscn  # render a scene's last frame to reports/screenshots/
```

See [design/tech/testing.md](design/tech/testing.md).

## Repo layout

| Path | Contents |
|---|---|
| `core/` | Framework only, no game content: `stimulus/`, `attributes/`, `event_log/`, `save/` |
| `actors/` | `player/`, `guard/` |
| `objects/` | Crates, barrels, doors, lights, ... |
| `items/` | Inventory items |
| `ui/` | `hud/`, `debug_panel/` |
| `levels/` | `hub/`, `gallery/<room>/`, `mission/` |
| `tests/` | Mirrors the source tree; `scenarios/` for scenario tests |
| `tools/` | Scripts (`run_tests.sh`, `lint.sh`, `hooks/`) |
| `design/` | Design docs and ADRs |
| `assets/` | Third-party media (audio) |
| `addons/` | gdUnit4, csg_blockout (do not edit) |

## Documentation

Start at [design/README.md](design/README.md). Agents: see [AGENTS.md](AGENTS.md).
