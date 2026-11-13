# 133. UI plumbing: overlay focus, notices, user screens, view registries

Status: Accepted

Date: 2026-11-13

## Context

The code audit ([audit-2026-11-13.md](../tech/audit-2026-11-13.md), Q1-Q6, Q28-Q31) found the UI plumbing re-implemented per feature: seven overlays each saved and restored the player's `input_enabled`, the HUD's visibility and the mouse mode (restoring in the wrong order when two were open: a remote desktop over the deck), the input gate `input_enabled and not DebugPanel.is_open()` was repeated, the HUD listened to five `message` / `notice` signals (some emitted by classes that do not own them), world objects instanced or called concrete UI screens on their user, the computer's apps and the deck's tools were closed enums matched in several places, and panel styles were built in code.

## Decision

- **OverlayFocus** (`ui/window/overlay_focus.gd`, static, like `PauseScreens`): a screen that keeps the world running `acquire()`s the focus for its user (mouse mode, whether the HUD hides) and `release()`s it; the debug panel and `PauseScreens` `acquire_all()` (every user's input, the mouse). Holds are counted: the user's held keys are resynced, its HUD shows and the mouse returns to its mode from before the first hold once, when the last hold goes. The newest hold's mouse mode wins. Screens no longer write `Player.input_enabled` (left to cutscenes and tests); the player's gate is `Player.accepts_input()` (`input_enabled` and not `OverlayFocus.blocks_input()`); systems ask `OverlayFocus.is_held(entity)`, never a screen.
- **Notices** (`actors/common/notices/notices.gd`): one component on any entity, the only path for short player-facing notices. Systems call `Notices.send(entity, text)`; an entity without one is not told. The HUD and the raised deck (its toast) listen to it. A component's page may keep a local `message` signal for its own Tab page (`PlayerInventory`, `Augmentations`), sending the same text to Notices.
- **Screens and UserScreen** (`ui/window/screens.gd`, `user_screen.gd`): world objects and items ask for a screen by id, `Screens.open(user, KeypadLock.SCREEN, lock, options)`; the id constant lives with the requester (`KeypadLock.SCREEN`, `MechanicalLock.SCREEN`, `Computer.SCREEN`, `DeckSession.SCREEN`, `TuningDesk.SCREEN`). A screen is a `UserScreen` child of the user answering to the id (`screen_id()`, `open_screen()`, `close_screen()`, `shows()`); the user's optional `Screens` component instances registered scenes on first use (the Player's tuning panel). Each screen keeps its own pause and leave rules.
- **View registries**: the computer's apps are `ComputerApp` views registered by app id (`ComputerScreen._build_apps()`), the deck's tools a `DeckTool` registry by tool id (`DeckScreen._build_tools()`); a new app or tool is one registration. Item use is read through `ItemData` predicates (`is_weapon()`, `is_tool()`, `is_consumable()`, `use_label()`), not matched on the enum.
- **Panel styles in `.tres`**: the Tab interface and its pages (`ui/tab_interface/tab_theme.tres`: `Tab*`, `Character*`, `Journal*`), the mission screens (`ui/mission/mission_theme.tres`) and the lockpick caption (`ui/lockpick/lockpick_theme.tres`), like `window_theme.tres`. Only boxes coloured from data (a bar's fill, a skill cell's tint) and boxes drawn in `_draw()` stay in code.
- `PauseScreens` moves to `ui/window/`. `TimedLabel` (`ui/window/timed_label.gd`) is the feedback line that clears itself.

## Consequences

- Opening two overlays and closing them in either order restores everything once (`tests/ui/window/overlay_focus_test.gd`).
- While the deck is raised its notices also reach the hidden HUD: a notice in the last 2.5 s before lowering the deck is still fading above the belt afterwards.
- Tests check the gate with `player.accepts_input()`, not `input_enabled`.
