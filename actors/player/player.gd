class_name Player
extends CharacterBody3D
## First-person player: walk, sprint, crouch, jump, mantle, mouse look, carry and throw objects,
## use things, weapons (WeaponHolder) and body-part damage (BodyParts, Hitboxes).
## A thin adapter over the pure rules (PlayerMotion, MantleRules, PlayerNoiseRules, CarryRules);
## tuning comes from `config`. Origin is at the feet. Collision layer 2 (ADR 0045).
## Its StimulusReceiver's `body_damage` receptron feeds every `damage.*` stimulus to BodyParts.
## Injuries: `move_speed_mult` scales speed, both legs disabled force a crawl; hard landings hurt
## the legs. Dead: input is off except `use`, which asks for a level reset. Saveable.

signal mantled(height: float)
## The player pressed `use` while dead (the HUD's death overlay says so).
signal reset_requested

const DEBUG_TAB: PackedScene = preload("res://ui/debug_panel/tabs/player_tab.tscn")
const GROUP: StringName = &"player"
## Actions handled on their press edge in _physics_process (carry, use, weapons).
const PRESS_ACTIONS: Array[StringName] = [&"use", &"drop_throw", &"fire", &"reload", &"belt_1", &"belt_2"]
const MOVE_SPEED: StringName = &"move_speed_mult"
## Horizontal speed above which the aim counts as moving.
const AIM_MOVING_SPEED: float = 0.5
## Airborne this long (s) before the aim counts as jumping/falling (a teleport or a step off a
## kerb does not bloom the cone).
const AIM_AIR_GRACE: float = 0.1

@export var config: PlayerConfig
## When false the player ignores input (cutscenes, tests that drive it directly).
@export var input_enabled: bool = true
## When false, `use` while dead only emits `reset_requested` (tests) instead of reloading the level.
@export var reload_on_reset: bool = true

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
var _air_time: float = 0.0
var _air_speed_cap: float = 0.0
## Height of the ground last stood on; caps how high a ledge can be mantled after a jump.
var _ground_y: float = 0.0
var _mantle: MantleRules.Plan = null
var _mantle_time: float = 0.0
var _spawn_transform: Transform3D
var _debug_tab: Node
var _actions_held: Dictionary[StringName, bool] = {}

@onready var noise: PlayerNoise = $Noise
@onready var carry: PlayerCarry = $Carry
@onready var body: BodyParts = $BodyParts
@onready var hitboxes: Hitboxes = $Hitboxes
@onready var weapons: WeaponHolder = $Head/Camera/WeaponHolder
@onready var attributes: Attributes = $Attributes
@onready var _collision: CollisionShape3D = $Collision
@onready var _head: Node3D = $Head
@onready var _floor_ray: RayCast3D = $FloorRay
@onready var _camera: Camera3D = $Head/Camera


func _ready() -> void:
	add_to_group(&"saveable")
	add_to_group(GROUP)
	carry.player = self
	carry.config = config
	weapons.setup(self, _camera)
	body.died.connect(_on_died)
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
	_handle_actions()
	carry.physics_step()
	weapons.physics_step(delta, aim_stance())


## Turns the view by a mouse delta in screen pixels (and blooms the aim cone).
func look(screen_delta: Vector2) -> void:
	weapons.add_look(screen_delta.length())
	rotation.y = wrapf(rotation.y - screen_delta.x * config.mouse_sensitivity, -PI, PI)
	var limit := deg_to_rad(config.max_pitch_deg)
	pitch = clampf(pitch - screen_delta.y * config.mouse_sensitivity, -limit, limit)
	_head.rotation.x = pitch


func is_mantling() -> bool:
	return _mantle != null


func is_dead() -> bool:
	return body.is_dead()


## Movement stance for the aim cone.
func aim_stance() -> AimModel.Stance:
	if _air_time > AIM_AIR_GRACE or _mantle != null:
		return AimModel.Stance.AIR
	if mode == PlayerMotion.Mode.SPRINT:
		return AimModel.Stance.SPRINT
	if horizontal_speed() > AIM_MOVING_SPEED:
		return AimModel.Stance.WALK
	return AimModel.Stance.CROUCH_STILL if crouched else AimModel.Stance.STILL


