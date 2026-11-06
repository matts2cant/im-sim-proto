# 63. Quicksave and quickload: one JSON slot, level snapshot with removed and spawned nodes

Status: Accepted

Date: 2026-11-06

## Context

Every stateful node has been saveable since M0 ([ADR 0025](0025-saving.md)): it is in group `saveable` and implements `save_state() -> Dictionary` / `load_state(data)`. M6 adds F5 quicksave and F9 quickload. Open points: the file format and location, how a level is rebuilt (things get destroyed and created at runtime), the order states are applied in, and how to do it without a fourth autoload.

## Decision

- **Slot and format.** One slot, `user://saves/quicksave.save` (`QuickSave.path`; tests point it elsewhere). The file is JSON text of `JSON.from_native(data)` (`SaveFile`, `core/save/save_file.gd`): Godot types survive (Vector3, Transform3D, StringName, int vs float, typed arrays and dictionaries, int keys), it is readable and diffable, and `JSON.to_native` is called without objects, so a save file can never make the game instantiate anything. `var_to_str` / `str_to_var` was rejected after a probe: `str_to_var('Object(Node, ...)')` instantiates the object (with a script, that runs code). Floats keep 17 digits (a double may lose its last bit; component states compare with a tolerance). Header: `{version, level, saved_at}`; `SaveFile.VERSION` = 1. A save of another version is refused ("Quicksave is from another version"), not migrated; a missing file says "No quicksave", an unparsable or malformed one "Quicksave is damaged". Nothing changes when a load is refused.
- **Snapshot** (`LevelSnapshot`, `core/save/level_snapshot.gd`), all paths relative to the level root:
  - `states`: path -> `save_state()` of every node in group `saveable` under the current scene (nodes queued for deletion are skipped).
  - `removed`: level-placed entities that no longer exist (broken or burnt crates, exploded barrels, the burnt barricade, consumed pickups). "Level-placed" comes from a **packed index**: the level's PackedScene instantiated once out of the tree (no `_ready` runs), every node's path and `scene_file_path` listed, then freed; cached per scene path (about 150 ms for the hub, once per session). A packed path whose subtree has a node with `save_state()` and that is missing (or replaced by a node of another scene) is removed; only the topmost missing node of each is listed. Paths without a saveable in their subtree are ignored, so kit parts regenerating their internal CSG never count.
  - `spawned`: path -> scene file of every entity root that is not in the packed scene: the topmost ancestor of a saveable whose path is not level-placed (dropped pickups, debug-spawned objects, broken-crate contents). Its parent is always level-placed. A live node only counts as level-placed when its path is in the index **with the same scene file**, so a spawned box that took the name of a removed crate is saved as removed + spawned.
- **Load order** (`QuickSave.load_game`, a static coroutine; no autoload, it awaits `SceneTree.scene_changed`):
  1. Read and check the file (version, header, snapshot shape) and that the saved level scene exists.
  2. `Engine.time_scale = 1`; `LevelReset.load_level(tree, level)` drops queued stimuli and changes to a fresh instance of the saved level (the same or another one). The old level leaves the tree at once, which closes the pause screens (they unpause on `_exit_tree`).
  3. On `scene_changed` (the new level's `_ready` has run): pause the tree (physics holds), then `LevelSnapshot.apply`: free the removed nodes (`free()`, at once, so their names are free), recreate the spawned ones from their scene under the same parent with the same name (sorted by path; one that already exists, made by the level itself, is reused), then `load_state()` in **tree pre-order** (parents before children, siblings in tree order: the Player before its Tags / Attributes / BodyParts, so raw component data is applied last and wins over anything the parent's load re-derived).
  4. Wait 3 physics frames, still paused: kit CSG builds its collision deferred.
  5. If a removed node held level geometry (a StaticBody3D or a CSG collider, e.g. the burnt barricade), call `bake()` on nodes in group `rebake_after_load` (`LevelNavigation` joins it).
  6. `StimulusSystem.clear()`, unpause, log `game.loaded {level, saveables, removed, spawned, skipped}`, call `on_quickloaded()` on group `quickload_listener` (the player's `GameMenu` shows "Loaded", [ADR 0064](0064-game-menu.md)).
  A saved path that no longer exists (the level was edited since) is skipped with a `push_warning`, never an error. `game.saved` is logged on save with the same counts.
- ~~**Keys** (`QuickSaveKeys`, a node appended to `player.tscn`, `PROCESS_MODE_ALWAYS`): F5 (`quicksave`) is refused silently while dead, while a pause screen (inventory, reading overlay, log screen) is open, while input is disabled or a load is running; F9 (`quickload`) works anywhere, including pause screens and the death screen (its overlay now says "F9: load quicksave"). HUD: "Quicksaved", "Quickloaded", "No quicksave" (or the reason above).~~ Superseded by [ADR 0064](0064-game-menu.md): Save and Load are buttons in the Esc game menu, F5/F9 are gone.
- **Not saved**: the stimulus queue (cleared); `Debris` (cosmetic, no layers), fire and explosion effects (Flammable restarts its effect from its state; explosion FX live under the viewport), sounds; anything outside the current scene; the held state of a carried object (it is saved where it is held, as a normal prop, and is dropped there on load: the player and props do not collide in the solver, ADR 0054); the EventLog; the debug panel state (the Time tab's slider is not refreshed by the time-scale reset); the player's spawn point for fall respawns (the level's own).

## Alternatives considered

- **`var_to_str` text**: exact floats and smaller files, but `str_to_var` deserialises objects; filtering `Object(` / `Resource(` out of the text is fragile.
- **Binary `var_to_bytes`** (objects off by default): safe and exact, but not readable or diffable.
- **Recording removals as they happen** (every component reports "I was destroyed"): every destroying code path would need to remember it, and the record would need a home that survives the level (an autoload). Comparing with the packed scene finds every removal with no cooperation.
- **`SceneState` walk instead of instantiating**: avoids the one-time instantiate, but nested instances need recursive SceneState walks and the scripts (which tell whether a subtree has saveables) are only properties there.
- **Applying states over several frames, unpaused**: physics would move restored bodies before the CSG collision exists.
- **Objects before the player**: no dependency needs it; pre-order is deterministic for any level without special cases.

## Consequences

- New stateful components only need the contract; `tests/core/save/saveable_contract_test.gd` instantiates every scene under `levels/`, `objects/`, `actors/` and `items/` and checks each saveable's state round-trips into a fresh instance.
- Saves depend on node paths: renaming or moving level nodes invalidates those entries (skipped with a warning). Bump `SaveFile.VERSION` when a component's saved data changes incompatibly.
- Freeing removed props right after their `_ready` exposed `ImpactNoise` orphaning its deferred audio player; it now frees it on predelete.
- See [saving](../game/saving.md).

## Amended (2026-11-06)

Save and load moved into the Esc game menu with a Quit button ([ADR 0064](0064-game-menu.md)): the F5/F9 actions and `QuickSaveKeys` are removed, player-facing texts say "save" ("Saved", "Loaded", "No save", "Save is damaged", ...), the death overlay says "E: restart level · Esc: menu", and F5 now toggles Combat Strength. The slot, format and load order are unchanged.
