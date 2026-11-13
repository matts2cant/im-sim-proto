class_name LevelExit
extends Area3D
## Kit part (ADR 0087): an invisible trigger box (`size`, standing on the node's origin) that loads
## `scene_path` when an entity with `required_tag` (the player) that can act walks into it: the
## hub's mission doorway. Nothing comes along: the new level starts from its own scene
## (LevelReset.load_level). Once per instance. A missing scene changes nothing.
## EventLog: `level.exit {scene, by}`, `level.exit_refused {scene, reason}`.

@export_file("*.tscn") var scene_path: String = ""
@export var required_tag: StringName = ActorState.PLAYER
## The box, metres (x, y, z), standing on the node's origin.
@export var size: Vector3 = Vector3(1.0, 3.0, 2.0)

var used: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = PhysicsLayers.PLAYER | PhysicsLayers.ACTORS
	monitorable = false
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.name = "Box"
	collision.shape = shape
	collision.position = Vector3(0.0, size.y * 0.5, 0.0)
	add_child(collision)
	body_entered.connect(_on_body_entered)


## Loads the target level now (the trigger's effect); false when used or the scene is missing.
func leave(by: Node = null) -> bool:
	if used or QuickSave.is_loading():
		return false
	var who := String(by.name) if is_instance_valid(by) else ""
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		EventLog.record(EventKinds.LEVEL_EXIT_REFUSED, who, "", {"scene": scene_path, "reason": "missing"})
		return false
	used = true
	EventLog.record(EventKinds.LEVEL_EXIT, who, "", {"scene": scene_path, "by": who})
	return LevelReset.load_level(get_tree(), scene_path) == OK


func _on_body_entered(body: Node3D) -> void:
	if ActorState.has(body, required_tag) and ActorState.can_act(body):
		leave(body)
