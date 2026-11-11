# Saving

Milestone: contract in M0; save/load in M6 (Esc game menu after the M6 playtest).

## Purpose

Every stateful system is saveable from day one so saving and loading never need retrofitting ([ADR 0025](../decisions/0025-saving.md)). Save and load: [ADR 0063](../decisions/0063-quicksave-quickload.md); the game menu: [ADR 0064](../decisions/0064-game-menu.md).

## Player-facing behaviour

- **Esc** opens the game menu (pauses, frees the mouse; not over the Tab interface, the reading overlay, the keypad, a computer or the lockpicking screen, which Esc closes instead ([ADR 0110](../decisions/0110-tab-interface.md)); not while the debug panel is open): **Resume**, **Save**, **Load**, **Quit game**. Esc or Resume closes it. One slot.
- **Save** writes the slot; the menu stays open and says "Saved". Refused while dead ("Cannot save while dead") or knocked out ("Cannot save while knocked out").
- **Load** is disabled when there is nothing loadable; the line under it says "Saved 14:32 · Hub" (local time, level) or why not: "No save", "Save is damaged", "Save is from another version", "Saved level not found". Load closes the menu, loads, and the HUD says "Loaded".
- **Quit game** asks "Quit? Unsaved progress is lost." (Yes / No, No focused; Esc = No); Yes quits.
- The death screen ("You died") and the knocked-out screen ("Knocked out") say "E: restart level · Esc: menu": the menu opens there and its Load works.
- A load puts back the level as it was saved: what was broken, burnt, exploded or picked up stays gone; dropped items, broken-crate contents and debug-spawned objects are back; fires, health, inventory, the item in hand and the personal log are as saved. Something carried at save time lies where it was held (it falls in front of you).
- Death leads to reset (E) or Load from the game menu (Esc) ([../levels/mission-warehouse.md](../levels/mission-warehouse.md)).
- **Levels** (M9, [ADR 0087](../decisions/0087-mission-systems.md)): the slot is shared by every level and records the one it was saved in ("Saved 14:32 · Warehouse"). Loading it from anywhere (the hub, a mission, a losing screen) loads that level, then restores it: in the mission, the timer, objectives done, tallies and badges so far, the first alarm and whether the reinforcements came are back; the briefing does not open again. Saving is not possible on the briefing or the summary (the game menu does not open over them).

## Rules

