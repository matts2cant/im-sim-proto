class_name ObjectCatalog
extends Resource
## Object scenes the debug panel's Spawn tab offers (`objects/object_catalog.tres`).

@export var scenes: Array[PackedScene] = []


## Button label for a scene: its file name in words ("small crate").
static func label_of(scene: PackedScene) -> String:
	return scene.resource_path.get_file().get_basename().replace("_", " ")
