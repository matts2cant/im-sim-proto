class_name Player
extends CharacterBody3D
## First-person player: walk, sprint, crouch, jump, mantle, mouse look. A thin adapter over the
## pure rules (PlayerMotion, MantleRules, PlayerNoiseRules); tuning comes from `config`.
## Origin is at the feet. Saveable (group `saveable`).

signal mantled(height: float)

const DEBUG_TAB: PackedScene = preload("res://ui/debug_panel/tabs/player_tab.tscn")

@export var config: PlayerConfig
## When false the player ignores input (cutscenes, tests that drive it directly).
@export var input_enabled: bool = true

var mode: PlayerMotion.Mode = PlayerMotion.Mode.IDLE
var crouched: bool = false
var pitch: float = 0.0
## Surface of the floor last stood on.
var surface: StringName = &""

var _probe: PlayerProbe
var _footsteps := FootstepTracker.new()
var _jump_requested: bool = false
var _jump_was_held: bool = false
var _was_grounded: bool = true
var _air_speed_cap: float = 0.0
## Height of the ground last stood on; caps how high a ledge can be mantled after a jump.
var _ground_y: float = 0.0
var _mantle: MantleRules.Plan = null
var _mantle_time: float = 0.0
var _spawn_transform: Transform3D
var _debug_tab: Node

@onready var noise: PlayerNoise = $Noise
@onready var _collision: CollisionShape3D = $Collision
@onready var _head: Node3D = $Head
@onready var _floor_ray: RayCast3D = $FloorRay


func _ready() -> void:
	add_to_group(&"saveable")
	_collision.shape = _collision.shape.duplicate()
	(_collision.shape as CapsuleShape3D).radius = config.capsule_radius
	floor_max_angle = deg_to_rad(config.max_slope_deg)
	_probe = PlayerProbe.new(self, config)
	noise.config = config
	noise.source_name = name
	surface = config.surfaces.default_surface
	_spawn_transform = global_transform
	_ground_y = global_position.y
	_air_speed_cap = config.walk_speed
	_apply_crouched(false)
	_head.position.y = PlayerMotion.eye_height(false, config)
	_register_debug_tab()
	if input_enabled and not DebugPanel.is_open():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# The first entry happens before the DebugPanel autoload is ready, so _ready registers;
# this only re-registers after the player was taken out of the tree and put back.
func _enter_tree() -> void:
	if is_node_ready():
		_register_debug_tab()