- Nodes in group `saveable` implement `save_state() -> Dictionary` and `load_state(data: Dictionary) -> void`.
- Save code lives in `core/save/`: `SaveFile` (format), `LevelSnapshot` (capture / apply), `QuickSave` (slot, save and load flow; static, no autoload). The player's `GameMenu` (`ui/game_menu/`, texts in `GameMenuRules`) calls it.
- File: `user://saves/quicksave.save`, JSON of `JSON.from_native()` (Godot types kept, objects never read back), header `{version, level, saved_at}`, plus `stimulus_ids`: the last stimulus id of the saving session (M9). A load reserves the ids up to it (`StimulusSystem.reserve_ids()`) before restoring, so stimulus ids kept in saved state (a fire's ignition, a turret's cause, the mission's attributed ids) never name a stimulus of the new session.
- A save holds, by node path relative to the level root: `states` of every saveable under the current scene; `removed` level-placed entities (from the level's packed scene) that are gone; `spawned` entity roots not in the packed scene, with their scene file.
- Load: change to the saved level, pause, free removed, recreate spawned, `load_state()` in tree pre-order (parents before children), wait 3 physics frames (CSG collision), rebake the navmesh if level geometry was removed, clear stimuli, unpause. Paths that no longer exist are skipped with a warning.
- Logged: `game.saved` and `game.loaded` (`{level, saveables, removed, spawned}`, plus `skipped` on load).
- Systems that must comply: player ([movement.md](movement.md), done in M1), attributes ([attributes-and-tags.md](attributes-and-tags.md)), inventory ([inventory.md](inventory.md); M5: inside `Player.save_state()` as `inventory {inventory, belt, in_hand}`, world pickups save `ItemPickup` count and state; the player's `WeaponHolder` is no longer saveable itself, its magazine lives on the pistol stack), health ([damage.md](damage.md)), AI ([perception-and-ai.md](perception-and-ai.md)), objects ([objects-and-fire.md](objects-and-fire.md); M3: `PhysicsObject` saves `scene_file_path`, transform and velocities, `Flammable` and `Explosive` their fire state; a carried object is dropped on load), the personal log ([ADR 0060](../decisions/0060-datapads-read-in-place-personal-log.md)), abilities ([abilities.md](abilities.md), M6: `Skills` saves the tiers, `Augmentations` the installed and active ids; `Energy` is not saveable itself, the charge is the base of the `energy` attribute and is saved with `Attributes`). Computers ([ADR 0114](../decisions/0114-computers-halcyon-os.md)): `Computer` saves its open session (`session_user`); what the player read on it is in the personal log. `Tags` and `Attributes` components are in group `saveable` (TagContainer/AttributeSet `to_dict()`/`from_dict()`).
- Derived state is re-derived on load, never added twice: `Attributes` and `Tags` restore their saved modifiers and tags, then `Skills` and `Augmentations` (later in tree order) replace their own modifiers by source (`skill.<id>`, `aug.<id>`) and set their tags (`state.cloaked`) from the loaded state. The load keeps the tree paused while it settles, so augmentations do not drain energy before the player can act. `tests/scenarios/quicksave_hub_test.gd` (Save and Load also through the game menu) checks tiers, energy, installed and active augmentations, tags and modifier counts after a quickload.
- Hacking (M12, [hacking.md](hacking.md)); everything is deterministic, so a load continues exactly:
  - network state: device power and links, firewall rules (M12a: `Router` saves its rules), patched devices, device logs (erased entries stay erased), who has which account on each device (`DeviceAccounts`: access and passwords, M12a), who knows each access point's Wi-Fi key (`AccessPoint`, M12b), discovered devices (greyed when access is lost: kept on the deck); wireless links are level data (`Device.wireless`), not saved;
  - known credentials and exploits: in the PersonalLog, like codes;
  - the deck's contents (copied files, Icebreaker progress per account, seen devices and scanned subnets, M12a; Wi-Fi crack progress per access point, M12b): in its stack's `state`, saved with the inventory; a load leaves the deck unplugged and off any Wi-Fi (plug it in or aim at the access point again: the crack resumes, a known key joins at once);
  - tracers: trace per tracer and user (and time since its last gain), lockouts (time left), whether the app runs (`Tracer`, M12a);
  - panic buttons and radio base stations switched off by a command (`DeviceSwitch`, M12a);
  - alarm devices (M8): the controller's ringing time left and incident point, disarmed state, silenced sirens.
- Missions (M9, [ADR 0087](../decisions/0087-mission-systems.md)): the `Mission` node saves time, objectives done, tallies (with the player's attributed stimulus ids), briefing seen, first alarm time and point, reinforcements sent, finished; reinforcements and dropped weapons are spawned entities; a guard's `WeaponHolder` saves the loadout it has left (`weapons`), so a guard that dropped its weapon stays unarmed; a turret saves its shots' cause.
- Not saved: the in-flight stimulus queue (`StimulusSystem.clear()` on load, M2), debris, fire / explosion effects and sounds, the EventLog, debug panel state.
- Contract tests are written with each feature; `tests/core/save/saveable_contract_test.gd` checks every scene's saveables round-trip.

## Open questions

- More slots, named saves, autosave on level change: not in v0.
- Carrying the player's state into another level: not in v0. M9 levels start fresh (the mission's fixed kit, [ADR 0087](../decisions/0087-mission-systems.md)).
