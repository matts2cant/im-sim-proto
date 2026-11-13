class_name QuickSave
extends RefCounted
## The quicksave slot (ADR 0063): `save_game()` writes the current level's snapshot (LevelSnapshot)
## to `path`; `load_game()` reloads the saved level and restores the snapshot onto it.
## Static, no autoload: the load outlives the scene it was started from (it awaits
## SceneTree.scene_changed in a static coroutine).
## The save records the level it was made in: loading it from any level (the hub, a mission) loads
## that level first.
## Load order: read and check the file (nothing changes on failure) -> reset Engine.time_scale ->
## change to the saved level (LevelReset.load_level, which drops queued stimuli; pause screens
## close as the old level leaves the tree) -> on scene_changed pause the tree (physics holds) ->
## reserve the saved stimulus ids (STIMULUS_IDS) -> LevelSnapshot.apply (free removed, recreate
## spawned, load_state in tree order) -> wait SETTLE_FRAMES physics frames (kit CSG collision
## builds deferred) -> if level geometry was removed, `bake()` every node in REBAKE_GROUP
## (LevelNavigation) -> clear stimuli -> unpause -> log `game.loaded` -> `on_quickloaded()` on
## every node in LOADED_GROUP (the player's HUD message).

## EventLog kinds this mechanism records (aliased by EventKinds).
const SAVED_KIND: StringName = &"game.saved"
const LOADED_KIND: StringName = &"game.loaded"
const DEFAULT_PATH: String = "user://saves/quicksave.save"
## Nodes rebuilt from level geometry; they implement `bake()`, called after a load removed geometry.
const REBAKE_GROUP: StringName = &"rebake_after_load"
## Nodes told when a quickload finished; they implement `on_quickloaded()`.
const LOADED_GROUP: StringName = &"quickload_listener"
## Physics frames the restored level is held paused before play resumes.
const SETTLE_FRAMES: int = 3
## Save key: the last stimulus id of the session that saved (StimulusSystem.last_id()). A load
## reserves the ids up to it, so ids kept in saved state (a fire's ignition, mission tallies) never
## name a stimulus of the new session.
const STIMULUS_IDS: String = "stimulus_ids"

## The slot file; tests point it elsewhere so they never touch the player's quicksave.
static var path: String = DEFAULT_PATH

static var _loading: bool = false


static func is_loading() -> bool:
	return _loading


## Writes the current level's snapshot to the slot and logs `game.saved`.
static func save_game(tree: SceneTree) -> SaveFile.Status:
	if _loading:
		return SaveFile.Status.BUSY
	var level := tree.current_scene
	if level == null or level.scene_file_path.is_empty():
		return SaveFile.Status.NO_LEVEL
	var snapshot := LevelSnapshot.capture(level)
	snapshot[STIMULUS_IDS] = StimulusSystem.last_id()
	var status := SaveFile.write(path, level.scene_file_path, snapshot)
	if status == SaveFile.Status.OK:
		EventLog.record(SAVED_KIND, "", "", _summary(level.scene_file_path, snapshot))
	return status


## Reads and checks the slot without loading it.
static func check() -> SaveFile.Status:
	var result := SaveFile.read(path)
	if result.status != SaveFile.Status.OK:
		return result.status
	if not LevelSnapshot.is_valid(result.data):
		return SaveFile.Status.CORRUPT
	if not ResourceLoader.exists(str(result.data["level"]), "PackedScene"):
		return SaveFile.Status.NO_LEVEL
	return SaveFile.Status.OK


## Coroutine: loads the slot (see the class description). Returns at once, changing nothing, when
## the file is missing, unreadable, of another version or a load is already running; otherwise
## after the restored level is running again. Callers that are part of the level must not await
## it (they are freed on the way): they start it and get `on_quickloaded()` afterwards.
static func load_game(tree: SceneTree) -> SaveFile.Status:
	if _loading:
		return SaveFile.Status.BUSY
	var result := SaveFile.read(path)
	if result.status != SaveFile.Status.OK:
		return result.status
	var data := result.data
	if not LevelSnapshot.is_valid(data):
		return SaveFile.Status.CORRUPT
	var level_path := str(data["level"])
	Engine.time_scale = 1.0
	if LevelReset.load_level(tree, level_path) != OK:
		return SaveFile.Status.NO_LEVEL
	_loading = true
	await tree.scene_changed
	var level := tree.current_scene
	if level == null or level.scene_file_path != level_path:
		_loading = false
		push_warning("QuickSave: the level changed during the load; save not applied")
		return SaveFile.Status.NO_LEVEL
	tree.paused = true
	StimulusSystem.reserve_ids(int(data.get(STIMULUS_IDS, 0)))
	var report := LevelSnapshot.apply(level, data)
	for i in SETTLE_FRAMES:
		await tree.physics_frame
	if report.geometry_removed:
		tree.call_group(REBAKE_GROUP, &"bake")
	StimulusSystem.clear()
	tree.paused = false
	_loading = false
	var summary := _summary(level_path, data)
	summary["skipped"] = report.skipped.size()
	EventLog.record(LOADED_KIND, "", "", summary)
	tree.call_group(LOADED_GROUP, &"on_quickloaded")
	return SaveFile.Status.OK


static func _summary(level_path: String, snapshot: Dictionary) -> Dictionary:
	return {
		"level": level_path,
		"saveables": (snapshot.get("states", {}) as Dictionary).size(),
		"removed": (snapshot.get("removed", []) as Array).size(),
		"spawned": (snapshot.get("spawned", {}) as Dictionary).size(),
	}