func _exit_tree() -> void:
	if is_instance_valid(_debug_tab):
		_debug_tab.queue_free()
	_debug_tab = null
	if input_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if not _input_allowed():
		return
	if event.is_action_pressed(&"jump"):
		_jump_requested = true
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look((event as InputEventMouseMotion).screen_relative)
	elif event.is_action_pressed(&"ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.is_pressed():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if global_position.y < config.fall_respawn_height:
		_respawn()
	var jump_held := _input_allowed() and Input.is_action_pressed(&"jump")
	if jump_held and not _jump_was_held:
		_jump_requested = true
	_jump_was_held = jump_held
	if _mantle != null:
		_jump_requested = false
		_step_mantle(delta)
	else:
		_step_movement(delta, jump_held)
	_head.position.y = PlayerMotion.step_eye(_head.position.y, PlayerMotion.eye_height(crouched, config), delta, config)


## Turns the view by a mouse delta in screen pixels.
func look(screen_delta: Vector2) -> void:
	rotation.y = wrapf(rotation.y - screen_delta.x * config.mouse_sensitivity, -PI, PI)
	var limit := deg_to_rad(config.max_pitch_deg)
	pitch = clampf(pitch - screen_delta.y * config.mouse_sensitivity, -limit, limit)
	_head.rotation.x = pitch


func is_mantling() -> bool:
	return _mantle != null


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func capsule_height() -> float:
	return (_collision.shape as CapsuleShape3D).height


func eye_height() -> float:
	return _head.position.y


func save_state() -> Dictionary:
	return {
		"position": global_position,
		"yaw": rotation.y,
		"pitch": pitch,
		"crouched": crouched,
		"velocity": velocity,
	}


func load_state(data: Dictionary) -> void:
	_mantle = null
	global_position = data.get("position", global_position)
	rotation.y = data.get("yaw", rotation.y)
	pitch = data.get("pitch", pitch)
	_head.rotation.x = pitch
	velocity = data.get("velocity", velocity)
	_apply_crouched(data.get("crouched", crouched))
	_head.position.y = PlayerMotion.eye_height(crouched, config)
	_ground_y = global_position.y
	_footsteps.reset()


func _step_movement(delta: float, jump_held: bool) -> void:
	var grounded := is_on_floor()
	_update_crouch()
	var wants_mantle := (_jump_requested and grounded) or (jump_held and not grounded)
	if wants_mantle and _try_start_mantle():
		_jump_requested = false
		return
	var jumping := _jump_requested and grounded
	_jump_requested = false

	var input := _move_input()
	var sprint_held := _input_allowed() and Input.is_action_pressed(&"sprint")
	mode = PlayerMotion.select_mode(grounded, crouched, sprint_held, input, config)
	if grounded:
		_air_speed_cap = PlayerMotion.max_speed(mode, config)
	var wish := global_basis * Vector3(input.x, 0.0, input.y)
	var horizontal := PlayerMotion.horizontal_velocity(velocity, wish, _air_speed_cap, grounded, delta, config)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	var gravity := get_gravity() * config.gravity_scale
	if jumping:
		velocity.y = PlayerMotion.jump_speed(config.jump_apex_height, gravity.length())
	elif not grounded:
		velocity += gravity * delta

	var fall_speed := maxf(-velocity.y, 0.0)
	var before := global_position
	move_and_slide()
	_after_move(before, fall_speed)


func _after_move(before: Vector3, fall_speed: float) -> void:
	var grounded := is_on_floor()
	if grounded:
		_ground_y = global_position.y
		_update_surface()
		if not _was_grounded:
			_footsteps.reset()
			noise.landed(fall_speed, surface)
		else:
			var travelled := Vector2(global_position.x - before.x, global_position.z - before.z).length()
			if _footsteps.advance(travelled, PlayerNoiseRules.stride(mode, config)):
				noise.footstep(mode, surface)
	_was_grounded = grounded


func _update_surface() -> void:
	_floor_ray.force_raycast_update()
	if _floor_ray.is_colliding():
		surface = config.surfaces.surface_of(_floor_ray.get_collider())


# Crouch is held. Standing up waits until there is headroom.
func _update_crouch() -> void:
	var wants_crouch := _input_allowed() and Input.is_action_pressed(&"crouch")
	if wants_crouch and not crouched:
		_apply_crouched(true)
	elif not wants_crouch and crouched and _probe.is_clear(global_position, config.standing_height):
		_apply_crouched(false)


func _apply_crouched(value: bool) -> void:
	crouched = value
	var height := config.crouched_height if value else config.standing_height
	(_collision.shape as CapsuleShape3D).height = height
	_collision.position.y = height * 0.5


func _try_start_mantle() -> bool:
	var probe := _probe.find_ledge(global_position, -global_basis.z, _ground_y)
	var plan := MantleRules.evaluate(probe, global_position, config)
	if plan == null:
		return false
	_mantle = plan
	_mantle_time = 0.0
	mode = PlayerMotion.Mode.MANTLE
	velocity = Vector3.ZERO
	if plan.end_crouched:
		_apply_crouched(true)
	return true


# Scripted move: no physics while mantling, the path was checked by PlayerProbe.
func _step_mantle(delta: float) -> void:
	_mantle_time += delta
	var t := _mantle_time / _mantle.duration if _mantle.duration > 0.0 else 1.0
	global_position = MantleRules.position_at(_mantle, t)
	if t < 1.0:
		return
	var height := _mantle.height
	_mantle = null
	velocity = Vector3.ZERO
	_was_grounded = true
	_ground_y = global_position.y
	_footsteps.reset()
	EventLog.record(&"player.mantled", name, "", {"height": height})
	mantled.emit(height)


func _register_debug_tab() -> void:
	_debug_tab = DEBUG_TAB.instantiate()
	_debug_tab.set(&"player", self)
	DebugPanel.register_tab("Player", _debug_tab as Control)


func _respawn() -> void:
	_mantle = null
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	_ground_y = global_position.y


func _move_input() -> Vector2:
	if not _input_allowed():
		return Vector2.ZERO
	return Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")


func _input_allowed() -> bool:
	return input_enabled and not DebugPanel.is_open()
