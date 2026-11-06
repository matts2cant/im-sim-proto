class_name LevelReset
extends RefCounted
## Reloads the current level from its scene file: drops queued stimuli first so nothing from the
## old level reaches the new one, and logs `level.reset` (or `event` when given). Used by the death
## overlay and the debug Spawn tab (`debug.reset_level`). Quickload (QuickSave, ADR 0063) loads the
## saved level through `load_level()` and then restores the save onto it.


## Returns the reload error; ERR_UNAVAILABLE, doing nothing, without a current scene file.
static func reload_level(tree: SceneTree, event: StringName = &"level.reset") -> Error:
	var scene := tree.current_scene
	if scene == null or scene.scene_file_path.is_empty():
		return ERR_UNAVAILABLE
	EventLog.record(event, "", "", {"scene": scene.scene_file_path})
	StimulusSystem.clear()
	return tree.reload_current_scene()


## Replaces the current scene with a fresh instance of `scene_path` (the same level or another one)
## at the end of the frame; SceneTree.scene_changed follows. Drops queued stimuli; logs `event`
## unless it is empty. ERR_FILE_NOT_FOUND, doing nothing, when the scene does not exist.
static func load_level(tree: SceneTree, scene_path: String, event: StringName = &"") -> Error:
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		return ERR_FILE_NOT_FOUND
	if event != &"":
		EventLog.record(event, "", "", {"scene": scene_path})
	StimulusSystem.clear()
	return tree.change_scene_to_file(scene_path)
