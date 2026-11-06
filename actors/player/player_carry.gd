class_name PlayerCarry
extends Node
## Component of the Player: picks up, carries, puts down, drops and throws physics objects that have
## a Carryable (ADR 0053). The held body is a ghost: collision layer and mask 0 (nothing hits it, it
## hits nothing), frozen kinematic and placed every tick at the hold point in front of the eyes
## (CarryRules.hold_point), upright and turned to the nearest 90 degrees of the view; its meshes are
## see-through. It still burns, hurts its carrier when burning and receives stimuli (they reach
## receivers by distance, not by collision). Every release looks for a free spot first: the shape is
## cast from the chest towards the hold point (pushed clear of the capsule) and placed short of the
## first contact; put down, drop and throw are refused (`player.release_refused`, HUD "No room")
## when that spot overlaps anything.
## The mass limit is the player's `carry_mass_limit` attribute (Combat Strength raises it in M6).
## Not saved: loading a save drops what is held where it is.

signal picked_up(body: RigidBody3D)
signal released(body: RigidBody3D, how: StringName)
## A put down / drop / throw found no free spot; the object stays held.
signal release_refused(body: RigidBody3D, how: StringName)

const LIMIT_ATTRIBUTE: StringName = &"carry_mass_limit"
## What a released object must be clear of besides the player (world, objects, actors).
const RELEASE_MASK: int = PhysicsLayers.WORLD | PhysicsLayers.ACTORS | PhysicsLayers.OBJECTS

var player: Player
var config: PlayerConfig
## The body being carried, or null.
var held: RigidBody3D = null

var _layer: int = 0
var _mask: int = 0
var _freeze: bool = false
var _freeze_mode: RigidBody3D.FreezeMode = RigidBody3D.FREEZE_MODE_STATIC
## Transparency of each faded mesh before pick-up, by instance id (meshes may be freed meanwhile).
var _faded: Dictionary[int, float] = {}
var _half_extent: float = 0.0
var _yaw_offset: float = 0.0
var _start: Transform3D
var _elapsed: float = 0.0
var _velocity: Vector3 = Vector3.ZERO
var _room: bool = true


func is_carrying() -> bool:
	return is_instance_valid(held)


func held_mass() -> float:
	return held.mass if is_carrying() else 0.0


func mass_limit() -> float:
	var attributes := player.get_node_or_null(^"Attributes") as Attributes
	return attributes.value(LIMIT_ATTRIBUTE) if attributes != null else 0.0


func speed_factor() -> float:
	return CarryRules.speed_factor(held_mass(), config)


## False when, at the last tick, the held object had no free spot to be released into.
func has_room() -> bool:
	return _room


## `use`: put down what is held, else try to pick up what is looked at.
func use() -> void:
	if is_carrying():
		put_down()
	else:
		try_pick_up()


## Picks up the Carryable body under the crosshair within reach; false when there is none or it is
## too heavy (logged as `player.pickup_refused`).
func try_pick_up() -> bool:
	var hit := player.look_hit(config.carry_reach)
	if hit.is_empty():
		return false
	var body := hit["collider"] as RigidBody3D
	if body == null or not can_offer(body):
		return false
	return try_pick_up_body(body)


## True when `body` has an enabled Carryable nobody holds (whatever its mass).
static func can_offer(body: RigidBody3D) -> bool:
	var carryable := Carryable.of(body)
	return carryable != null and carryable.enabled and not carryable.is_carried()


## Picks up `body` if it is within the mass limit; otherwise logs `player.pickup_refused`.
func try_pick_up_body(body: RigidBody3D) -> bool:
	var limit := mass_limit()
	if not CarryRules.can_carry(body.mass, limit):
		var data := {"object": String(body.name), "mass": body.mass, "limit": limit}
		EventLog.record(&"player.pickup_refused", String(player.name), String(body.name), data)
		return false
	pick_up(body)
	return true


