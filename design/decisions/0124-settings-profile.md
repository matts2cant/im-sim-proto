# 124. Settings: a profile file, a static GameSettings, audio buses (M13a)

Status: Accepted (builds the settings menu of [ADR 0120](0120-weapon-feel.md))

Date: 2026-11-12

## Context

ADR 0120 asks for a settings menu nested in the Esc menu (paused; Back or Esc returns to it), stored in the player's profile, not in save games: mouse sensitivity, invert Y, field of view 70–100° (default 80), camera motion 0–100 %, master, effects and music volume, fullscreen, vsync. The project allows exactly three autoloads, had no audio bus layout (every sound played on Master) and keeps the look sensitivity in `player_config.tres` (0.0025 rad per pixel), which many tests use to compute expected turns.

## Decision

- **`GameSettings`** (`core/settings/game_settings.gd`): a static class, no autoload, like `QuickSave`. It loads `user://settings.cfg` (ConfigFile, sections `controls`, `view`, `audio`, `display`) on first use and applies every setting at once; a missing or unreadable file, a missing key or a value of the wrong type gives the default; numbers are clamped to their range. `set_value(key, value)` applies a change live and marks the profile dirty; the Settings screen writes the file when it closes (`save_if_changed()`), so dragging a slider does not write the file every frame. Getters per setting, including `camera_motion() -> float` (0..1) for the camera's shake, bob and recoil climb (M13a's recoil, M13b's weapon motion), never the bullets.
- **Change notification**: `GameSettings.notifier().changed(key)` after every live change. Consumers that read a value now and then call the getter each time (the look reads the sensitivity per mouse event); consumers that must react while the game is paused connect to it (the player's camera FOV follows the slider behind the dimmed menu).
- **Mouse sensitivity is a multiplier** (0.25–3.0, default 1.0) on the config's 0.0025 rad per pixel, so the tuning stays in the config and default behaviour is unchanged. It scales the turn and the aim cone's look bloom (the bloom follows the angle turned). Invert Y flips the pitch.
- **FOV** is the player's hip FOV; a scope's FOV stays fixed (15°), and look sensitivity through the scope keeps scaling with the camera's FOV over the hip FOV, so the crosshair moves as far on screen per pixel at any setting.
- **Audio buses**: `default_bus_layout.tres` adds `Effects` and `Music`, both sending to `Master`. Every sound player in the game today plays on `Effects` (`GameSettings.EFFECTS_BUS`); `Music` is ready for music (there is none yet). Volumes are linear 0..1 shown as percent, applied as `linear_to_db`, and a bus at 0 is muted.
- **Display**: fullscreen (borderless `WINDOW_MODE_FULLSCREEN`) or windowed, and vsync on or off, through `GameSettings.display` (`GameSettingsDisplay`), which only changes the window when it differs; tests swap it for a recording stand-in.
- **The Settings screen** (`ui/game_menu/settings_menu.gd` / `.tscn`) is part of the game menu's pause screen: it replaces the menu's panel, Back or Esc brings the panel back (still paused), closing the game menu also leaves it. Its rows are built from one table (sliders and switches); the game menu's look moved to a shared theme (`ui/game_menu/game_menu_theme.tres`).
- **Tests never use the real profile**: suites call `GameSettings.use_path("user://test_settings.cfg")` and switch back in `after_test`; `tools/run_tests.sh` already gives every shard its own `user://`.

## Alternatives considered

- **A fourth autoload for settings**: the three-autoload rule; a static class with lazy loading needs none.
- **Settings in the save game**: ADR 0120 keeps them in the profile, so loading an old save never changes the controls.
- **Sensitivity stored in rad per pixel**: unreadable in a menu, and every test computing turns from the config would have to read the setting.
- **Saving on every change**: a slider drag writes many times a second; saving on leaving the screen is enough.
- **Routing sounds by a scene-tree hook** (set the bus of every new audio player): implicit; each player names its bus instead.

## Consequences

- New sound players set `bus = GameSettings.EFFECTS_BUS` (or `MUSIC_BUS` for music); a player left on `Master` ignores the effects volume.
- A file ConfigFile cannot parse falls back to the defaults, but the engine prints its parse error.
- `tools/screenshot.sh` and windowed runs read the developer's real profile (fullscreen, FOV), unlike the test runner.
