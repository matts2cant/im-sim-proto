class_name PickupRestock
extends Usable
## Component (M14c, ADR 0131): pressing it (E) puts every item pickup inside `scope_path` back as the
## level placed it: one taken (gone) is made again from its scene, with the same name, under the
## same parent, at the same place and count; one still there but moved or partly taken is put back
## and refilled. What the pickups are does not matter (any entity with an ItemPickup); the layout is
## read from the scope when it is ready, so nothing lists the pickups. EventLog:
## `range.restocked {by, count}` (the pickups made again, put back or refilled).

## A pickup further than this from where it was placed (m) has been moved.
const MOVED := 0.02

## Only pickups under this node count (the station's group).
@export var scope_path: NodePath = ^"../.."
@export var label: String = "pickups"

## One placed pickup: parent path (from the scope), name, scene, local transform, count and state.
var _records: Array[Dictionary] = []


func _ready() -> void:
	verb = "restock"
	_record.call_deferred()


func target_name() -> String:
	return label


func use(user: Node) -> bool:
	var count := restock()
	var by := String(user.name) if user != null else ""
	EventLog.record(EventKinds.RANGE_RESTOCKED, by, "", {"by": by, "count": count})
	used.emit(user)
	return true


## How many pickups the scope had when it was ready.
func recorded() -> int:
	return _records.size()


## Puts every recorded pickup back; returns how many were made again, put back or refilled.
func restock() -> int:
	var scope := get_node_or_null(scope_path)
	if scope == null:
		return 0
	var count := 0
	for record in _records:
		var parent := scope.get_node_or_null(record["parent"] as NodePath)
		if parent == null:
			continue
		var entity := parent.get_node_or_null(NodePath(String(record["name"]))) as Node3D
		if entity != null and entity.is_queued_for_deletion():
			# Taken this tick: free its name for the new one.
			parent.remove_child(entity)
			entity = null
		if entity == null:
			if _respawn(parent, record):
				count += 1
			continue
		var pickup := ItemPickup.of(entity)
		var placed: Transform3D = record["transform"]
		if pickup == null:
			continue
		# Settled on its surface (a few mm) is still in place.
		if pickup.count == int(record["count"]) and entity.position.distance_to(placed.origin) < MOVED:
			continue
		count += 1
		_put_back(entity, pickup, record)
	return count


func _record() -> void:
	var scope := get_node_or_null(scope_path)
	if scope == null:
		return
	for node in scope.find_children("*", "", true, false):
		var pickup := node as ItemPickup
		var entity := pickup.entity() if pickup != null else null
		if entity == null or entity.scene_file_path.is_empty():
			continue
		var record := {
			"parent": scope.get_path_to(entity.get_parent()),
			"name": String(entity.name),
			"scene": entity.scene_file_path,
			"transform": entity.transform,
			"count": pickup.count,
			"state": pickup.state.duplicate(true),
		}
		_records.append(record)


func _respawn(parent: Node, record: Dictionary) -> bool:
	var scene := load(String(record["scene"])) as PackedScene
	if scene == null:
		return false
	var entity := scene.instantiate() as Node3D
	var pickup := ItemPickup.of(entity)
	if entity == null or pickup == null:
		if entity != null:
			entity.free()
		return false
	entity.name = String(record["name"])
	entity.transform = record["transform"]
	pickup.count = int(record["count"])
	pickup.state = (record["state"] as Dictionary).duplicate(true)
	parent.add_child(entity)
	return true


func _put_back(entity: Node3D, pickup: ItemPickup, record: Dictionary) -> void:
	pickup.count = int(record["count"])
	pickup.state = (record["state"] as Dictionary).duplicate(true)
	pickup.refresh_model()
	entity.transform = record["transform"]
	var body := entity as RigidBody3D
	if body != null:
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		PhysicsServer3D.body_set_state(body.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, entity.global_transform)
