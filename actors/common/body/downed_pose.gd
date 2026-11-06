class_name DownedPose
extends Node
## Component of a character body (its parent): lays it down while it cannot act (ActorState:
## `state.dead`, `state.unconscious`, whatever added the tag) and stands it up again when it can.
## The figure (`pose_path`) and its hitboxes (`hitboxes_path`) tip backwards over `tip_time`; the
## collision shape (`collision_path`) is laid flat at once, its side resting on the floor, so the
## body is a low obstacle (about 0.7 m for a 0.35 m capsule) instead of a standing one. Polls the
## tags every physics tick, so a loaded save poses itself. Origin of the parent at the feet,
## facing -Z (it falls onto +Z).

## Tipped +90 degrees about X at the feet, lifted so the figure's torso rests on the floor.
const LYING_FIGURE := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.15, 0))

@export var pose_path: NodePath = ^"../Pose"
@export var hitboxes_path: NodePath = ^"../Hitboxes"
@export var collision_path: NodePath = ^"../Collision"
@export var tip_time: float = 0.5

var entity: Node3D
## True while lying down.
var is_down: bool = false

var _pose: Node3D
var _hitboxes: Node3D
var _collision: CollisionShape3D
var _standing_collision: Transform3D
var _lying_collision: Transform3D
var _fall: float = 0.0
var _tween: Tween


func _ready() -> void:
	entity = get_parent() as Node3D
	_pose = get_node_or_null(pose_path) as Node3D
	_hitboxes = get_node_or_null(hitboxes_path) as Node3D
	_collision = get_node_or_null(collision_path) as CollisionShape3D
	if _collision != null:
		_standing_collision = _collision.transform
		var lift := _shape_radius(_collision.shape) + 0.01
		_lying_collision = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, lift, 0)) * _standing_collision
		_lying_collision.origin.y = lift


func _physics_process(_delta: float) -> void:
	var down := entity != null and not ActorState.can_act(entity)
	if down == is_down:
		return
	is_down = down
	if _collision != null:
		_collision.transform = _lying_collision if down else _standing_collision
	if _tween != null:
		_tween.kill()
		_tween = null
	if not down or not is_inside_tree():
		_set_fall(1.0 if down else 0.0)
		return
	_tween = create_tween()
	_tween.tween_method(_set_fall, _fall, 1.0, tip_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


# 0 = standing, 1 = lying: the figure and its hitboxes tip together.
func _set_fall(amount: float) -> void:
	_fall = amount
	var lying := Transform3D.IDENTITY.interpolate_with(LYING_FIGURE, amount)
	if _pose != null:
		_pose.transform = lying
	if _hitboxes != null:
		_hitboxes.transform = lying


static func _shape_radius(shape: Shape3D) -> float:
	if shape is CapsuleShape3D:
		return (shape as CapsuleShape3D).radius
	if shape is CylinderShape3D:
		return (shape as CylinderShape3D).radius
	if shape is SphereShape3D:
		return (shape as SphereShape3D).radius
	return 0.35
