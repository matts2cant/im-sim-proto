# 110. The Tab interface: one host with data-driven tabs over the running world; only the game menu, briefing and summary pause

Status: Accepted (supersedes [ADR 0052](0052-inventory-pauses-the-game.md)'s pause for the inventory, and [ADR 0060](0060-datapads-read-in-place-personal-log.md)'s log screen and paused reading overlay)

Date: 2026-11-11

## Context

Up to M10 the inventory (I), the personal log (L), the datapad reading overlay and the keypad were separate pause screens ([ADR 0052](0052-inventory-pauses-the-game.md)), while the terminal and the lockpicking screen ran in real time with the player's input off. M11 adds Health, Augmentations and Skills screens; the user approved a mockup ([tab_interface.html](../prototypes/tab_interface.html)) that puts them all in one Deus Ex-style interface over the still running world, and settled the rules below. A later milestone adds a Map tab (M20).

## Decision

- **One host, tabs as data.** `TabInterface` (`ui/tab_interface/tab_interface.tscn`, a CanvasLayer child of the Player like the HUD) loads its pages from an exported list of scenes, in tab order: `tabs/inventory_tab.tscn`, `health_tab.tscn`, `augmentations_tab.tscn`, `skills_tab.tscn`, `journal_tab.tscn`. Each page is a `TabPage` (`tab_page.gd`): `tab_title()`, `bind(player)` once after it enters the tree, `on_shown()` each time it becomes the visible tab; pages update themselves in their own `_process` while visible, so they stay live while the world runs. Shortcut keys are data too (`shortcuts`: `inventory` -> 0, `personal_log` -> 4). The host never names a page: a new tab is one more scene in the list.
- **Opening and closing.** `tab_interface` (Tab) opens on the last tab used, Tab again closes. I and L open on their tab; open, they switch to it, or close when it already shows. Esc closes (taken first, so it never also opens the game menu; the next Esc does). A close button ends the tab bar. While open the belt keys 1-5 select a tab and `tab_prev` / `tab_next` (Q / E) step left / right, wrapping. Tab closes in `_input` so a focused control's focus navigation never eats it.
- **Not a pause screen.** The world keeps running. While open the player's input is off (`Player.input_enabled`, like the terminal), the mouse is free and the HUD hidden; closing restores all three at once and resyncs the held keys. A large panel (85 % of the screen) over the dimmed world. Getting hit does not close it: the screen edges flash red over the panel (`player.body.damaged`).
- **One screen at a time.** It opens only when the player can act, has its input, no pause screen is open and the debug panel is closed. Screens that turn the input off (terminal, lockpicking, keypad, reading overlay) therefore keep it shut, and while it is open none of them can open (they all start from the player's use or fire actions). It swallows the debug panel key while open. It closes when the player dies or is knocked out (their overlay shows; the game menu opens on Esc), so the player can always leave.
- **Only the game menu, the mission briefing and the summary pause.** The keypad and the datapad reading overlay stop pausing: they turn their user's input off and free the mouse, and close when the user can no longer act. `PauseScreens` keeps only those three. A consumable used from a screen is delivered at once (`StimulusSystem.emit_now`), so nothing relies on a paused tree.
- **Inventory tab** (replaces the inventory screen): the existing `InventoryView` (grid, drag and drop, attachments, tooltips; belt slots 40 px here) with a placeholder Credits box (M19), and a details panel for the selected stack. Its rows come from data through `ItemDetails`, never per item: a weapon's damage stimuli times the player's `<attribute_class>_damage_mult`, magazine current / max, the ammo item and how many are carried, the `fire_noise` stat (attachments applied), each attachment slot, the governing skill (the skill whose effects write `<attribute_class>_*`, `<tool_kind>_*` or the consumable's `use_scale_attribute`); a consumable's use stimuli times its scale attribute. Actions: Use or Equip / Put away by the item's use action, Drop, a belt-slot picker; the right-click menu is unchanged. Hover + a belt key no longer assigns (the number keys select tabs).
- **Journal tab** (replaces the log screen): Objectives (the level's `Mission`: title, a short briefing line, primary and secondary objectives with their state; none outside a mission), Codes and logins (every known code with what it opens, linking to its note), Notes (every entry newest first, with a reader). What a code opens is data: `Readable.code_labels` beside `codes`, carried by `LogEntry.code_labels` and saved; without a label the code id is shown in words.
- **Look**: `TabStyle`, the palette of the inventory view, belt, HUD and energy colours from the mockup; pages build their content in code with its helpers.

## Alternatives considered

- **Keep the inventory and log as pause screens**: the user wants the world to keep running (managing the inventory under fire is part of the tension, as with the lockpick and the terminal); only the game menu stops time.
- **A hard-coded tab switch in the host**: every new tab (the map in M20) would touch the host; a list of scenes keeps the host closed.
- **Block the debug panel by editing the DebugPanel autoload**: the host swallowing the toggle key while open needs no change to the autoload.
- **Name codes in a table keyed by code id**: a branch on ids; the label belongs next to the code in the readable's data.

## Consequences

- Tests: `tests/ui/tab_interface/` (open / close / switch rules, input and mouse, the world running, death and knockout, other screens, the debug key, the hit flash, the inventory tab's details and actions, the journal), and the keypad and datapad tests assert the world runs.
- The number keys no longer assign a hovered item to a belt slot.
- The Health, Augmentations and Skills tabs ([ADR 0111](0111-character-tabs-and-per-part-medkit.md)) are built against `TabPage`; `character_tabs_host_test.gd` drives them through this host (click and number keys, bound to the player, live energy drain and hits, a per-part medkit while the world runs). Pages show their own result messages, since the HUD is hidden while the interface is open.