func pick_up(body: RigidBody3D) -> void:
	if is_carrying():
		_let_go(&"put_down", _forced_spot(&"put_down"), Vector3.ZERO)
	held = body
	_layer = body.collision_layer
	_mask = body.collision_mask
	_freeze = body.freeze
	_freeze_mode = body.freeze_mode
	_half_extent = CarryRules.half_extent(shapes_aabb(body))
	var view_yaw := CarryRules.view_yaw(player.eye_transform().basis)
	_yaw_offset = CarryRules.snapped_yaw_offset(CarryRules.upright_yaw(body.global_basis), view_yaw)
	_start = body.global_transform.orthonormalized()
	_elapsed = 0.0
	_velocity = Vector3.ZERO
	_room = true
	body.collision_layer = 0
	body.collision_mask = 0
	body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	body.freeze = true
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	_fade(body)
	var carryable := Carryable.of(body)
	if carryable != null:
		carryable.set_carrier(player)
	EventLog.record(&"player.picked_up", String(player.name), String(body.name), {"object": String(body.name)})
	picked_up.emit(body)


## Lets go gently (no velocity) at a free spot; false (still held) when there is none.
func put_down() -> bool:
	return _try_release(&"put_down", Vector3.ZERO)


## Q: lets go at a free spot with the carry velocity (false when refused). Other reasons (`load`,
## `died`, `respawn`) always let go: `load` where the object is, the others at a free spot, else
## at the chest.
func drop(reason: StringName = &"drop") -> bool:
	if not is_carrying():
		return false
	if reason == &"drop":
		return _try_release(&"drop", _velocity)
	_let_go(reason, _forced_spot(reason), Vector3.ZERO)
	return true


## Throws along the view at CarryRules.throw_speed() from a free spot; false when refused.
func throw() -> bool:
	if not is_carrying():
		return false
	var body := held
	var speed := CarryRules.throw_speed(body.mass, config)
	var direction := -player.eye_transform().basis.z
	if not _try_release(&"throw", direction * speed):
		return false
	var data := {"object": String(body.name), "speed": speed}
	EventLog.record(&"player.threw", String(player.name), String(body.name), data)
	return true


## Called by the Player every physics tick: places the held body and checks there is room to let go.
func physics_step() -> void:
	if held == null:
		return
	if not is_instance_valid(held) or held.is_queued_for_deletion():
		held = null
		_faded.clear()
		_room = true
		return
	var delta := get_physics_process_delta_time()
	var before := held.global_position
	_elapsed += delta
	held.global_transform = _hold_transform()
	_velocity = (held.global_position - before) / delta if delta > 0.0 else Vector3.ZERO
	_room = not release_spot().is_empty()


## Where the held object would be released now: {"transform": Transform3D}, or {} when there is
## no free spot. The shape travels from the chest to the release target in two legs (out then
## down, or up then out: CarryRules.release_corner), each cast against world, objects and actors
## and stopped `release_margin` short of the first contact; the result must overlap nothing, the
## player included.
func release_spot() -> Dictionary:
	var shapes := _shapes(held)
	var basis := _target_transform().basis
	var start := _chest()
	var target := CarryRules.release_target(player.eye_transform(), _half_extent, config)
	var corner := CarryRules.release_corner(start, target)
	var space := player.get_world_3d().direct_space_state
	var ignore: Array[RID] = [held.get_rid(), player.get_rid()]
	for shape in shapes:
		# A cast that starts inside something ignores it (Jolt): check the start first.
		if not space.intersect_shape(_query(shape, Transform3D(basis, start), RELEASE_MASK, ignore), 1).is_empty():
			return {}
	var at := start
	for leg: Vector3 in [corner - start, target - corner]:
		at += leg * _travel(shapes, Transform3D(basis, at), leg, ignore)
	var spot := Transform3D(basis, at)
	var only_held: Array[RID] = [held.get_rid()]
	for shape in shapes:
		if not space.intersect_shape(_query(shape, spot, RELEASE_MASK | PhysicsLayers.PLAYER, only_held), 1).is_empty():
			return {}
	return {"transform": spot}


## Local-space AABB of a body's collision shapes (a 0.5 m cube when it has none).
static func shapes_aabb(body: RigidBody3D) -> AABB:
	var shapes := _shapes(body)
	if shapes.is_empty():
		return AABB(Vector3.ONE * -0.25, Vector3.ONE * 0.5)
	var box := AABB()
	for i in shapes.size():
		var local := shapes[i].transform * shapes[i].shape.get_debug_mesh().get_aabb()
		box = local if i == 0 else box.merge(local)
	return box


