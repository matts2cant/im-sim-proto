# Saving

Milestone: contract in M0; save/load in M6 (Esc game menu after the M6 playtest).

## Purpose

Every stateful system is saveable from day one so saving and loading never need retrofitting ([ADR 0025](../decisions/0025-saving.md)). Save and load: [ADR 0063](../decisions/0063-quicksave-quickload.md); the game menu: [ADR 0064](../decisions/0064-game-menu.md).

## Player-facing behaviour

- **Esc** opens the game menu (pauses, frees the mouse; not over the inventory, log screen or reading overlay, which Esc closes instead; not while the debug panel is open): **Resume**, **Save**, **Load**, **Quit game**. Esc or Resume closes it. One slot.
- **Save** writes the slot; the menu stays open and says "Saved". Refused while dead ("Cannot save while dead") or knocked out ("Cannot save while knocked out").
- **Load** is disabled when there is nothing loadable; the line under it says "Saved 14:32 · Hub" (local time, level) or why not: "No save", "Save is damaged", "Save is from another version", "Saved level not found". Load closes the menu, loads, and the HUD says "Loaded".
- **Quit game** asks "Quit? Unsaved progress is lost." (Yes / No, No focused; Esc = No); Yes quits.
- The death screen ("You died") and the knocked-out screen ("Knocked out") say "E: restart level · Esc: menu": the menu opens there and its Load works.
- A load puts back the level as it was saved: what was broken, burnt, exploded or picked up stays gone; dropped items, broken-crate contents and debug-spawned objects are back; fires, health, inventory, the item in hand and the personal log are as saved. Something carried at save time lies where it was held (it falls in front of you).
- Death leads to reset (E) or Load from the game menu (Esc) ([../levels/mission-warehouse.md](../levels/mission-warehouse.md)).

## Rules

- Nodes in group `saveable` implement `save_state() -> Dictionary` and `load_state(data: Dictionary) -> void`.
- Save code lives in `core/save/`: `SaveFile` (format), `LevelSnapshot` (capture / apply), `QuickSave` (slot, save and load flow; static, no autoload). The player's `GameMenu` (`ui/game_menu/`, texts in `GameMenuRules`) calls it.
- File: `user://saves/quicksave.save`, JSON of `JSON.from_native()` (Godot types kept, objects never read back), header `{version, level, saved_at}`.
- A save holds, by node path relative to the level root: `states` of every saveable under the current scene; `removed` level-placed entities (from the level's packed scene) that are gone; `spawned` entity roots not in the packed scene, with their scene file.
- Load: change to the saved level, pause, free removed, recreate spawned, `load_state()` in tree pre-order (parents before children), wait 3 physics frames (CSG collision), rebake the navmesh if level geometry was removed, clear stimuli, unpause. Paths that no longer exist are skipped with a warning.
- Logged: `game.saved` and `game.loaded` (`{level, saveables, removed, spawned}`, plus `skipped` on load).
- Systems that must comply: player ([movement.md](movement.md), done in M1), attributes ([attributes-and-tags.md](attributes-and-tags.md)), inventory ([inventory.md](inventory.md); M5: inside `Player.save_state()` as `inventory {inventory, belt, in_hand}`, world pickups save `ItemPickup` count and state; the player's `WeaponHolder` is no longer saveable itself, its magazine lives on the pistol stack), health ([damage.md](damage.md)), AI ([perception-and-ai.md](perception-and-ai.md)), objects ([objects-and-fire.md](objects-and-fire.md); M3: `PhysicsObject` saves `scene_file_path`, transform and velocities, `Flammable` and `Explosive` their fire state; a carried object is dropped on load), the personal log ([ADR 0060](../decisions/0060-datapads-read-in-place-personal-log.md)), abilities ([abilities.md](abilities.md), M6: `Skills` saves the tiers, `Augmentations` the installed and active ids; `Energy` is not saveable itself, the charge is the base of the `energy` attribute and is saved with `Attributes`). `Tags` and `Attributes` components are in group `saveable` (TagContainer/AttributeSet `to_dict()`/`from_dict()`).
- Derived state is re-derived on load, never added twice: `Attributes` and `Tags` restore their saved modifiers and tags, then `Skills` and `Augmentations` (later in tree order) replace their own modifiers by source (`skill.<id>`, `aug.<id>`) and set their tags (`state.cloaked`) from the loaded state. The load keeps the tree paused while it settles, so augmentations do not drain energy before the player can act. `tests/scenarios/quicksave_hub_test.gd` (Save and Load also through the game menu) checks tiers, energy, installed and active augmentations, tags and modifier counts after a quickload.
- Hacking (M11, [hacking.md](hacking.md)); everything is deterministic, so a load continues exactly:
  - network state: device power and links, firewall rules, patched devices, device logs (erased entries stay erased), discovered devices (greyed when access is lost);
  - known credentials and exploits: in the PersonalLog, like codes;
  - the deck's contents (copied files, Icebreaker progress per account): in its stack's `state`, saved with the inventory;
  - tracers: trace per tracer, lockouts (time left), whether the app runs;
  - alarm devices (M8): the controller's ringing time left and incident point, disarmed state, silenced sirens.
- Not saved: the in-flight stimulus queue (`StimulusSystem.clear()` on load, M2), debris, fire / explosion effects and sounds, the EventLog, debug panel state.
- Contract tests are written with each feature; `tests/core/save/saveable_contract_test.gd` checks every scene's saveables round-trip.

## Open questions

- More slots, named saves, autosave on level change: not in v0.
- Saving across level transitions (carrying the player's state into another level) waits for M9.
