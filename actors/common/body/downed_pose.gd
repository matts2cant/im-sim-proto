class_name DownedPose
extends Node
## Component of a character body (its parent): lays it down while it cannot act (ActorState:
## `state.dead`, `state.unconscious`, whatever added the tag) and stands it up again when it can.
## The figure (`pose_path`) and its hitboxes (`hitboxes_path`) tip backwards over `tip_time`; the
## collision shape (`collision_path`) is laid flat at once, its side resting on the floor, so the
## body is about 0.7 m high (a 0.35 m capsule) instead of standing. While down the body also leaves
## the character layers (PhysicsLayers.CHARACTER_LAYERS) for PhysicsLayers.DOWNED and stops scanning
## them, so characters walk through it (ADR 0082); it still lands on the world and props, its
## hitboxes still take shots and the interactor's ray, and stimuli reach its receiver as before.
## Standing up restores the layers it had. While a carrier holds it (Carryable), the carrier owns
## the layers; they are put right on the first tick after release. Polls the tags every physics
## tick, so a loaded save poses itself. Origin of the parent at the feet, facing -Z (it falls onto
## +Z).

## Tipped +90 degrees about X at the feet, lifted so the figure's torso rests on the floor.
const LYING_FIGURE := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.15, 0))

@export var pose_path: NodePath = ^"../Pose"
@export var hitboxes_path: NodePath = ^"../Hitboxes"
@export var collision_path: NodePath = ^"../Collision"
@export var tip_time: float = 0.5

var entity: Node3D
## True while lying down.
var is_down: bool = false
## The body's collision layer and mask while standing (taken when it goes down).
var standing_layer: int = 0
var standing_mask: int = 0

var _pose: Node3D
var _hitboxes: Node3D
var _collision: CollisionShape3D
var _standing_collision: Transform3D
var _lying_collision: Transform3D
var _fall: float = 0.0
var _tween: Tween
var _body: CollisionObject3D


func _ready() -> void:
	entity = get_parent() as Node3D
	_body = entity as CollisionObject3D
	if _body != null:
		standing_layer = _body.collision_layer
		standing_mask = _body.collision_mask
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
	if down != is_down:
		_turn(down)
	_apply_layers()


## Collision layer of a downed body that stood on `layer`: off the character layers, on DOWNED.
static func downed_layer(layer: int) -> int:
	return (layer & ~PhysicsLayers.CHARACTER_LAYERS) | PhysicsLayers.DOWNED


## Collision mask of a downed body that stood with `mask`: it no longer meets characters (nor other
## bodies), so nobody pushes it around while walking through it.
static func downed_mask(mask: int) -> int:
	return mask & ~(PhysicsLayers.CHARACTER_LAYERS | PhysicsLayers.DOWNED)


func _turn(down: bool) -> void:
	if down and _body != null and not _is_held():
		standing_layer = _body.collision_layer
		standing_mask = _body.collision_mask
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


func _apply_layers() -> void:
	if _body == null:
		return
	var layer := downed_layer(standing_layer) if is_down else standing_layer
	var mask := downed_mask(standing_mask) if is_down else standing_mask
	if (_body.collision_layer == layer and _body.collision_mask == mask) or _is_held():
		return
	_body.collision_layer = layer
	_body.collision_mask = mask


func _is_held() -> bool:
	var carryable := Carryable.of(entity)
	return carryable != null and carryable.is_carried()


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
