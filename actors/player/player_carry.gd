class_name PlayerCarry
extends Node
## Component of the Player: picks up, carries, puts down, drops and throws physics objects that have
## a Carryable. The held body stays a physics body: each tick its velocity is set towards the hold
## point (it still collides with the world), gravity is off and it ignores the player's capsule.
## The mass limit is the player's `carry_mass_limit` attribute (Combat Strength raises it in M6).
## Not saved: loading a save drops what is held.

signal picked_up(body: RigidBody3D)
signal released(body: RigidBody3D, how: StringName)

const LIMIT_ATTRIBUTE: StringName = &"carry_mass_limit"

var player: Player
var config: PlayerConfig
## The body being carried, or null.
var held: RigidBody3D = null

var _gravity_scale: float = 1.0


func is_carrying() -> bool:
	return is_instance_valid(held)


func held_mass() -> float:
	return held.mass if is_carrying() else 0.0


func mass_limit() -> float:
	var attributes := player.get_node_or_null(^"Attributes") as Attributes
	return attributes.value(LIMIT_ATTRIBUTE) if attributes != null else 0.0


func speed_factor() -> float:
	return CarryRules.speed_factor(held_mass(), config)


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
		put_down()
	held = body
	_gravity_scale = body.gravity_scale
	body.gravity_scale = 0.0
	body.sleeping = false
	player.add_collision_exception_with(body)
	body.add_collision_exception_with(player)
	var carryable := Carryable.of(body)
	if carryable != null:
		carryable.set_carrier(player)
	EventLog.record(&"player.picked_up", String(player.name), String(body.name), {"object": String(body.name)})
	picked_up.emit(body)


## Lets go gently: no velocity.
func put_down() -> void:
	if is_carrying():
		var body := held
		_release(&"put_down")
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO


## Lets go, keeping the current velocity.
func drop(reason: StringName = &"drop") -> void:
	if is_carrying():
		_release(reason)


## Throws along the view at CarryRules.throw_speed().
func throw() -> void:
	if not is_carrying():
		return
	var body := held
	var speed := CarryRules.throw_speed(body.mass, config)
	var direction := -player.eye_transform().basis.z
	_release(&"throw")
	body.linear_velocity = direction * speed
	body.angular_velocity = Vector3.ZERO
	var data := {"object": String(body.name), "speed": speed}
	EventLog.record(&"player.threw", String(player.name), String(body.name), data)


## Called by the Player every physics tick.
func physics_step() -> void:
	if held == null:
		return
	if not is_instance_valid(held) or held.is_queued_for_deletion():
		held = null
		return
	var target := CarryRules.hold_point(player.eye_transform(), config)
	if held.global_position.distance_to(target) > config.hold_break_distance:
		drop(&"stuck")
		return
	held.linear_velocity = CarryRules.follow_velocity(held.global_position, target, config)
	held.angular_velocity = Vector3.ZERO


func _release(how: StringName) -> void:
	var body := held
	held = null
	body.gravity_scale = _gravity_scale
	player.remove_collision_exception_with(body)
	body.remove_collision_exception_with(player)
	var carryable := Carryable.of(body)
	if carryable != null:
		carryable.set_carrier(null)
	if how != &"throw":
		var data := {"object": String(body.name), "how": how}
		EventLog.record(&"player.dropped", String(player.name), String(body.name), data)
	released.emit(body, how)