func _try_release(how: StringName, velocity: Vector3) -> bool:
	if not is_carrying():
		return false
	var spot := release_spot()
	if spot.is_empty():
		_room = false
		var body := held
		var data := {"object": String(body.name), "how": how, "reason": &"no_room"}
		EventLog.record(&"player.release_refused", String(player.name), String(body.name), data)
		release_refused.emit(body, how)
		return false
	_let_go(how, spot["transform"], velocity)
	return true


func _forced_spot(how: StringName) -> Transform3D:
	if how == &"load":
		return held.global_transform
	var spot := release_spot()
	if not spot.is_empty():
		return spot["transform"]
	return Transform3D(_target_transform().basis, _chest())


func _let_go(how: StringName, spot: Transform3D, velocity: Vector3) -> void:
	var body := held
	held = null
	_room = true
	_unfade()
	body.freeze = _freeze
	body.freeze_mode = _freeze_mode
	body.global_transform = spot
	body.collision_layer = _layer
	body.collision_mask = _mask
	body.linear_velocity = velocity
	body.angular_velocity = Vector3.ZERO
	var carryable := Carryable.of(body)
	if carryable != null:
		carryable.set_carrier(null)
	if how != &"throw":
		var data := {"object": String(body.name), "how": how}
		EventLog.record(&"player.dropped", String(player.name), String(body.name), data)
	released.emit(body, how)


# Hold point, upright at the view's yaw plus the snapped offset.
func _target_transform() -> Transform3D:
	var eye := player.eye_transform()
	var basis := CarryRules.held_basis(CarryRules.view_yaw(eye.basis), _yaw_offset)
	return Transform3D(basis, CarryRules.hold_point(eye, _half_extent, config))


# The target, blended from where the object was picked up over `hold_turn_time`.
func _hold_transform() -> Transform3D:
	var target := _target_transform()
	var weight := CarryRules.pickup_blend(_elapsed, config.hold_turn_time)
	if weight >= 1.0:
		return target
	var rotation := _start.basis.get_rotation_quaternion().slerp(target.basis.get_rotation_quaternion(), weight)
	return Transform3D(Basis(rotation), _start.origin.lerp(target.origin, weight))


# Release cast start: on the player's axis, `release_start_drop` below the eyes.
func _chest() -> Vector3:
	var feet := player.global_position
	return Vector3(feet.x, player.eye_transform().origin.y - config.release_start_drop, feet.z)


func _fade(body: RigidBody3D) -> void:
	_faded.clear()
	for node in body.find_children("*", "GeometryInstance3D", true, false):
		if _in_fire_fx(node, body):
			continue
		var mesh := node as GeometryInstance3D
		_faded[mesh.get_instance_id()] = mesh.transparency
		mesh.transparency = maxf(mesh.transparency, config.held_transparency)


func _unfade() -> void:
	for id in _faded:
		var mesh := instance_from_id(id) as GeometryInstance3D
		if mesh != null:
			mesh.transparency = _faded[id]
	_faded.clear()


static func _in_fire_fx(node: Node, body: Node) -> bool:
	var current := node
	while current != null and current != body:
		if current is FireFx:
			return true
		current = current.get_parent()
	return false


# Fraction of `motion` the shapes can travel from `from` (backed off by the release margin).
func _travel(shapes: Array[CollisionShape3D], from: Transform3D, motion: Vector3, ignore: Array[RID]) -> float:
	if motion.length() < 0.0001:
		return 0.0
	var space := player.get_world_3d().direct_space_state
	var safe := 1.0
	for shape in shapes:
		var query := _query(shape, from, RELEASE_MASK, ignore)
		query.motion = motion
		safe = minf(safe, space.cast_motion(query)[0])
	return CarryRules.release_fraction(safe, motion.length(), config.release_margin)


static func _shapes(body: RigidBody3D) -> Array[CollisionShape3D]:
	var shapes: Array[CollisionShape3D] = []
	for child in body.get_children():
		var shape := child as CollisionShape3D
		if shape != null and shape.shape != null and not shape.disabled:
			shapes.append(shape)
	return shapes


static func _query(
	shape: CollisionShape3D, at: Transform3D, mask: int, ignore: Array[RID]
) -> PhysicsShapeQueryParameters3D:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape.shape
	query.transform = at * shape.transform
	query.collision_mask = mask
	query.exclude = ignore
	return query
