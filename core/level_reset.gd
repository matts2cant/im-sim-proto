class_name LevelReset
extends RefCounted
## Reloads the current level from its scene file: drops queued stimuli first so nothing from the
## old level reaches the new one, and logs `level.reset` (or `event` when given). Used by the death
## overlay and the debug Spawn tab (`debug.reset_level`). M6 quickload restores a save instead.


## Returns the reload error; ERR_UNAVAILABLE, doing nothing, without a current scene file.
static func reload_level(tree: SceneTree, event: StringName = &"level.reset") -> Error:
	var scene := tree.current_scene
	if scene == null or scene.scene_file_path.is_empty():
		return ERR_UNAVAILABLE
	EventLog.record(event, "", "", {"scene": scene.scene_file_path})
	StimulusSystem.clear()
	return tree.reload_current_scene()
