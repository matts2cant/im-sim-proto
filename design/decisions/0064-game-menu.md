# 64. Esc game menu: save, load and quit; F5 becomes Combat Strength

Status: Accepted

Date: 2026-11-06

## Context

M6 shipped F5 quicksave and F9 quickload ([ADR 0063](0063-quicksave-quickload.md)), read by a `QuickSaveKeys` node on the player. After the M6 playtest the user asked to move save and load into a game menu opened with Esc, with a quit button, and to put Combat Strength on F5 (it was on F6 only because F5 was taken, which left a gap in F1-F6).

## Decision

- **Game menu** (`GameMenu`, `ui/game_menu/game_menu.tscn`, instanced in `player.tscn` in place of `QuickSaveKeys`; texts in `GameMenuRules`). It is a pause screen like the inventory and the log ([ADR 0052](0052-inventory-pauses-the-game.md)): group `pause_screen`, `PauseScreens.update()` pauses the tree and frees the mouse, closing restores the previous mouse mode (captured in play) and the player resyncs its held actions.
- **Esc** (`ui_cancel`) opens it only when no other pause screen is open, the debug panel is closed, the player's input is enabled and no load is running. Esc on the inventory, log screen or reading overlay closes that screen only (whichever node sees the event first, the other cannot act: the menu does not open over an open screen, and an open screen consumes the Esc). Esc or Resume closes the menu; on the quit question Esc means No. Other pause screens do not open over the menu. It opens on the death screen.
- **Buttons**, keyboard and mouse (Resume has focus on open; focus is released on close so Space/Enter do not press a hidden button):
  - **Resume**.
  - **Save**: writes the one slot (`QuickSave.save_game`), the menu stays open with "Saved"; refused while dead ("Cannot save while dead") or while a load runs. Saving with the menu open is fine: the menu is the only pause screen then and the snapshot does not depend on the pause.
  - **Load**: enabled only when `QuickSave.check()` is OK. The line under it reads "Saved 14:32 · Hub" (the header's UTC `saved_at` shown in local time; the level scene's file name, capitalised) or why there is nothing to load ("No save", "Save is damaged", "Save is from another version", "Saved level not found"). Load starts `QuickSave.load_game`; the menu leaves the tree with the old level (unpausing as it goes), and the new player's menu shows "Loaded" on the HUD (`on_quickloaded`, group `quickload_listener`).
  - **Quit game**: swaps the buttons for "Quit? Unsaved progress is lost." with Yes / No (No focused). Yes emits `quit_requested` and calls `SceneTree.quit()` (tests set `quit_on_confirm = false`).
- **Death screen**: "E: restart level · Esc: menu" (E still reloads the level; F9 is gone).
- **Keys**: the `quicksave` (F5) and `quickload` (F9) actions are removed; `aug_5` (Combat Strength) moves from F6 to **F5**. HUD chips and the Stats tab read the key from the input map, so they say "F5 Combat Strength"; the gallery signs were changed to match.
- Player-facing text says "save" / "load", never "quicksave". Internal names (`QuickSave`, `quicksave.save`, `on_quickloaded`, `tests/scenarios/quicksave_hub_test.gd`) stay to avoid churn.

## Alternatives considered

- **Keep F5/F9 as shortcuts next to the menu**: the user asked to move the feature, and F5 is wanted for Combat Strength.
- **A `ConfirmationDialog` for quit**: a popup window with the default theme; swapping the menu's buttons for the question keeps the style and keyboard focus simple.
- **A separate node owning the menu (like `QuickSaveKeys`)**: the menu itself is the only Esc handler that needs it; one node fewer.
- **Disable Save while dead**: the brief asked for a refusal with a message, consistent with how Load explains why it is disabled.

## Consequences

- Amends [ADR 0063](0063-quicksave-quickload.md) (keys, HUD texts, death overlay) and [ADR 0061](0061-abilities-model.md) (Combat Strength key) and [ADR 0025](0025-saving.md) (F5/F9).
- Esc no longer frees the mouse in play by itself: it opens the menu, which frees it.
- `tests/ui/game_menu/` covers the menu; `tests/scenarios/quicksave_hub_test.gd` drives Save and Load through it on the hub.
- See [saving](../game/saving.md), [controls](../game/controls.md).