## Ground speed cap for `p_mode`: the mode's speed x carry load x `move_speed_mult`; both legs
## disabled: the crawl speed instead of the mode's.
func speed_cap(p_mode: PlayerMotion.Mode) -> float:
	var base := PlayerMotion.max_speed(p_mode, config)
	if body.legs_disabled():
		base = body.profile.crawl_speed
	return base * carry.speed_factor() * attributes.value(MOVE_SPEED)


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func capsule_height() -> float:
	return (_collision.shape as CapsuleShape3D).height


func eye_height() -> float:
	return _head.position.y


## The camera's global transform: eye position and view direction (-Z).
func eye_transform() -> Transform3D:
	return _camera.global_transform


## First thing the view ray hits within `length` metres (world, actors, objects), ignoring the
## player and what it carries; empty when nothing. Same keys as intersect_ray().
func look_hit(length: float) -> Dictionary:
	var eye := eye_transform()
	var exclude: Array[RID] = [get_rid()]
	if carry.is_carrying():
		exclude.append(carry.held.get_rid())
	var query := PhysicsRayQueryParameters3D.create(
		eye.origin, eye.origin - eye.basis.z * length, PhysicsLayers.LOOK_MASK, exclude
	)
	return get_world_3d().direct_space_state.intersect_ray(query)


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
	carry.drop(&"load")
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
	# No mantling while carrying (the hands are busy).
	var wants_mantle := (_jump_requested and grounded) or (jump_held and not grounded)
	if wants_mantle and not carry.is_carrying() and _try_start_mantle():
		_jump_requested = false
		return
	var jumping := _jump_requested and grounded
	_jump_requested = false

	var input := _move_input()
	var sprint_held := _input_allowed() and Input.is_action_pressed(&"sprint")
	mode = PlayerMotion.select_mode(grounded, crouched, sprint_held, input, config)
	if grounded:
		_air_speed_cap = speed_cap(mode)
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
			body.take_fall(fall_speed)
		else:
			var travelled := Vector2(global_position.x - before.x, global_position.z - before.z).length()
			if _footsteps.advance(travelled, PlayerNoiseRules.stride(mode, config)):
				noise.footstep(mode, surface)
	_was_grounded = grounded
	_air_time = 0.0 if grounded else _air_time + get_physics_process_delta_time()


func _update_surface() -> void:
	_floor_ray.force_raycast_update()
	if _floor_ray.is_colliding():
		surface = config.surfaces.surface_of(_floor_ray.get_collider())


# Crouch is held. Standing up waits until there is headroom. Both legs disabled: always crouched.
func _update_crouch() -> void:
	if body.legs_disabled():
		if not crouched:
			_apply_crouched(true)
		return
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
	hitboxes.set_height_factor(height / config.standing_height)


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


# use: use the looked-at thing, else pick up / put down; drop_throw: drop; fire: throw while
# carrying, else the weapon; reload; belt_1 / belt_2: pistol / baton (until the M5 belt).
# Dead: only `use`, which asks for a level reset.
func _handle_actions() -> void:
	var can_press: bool = input_enabled and not DebugPanel.is_open()
	for action in PRESS_ACTIONS:
		var held: bool = can_press and Input.is_action_pressed(action)
		var pressed: bool = held and not _actions_held.get(action, false)
		_actions_held[action] = held
		if not pressed:
			continue
		if not body.can_act():
			if action == &"use" and body.is_dead():
				request_reset()
			continue
		match action:
			&"use":
				_use()
			&"drop_throw":
				carry.drop()
			&"fire":
				if carry.is_carrying():
					carry.throw()
				else:
					weapons.trigger()
			&"reload":
				weapons.reload()
			&"belt_1":
				weapons.toggle(0)
			&"belt_2":
				weapons.toggle(1)


## Death overlay: reloads the level (or only signals, for tests).
func request_reset() -> void:
	reset_requested.emit()
	if reload_on_reset:
		LevelReset.reload_level(get_tree())


# Something Usable under the crosshair (a medkit) is used; otherwise carry handles it.
func _use() -> void:
	if not carry.is_carrying():
		var hit := look_hit(config.carry_reach)
		var usable := Usable.of(hit["collider"] as Node) if not hit.is_empty() else null
		if usable != null and usable.use(self):
			return
	carry.use()


func _on_died() -> void:
	_mantle = null
	carry.drop(&"died")
	weapons.holster()


func _respawn() -> void:
	_mantle = null
	carry.drop(&"respawn")
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	_ground_y = global_position.y


func _move_input() -> Vector2:
	if not _input_allowed():
		return Vector2.ZERO
	return Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")


func _input_allowed() -> bool:
	return input_enabled and not DebugPanel.is_open() and body.can_act()
