class_name Sticky
extends Node
## Component of a RigidBody3D entity (ADR 0131): stick() fixes it on a surface and keeps it there
## while the surface moves (its pose: pose_on(), upright beside walls, on its base on floors and
## ceilings). The body is frozen (kinematic) and follows the node it was stuck to (the
## collision shape hit: a sliding door's panel, a hinged leaf, a crate) every physics tick at the same
## relative pose, and never collides with that node's body. If that node goes away (a crate broken)
## the body is let go and falls. `stuck` tells the entity's other components (a ProximityTrigger
## starts arming). EventLog `object.stuck {object, on}`. Saveable (what it is stuck to, by path from
## the entity's parent, and the relative pose).

signal stuck

## Centre of the entity this far out from a floor or ceiling it sticks to (m): its half height.
@export var surface_offset: float = 0.05
## Centre of the entity this far out from a wall it stands upright against (m): its radius, at
## least its collision shape's and enough for its model's side.
@export var side_offset: float = 0.05
@export var entity_path: NodePath = ^".."

var body: RigidBody3D
var is_stuck: bool = false
## The node followed, or null (stuck to nothing that moves, or let go).
var target: Node3D = null
## The entity's transform relative to `target`.
var offset := Transform3D.IDENTITY

var _following: bool = false


func _ready() -> void:
	add_to_group(LevelSnapshot.GROUP)
	body = Entities.of_component(self, entity_path) as RigidBody3D


static func of(node: Node) -> Sticky:
	if node == null:
		return null
	for child in node.get_children():
		if child is Sticky:
			return child as Sticky
	return null


## The pose the entity takes stuck at `point` on a surface with outward `normal`, seen along
## `view_forward` (ThrowRules.stick_transform() with its offsets).
func pose_on(point: Vector3, normal: Vector3, view_forward: Vector3) -> Transform3D:
	return ThrowRules.stick_transform(point, normal, view_forward, surface_offset, side_offset)


## Sticks the entity at `pose` (world) on `on` (the node hit, usually a CollisionShape3D; null: in
## place, following nothing).
func stick(on: Node3D, pose: Transform3D) -> void:
	is_stuck = true
	_freeze()
	body.global_transform = pose
	_follow(on)
	var on_name := String(on.name) if on != null else ""
	EventLog.record(EventKinds.OBJECT_STUCK, String(body.name), on_name, {"object": String(body.name), "on": on_name})
	stuck.emit()


func _physics_process(_delta: float) -> void:
	# A freed target compares equal to null: `_following` remembers there was one.
	if not is_stuck or not _following:
		return
	if not is_instance_valid(target) or not target.is_inside_tree() or target.is_queued_for_deletion():
		_let_go()
		return
	body.global_transform = target.global_transform * offset


func save_state() -> Dictionary:
	var path := ""
	if is_stuck and _following and is_instance_valid(target) and body.get_parent() != null:
		path = String(body.get_parent().get_path_to(target))
	return {"stuck": is_stuck, "target": path, "offset": offset}


func load_state(data: Dictionary) -> void:
	is_stuck = bool(data.get("stuck", is_stuck))
	if not is_stuck:
		return
	_freeze()
	offset = data.get("offset", offset)
	var path := str(data.get("target", ""))
	var on: Node3D = null
	if not path.is_empty() and body.get_parent() != null:
		on = body.get_parent().get_node_or_null(NodePath(path)) as Node3D
	target = on
	_following = on != null
	if on != null:
		_except(on)
		body.global_transform = on.global_transform * offset


func _freeze() -> void:
	body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	body.freeze = true
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO


func _follow(on: Node3D) -> void:
	target = on
	_following = on != null
	if on == null:
		return
	offset = on.global_transform.affine_inverse() * body.global_transform
	_except(on)


# Never collides with the body of what it is stuck on (it would push a crate it sits on).
func _except(on: Node) -> void:
	var node := on
	while node != null and not node is PhysicsBody3D:
		node = node.get_parent()
	if node != null and node != body:
		body.add_collision_exception_with(node as PhysicsBody3D)


func _let_go() -> void:
	target = null
	_following = false
	is_stuck = false
	body.freeze = false
