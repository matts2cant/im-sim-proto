class_name LevelReset
extends RefCounted
## Reloads the current level from its scene file: drops queued stimuli first so nothing from the
## old level reaches the new one, and logs `level.reset`. Used by the death overlay and the debug
## Spawn tab. M6 quickload restores a save instead.


static func reload_level(tree: SceneTree) -> void:
	var scene := tree.current_scene
	var path := scene.scene_file_path if scene != null else ""
	EventLog.record(&"level.reset", "", "", {"scene": path})
	StimulusSystem.clear()
	tree.reload_current_scene()
