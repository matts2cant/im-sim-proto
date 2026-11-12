class_name Player
extends CharacterBody3D
## First-person player: walk, sprint, crouch, jump, mantle, mouse look, carry and throw objects,
## use things (Interactor; reading a datapad logs it in the PersonalLog), inventory and belt
## (PlayerInventory), weapons (WeaponHolder) and body-part damage (BodyParts, Hitboxes).
## A thin adapter over the pure rules (PlayerMotion, MantleRules, CarryRules); tuning comes from
## `config`. Origin is at the feet. Collision layer 2 (ADR 0045).
## Physics props do not collide with this body in the solver; the BodyPusher component pushes them
## and presses on what the player stands on with bounded forces instead (ADR 0054); ImpactSensor turns props
## flying into it into `damage.blunt`.
## Generic character components do the rest (ADR 0056): MovementNoise (footsteps, landings; reads
## the stance tags this script sets), FallImpact (`damage.fall` -> the `fall_damage` receptron),
## Knockback (`force.*`), BodyParts via the `body_damage` receptron, StepClimber (walks up steps and
## down stairs, ADR 0058; the camera eases over its `stepped` height changes).
## State comes from tags (ActorState): `state.dead` / `state.unconscious` stop input except `use`,
## which asks for a level reset (the HUD's losing overlay), `state.legs_disabled` forces a crawl;
## `move_speed_mult` scales speed. The attributes `jump_apex_height` and `mantle_max_height` (base:
## config) change the jump and the highest mantle (Speed Enhancement). Skills, Energy and Augmentations (ADR 0061) are
## generic components; this script only maps F1-F5 (`aug_<n>`) to Augmentations.toggle_slot().
## Weapons (ADR 0085): LMB held sets the WeaponHolder's `trigger_held` (automatic weapons), RMB
## (`alt_fire`) toggles a weapon's scope (with a deck in hand: its AR cable view, DeckArView, M12c);
## the camera follows the holder's scope FOV and mouse look scales with it.
## Profile settings (GameSettings, ADR 0124): the hip FOV (applied at once, even while paused), the
## mouse sensitivity multiplier and invert Y.
## Saveable.

signal mantled(height: float)
## The player pressed `use` while dead or knocked out (the HUD's losing overlay says so).
signal reset_requested

const DEBUG_TAB: PackedScene = preload("res://ui/debug_panel/tabs/player_tab.tscn")
const STATS_TAB: PackedScene = preload("res://ui/debug_panel/tabs/stats_tab.tscn")
const GROUP: StringName = &"player"
## Belt keys, slot 0 first (key 1 ... key 0).
const BELT_ACTIONS: Array[StringName] = [
	&"belt_1", &"belt_2", &"belt_3", &"belt_4", &"belt_5", &"belt_6", &"belt_7", &"belt_8", &"belt_9", &"belt_0"
]
## Actions handled on their press edge in _physics_process (interact, carry, weapons, belt).
const PRESS_ACTIONS: Array[StringName] = [
	&"use",
	&"drop_throw",
	&"fire",
	&"alt_fire",
	&"reload",
	&"holster",
	&"belt_1",
	&"belt_2",
	&"belt_3",
	&"belt_4",
	&"belt_5",
	&"belt_6",
	&"belt_7",
	&"belt_8",
	&"belt_9",
	&"belt_0",
	&"aug_1",
	&"aug_2",
	&"aug_3",
	&"aug_4",
	&"aug_5",
]
## Augmentation toggle keys (F1-F5), slot 1 first.
const AUG_ACTIONS: Array[StringName] = [&"aug_1", &"aug_2", &"aug_3", &"aug_4", &"aug_5"]
const MOVE_SPEED: StringName = &"move_speed_mult"
const JUMP_APEX: StringName = &"jump_apex_height"
const MANTLE_MAX: StringName = &"mantle_max_height"

@export var config: PlayerConfig
## When false the player ignores input (cutscenes, tests that drive it directly).
@export var input_enabled: bool = true
## When false, `use` while dead only emits `reset_requested` (tests) instead of reloading the level.
@export var reload_on_reset: bool = true

var mode: PlayerMotion.Mode = PlayerMotion.Mode.IDLE
var crouched: bool = false
var pitch: float = 0.0

var _probe: PlayerProbe
var _jump_requested: bool = false
var _jump_was_held: bool = false
var _air_time: float = 0.0
var _air_speed_cap: float = 0.0
## Height of the ground last stood on; caps how high a ledge can be mantled after a jump.
var _ground_y: float = 0.0
var _mantle: MantleRules.Plan = null
var _mantle_time: float = 0.0
var _spawn_transform: Transform3D
var _debug_tab: Node
var _stats_tab: Node
var _actions_held: Dictionary[StringName, bool] = {}
## Mouse wheel notches since the last physics tick (+1 per `belt_next`, -1 per `belt_prev`). Wheel
## buttons press and release within one event pair, so they are counted as events, not polled.
var _belt_steps: int = 0
## Camera height minus eye height (m): a step moves the body at once, the view eases after it.
var _view_offset: float = 0.0
## The camera's field of view without a scope (GameSettings.fov(), default 80 degrees vertical).
var _hip_fov: float = 80.0
## face_towards(): the point the view turns to and the seconds left of the turn.
var _face_point: Vector3 = Vector3.ZERO
var _face_left: float = 0.0
## LMB was still held when a screen gave the input back: tools wait for a fresh press.
var _tool_latched: bool = false

@onready var noise: MovementNoise = $Noise
@onready var fall_impact: FallImpact = $FallImpact
@onready var step: StepClimber = $Step
@onready var pusher: BodyPusher = $Pusher
@onready var carry: PlayerCarry = $Carry
@onready var body: BodyParts = $BodyParts
@onready var hitboxes: Hitboxes = $Hitboxes
@onready var weapons: WeaponHolder = $Head/Camera/WeaponHolder
@onready var attributes: Attributes = $Attributes
@onready var inventory: PlayerInventory = $Inventory
@onready var interactor: Interactor = $Interactor
@onready var tool_use: ToolUse = $ToolUse
@onready var skills: Skills = $Skills
@onready var energy: Energy = $Energy
@onready var augmentations: Augmentations = $Augmentations
@onready var _collision: CollisionShape3D = $Collision
@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera


func _ready() -> void:
	add_to_group(&"saveable")
	add_to_group(GROUP)
	carry.player = self
	carry.config = config
	weapons.setup(self, _camera)
	_apply_view_settings()
	GameSettings.notifier().changed.connect(_on_setting_changed)
	inventory.setup(self)
	interactor.player = self
	body.died.connect(_on_died)
	step.stepped.connect(_on_stepped)
	_collision.shape = _collision.shape.duplicate()
	(_collision.shape as CapsuleShape3D).radius = config.capsule_radius
	floor_max_angle = deg_to_rad(config.max_slope_deg)
	_probe = PlayerProbe.new(self, config)
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
	if is_instance_valid(_stats_tab):
		_stats_tab.queue_free()
	_stats_tab = null
	if input_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if not _input_allowed():
		return
	if event.is_action_pressed(&"jump"):
		_jump_requested = true
	elif event.is_action_pressed(&"belt_next"):
		_belt_steps += 1
	elif event.is_action_pressed(&"belt_prev"):
		_belt_steps -= 1
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
	_set_view_offset(StepRules.ease_offset(_view_offset, delta, step.config))
	_step_face(delta)
	interactor.refresh()
	_step_tool(delta)
	_handle_actions()
	carry.physics_step()
	weapons.trigger_held = _trigger_held()
	weapons.recoil.view_share = camera_motion()
	weapons.physics_step(delta, aim_stance())
	_apply_view_recoil()
	_camera.fov = weapons.scope.view_fov(weapons.weapon(), _hip_fov)


## Turns the view by a mouse delta in screen pixels (and blooms the aim cone). Through a scope the
## turn (and the bloom) scales with the field of view, so the crosshair moves as far on screen per
## pixel as at the hip (ADR 0085). The profile's sensitivity multiplier scales the turn and the bloom
## (the bloom follows the turned angle); invert Y flips the pitch.
func look(screen_delta: Vector2) -> void:
	var turn_scale := fov_ratio() * GameSettings.mouse_sensitivity()
	weapons.add_look(screen_delta.length() * turn_scale)
	var sensitivity := config.mouse_sensitivity * turn_scale
	rotation.y = wrapf(rotation.y - screen_delta.x * sensitivity, -PI, PI)
	var limit := deg_to_rad(config.max_pitch_deg)
	var pitch_sign := -1.0 if GameSettings.invert_y() else 1.0
	pitch = clampf(pitch - screen_delta.y * sensitivity * pitch_sign, -limit, limit)
	_head.rotation.x = pitch


## Share (0-1) of a weapon's recoil climb the camera follows (ADR 0123): the camera motion
## setting (GameSettings, ADR 0124). The shots follow the whole climb whatever it is.
func camera_motion() -> float:
	return GameSettings.camera_motion()


## The camera's field of view over the hip one (1 without a scope, 15 / 80 fully scoped at the
## default FOV).
func fov_ratio() -> float:
	return _camera.fov / _hip_fov if _hip_fov > 0.0 else 1.0


## The profile's hip FOV now (the camera follows the scope's FOV from it).
func _apply_view_settings() -> void:
	_hip_fov = GameSettings.fov()
	_camera.fov = weapons.scope.view_fov(weapons.weapon(), _hip_fov)


func _on_setting_changed(key: StringName) -> void:
	if key == GameSettings.FOV:
		_apply_view_settings()


func is_mantling() -> bool:
	return _mantle != null


func is_dead() -> bool:
	return ActorState.is_dead(self)


## Movement stance for the aim cone.
func aim_stance() -> AimModel.Stance:
	if _air_time > config.aim_air_grace or _mantle != null:
		return AimModel.Stance.AIR
	if mode == PlayerMotion.Mode.SPRINT:
		return AimModel.Stance.SPRINT
	if horizontal_speed() > config.aim_moving_speed:
		return AimModel.Stance.WALK
	return AimModel.Stance.CROUCH_STILL if crouched else AimModel.Stance.STILL


## Ground speed cap for `p_mode`: the mode's speed x carry load x `move_speed_mult`; both legs
## disabled: the crawl speed instead of the mode's.
func speed_cap(p_mode: PlayerMotion.Mode) -> float:
	var base := PlayerMotion.max_speed(p_mode, config)
	if ActorState.legs_disabled(self):
		base = body.profile.crawl_speed
	return base * carry.speed_factor() * attributes.value(MOVE_SPEED)


## Jump apex (m): config.jump_apex_height through the `jump_apex_height` attribute.
func jump_apex_height() -> float:
	return Attributes.read(self, JUMP_APEX, config.jump_apex_height)


## Highest ledge top (m) above the last ground that can be mantled: config.mantle_max_height
## through the `mantle_max_height` attribute.
func mantle_max_height() -> float:
	return Attributes.read(self, MANTLE_MAX, config.mantle_max_height)


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func capsule_height() -> float:
	return (_collision.shape as CapsuleShape3D).height


func eye_height() -> float:
	return _head.position.y


## The camera's global transform: eye position and view direction (-Z). It includes the easing
## after a step (ADR 0058): rays aim from where the view is, so they match the crosshair.
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


## Takes the current key state as "already held", so a key still down when a pause screen closes
## (E closing the reading overlay) does not count as a new press; LMB still down does not work a
## tool until it is pressed again (leaving the lockpicking screen does not start it again).
func resync_actions() -> void:
	for action in PRESS_ACTIONS:
		_actions_held[action] = Input.is_action_pressed(action)
	_jump_was_held = Input.is_action_pressed(&"jump")
	_tool_latched = Input.is_action_pressed(&"fire")


## Turns the view to look at `point` (world) over `duration` seconds, smoothly (the lockpicking
## screen faces the lock). Mouse look would fight it: callers take the input first.
func face_towards(point: Vector3, duration: float) -> void:
	_face_point = point
	_face_left = maxf(duration, 0.001)


func save_state() -> Dictionary:
	return {
		"position": global_position,
		"yaw": rotation.y,
		"pitch": pitch,
		"crouched": crouched,
		"velocity": velocity,
		"inventory": inventory.save_state(),
	}


## Restores what `data` has (tests pass only position and view; the inventory is optional).
func load_state(data: Dictionary) -> void:
	_mantle = null
	_face_left = 0.0
	carry.drop(&"load")
	global_position = data.get("position", global_position)
	rotation.y = data.get("yaw", rotation.y)
	pitch = data.get("pitch", pitch)
	_head.rotation.x = pitch
	velocity = data.get("velocity", velocity)
	_apply_crouched(data.get("crouched", crouched))
	_head.position.y = PlayerMotion.eye_height(crouched, config)
	_ground_y = global_position.y
	noise.reset()
	fall_impact.reset()
	step.reset()
	_set_view_offset(0.0)
	if data.has("inventory"):
		inventory.load_state(data["inventory"])


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
	_update_stance_tags()
	if grounded:
		_air_speed_cap = speed_cap(mode)
	var wish := global_basis * Vector3(input.x, 0.0, input.y)
	var horizontal := PlayerMotion.horizontal_velocity(velocity, wish, _air_speed_cap, grounded, delta, config)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	var gravity := get_gravity() * config.gravity_scale
	if jumping:
		velocity.y = PlayerMotion.jump_speed(jump_apex_height(), gravity.length())
	elif not grounded:
		velocity += gravity * delta

	var attempted := velocity
	move_and_slide()
	var on_floor := is_on_floor()
	if on_floor:
		_ground_y = global_position.y
	_air_time = 0.0 if on_floor else _air_time + delta
	pusher.after_move(attempted, delta)


# The stance tags MovementNoise, StepClimber (and anything else) read: crouched, sprinting, mantling.
func _update_stance_tags() -> void:
	ActorState.set_tag(self, ActorState.CROUCHING, crouched)
	ActorState.set_tag(self, ActorState.SPRINTING, mode == PlayerMotion.Mode.SPRINT)
	ActorState.set_tag(self, ActorState.MANTLING, _mantle != null)


# Crouch is held. Standing up waits until there is headroom. Both legs disabled: always crouched.
# While a screen holds the input (lockpicking, a computer) the stance stays as it was.
func _update_crouch() -> void:
	if ActorState.legs_disabled(self):
		if not crouched:
			_apply_crouched(true)
		return
	if not input_enabled:
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
	_update_stance_tags()


func _try_start_mantle() -> bool:
	var max_height := mantle_max_height()
	var probe := _probe.find_ledge(global_position, -global_basis.z, _ground_y, max_height)
	var plan := MantleRules.evaluate(probe, global_position, config, max_height)
	if plan == null:
		return false
	_mantle = plan
	_mantle_time = 0.0
	mode = PlayerMotion.Mode.MANTLE
	_update_stance_tags()
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
	_ground_y = global_position.y
	noise.reset()
	EventLog.record(&"player.mantled", name, "", {"height": height})
	mantled.emit(height)


func _register_debug_tab() -> void:
	_debug_tab = DEBUG_TAB.instantiate()
	_debug_tab.set(&"player", self)
	DebugPanel.register_tab("Player", _debug_tab as Control)
	_stats_tab = STATS_TAB.instantiate()
	_stats_tab.set(&"entity", self)
	DebugPanel.register_tab("Stats", _stats_tab as Control)


# use: the Interactor (pick up, use, carry, put down); drop_throw: drop what is carried, else the
# item in hand; fire: throw while carrying, else use the item in hand (fire the weapon, use a
# medkit; a tool is worked while LMB is held: _step_tool); reload; holster: empty hands; belt keys: the belt slot
# (again: put away); wheel: the next / previous belt item (ADR 0059); F1-F4: augmentation toggles.
# Dead or knocked out: only `use`, which asks for a level reset.
func _handle_actions() -> void:
	var can_press: bool = input_enabled and not DebugPanel.is_open()
	var steps := _belt_steps
	_belt_steps = 0
	if can_press and ActorState.can_act(self):
		for i in absi(steps):
			inventory.cycle(signi(steps))
	for action in PRESS_ACTIONS:
		var held: bool = can_press and Input.is_action_pressed(action)
		var pressed: bool = held and not _actions_held.get(action, false)
		_actions_held[action] = held
		if not pressed:
			continue
		if not ActorState.can_act(self):
			if action == &"use":
				request_reset()
			continue
		match action:
			&"use":
				interactor.perform()
			&"drop_throw":
				if carry.is_carrying():
					carry.drop()
				else:
					inventory.drop_in_hand()
			&"fire":
				if carry.is_carrying():
					carry.throw()
				elif not inventory.use_held():
					weapons.trigger()
			&"alt_fire":
				# A deck in hand toggles its AR cable view (M12c); a weapon its scope.
				var ar_view := DeckArView.of(self)
				if ar_view == null or not ar_view.toggle():
					weapons.toggle_scope()
			&"reload":
				weapons.reload()
			&"holster":
				inventory.put_away()
			&"aug_1", &"aug_2", &"aug_3", &"aug_4", &"aug_5":
				augmentations.toggle_slot(AUG_ACTIONS.find(action) + 1)
			_:
				inventory.select_slot(BELT_ACTIONS.find(action))


# Holding LMB with a tool in hand works it on what the crosshair is on (ToolUse: a lockpick on a
# mechanical lock, ADR 0078; from afar, a ranged target such as an access point for the deck, ADR
# 0117); letting go, looking away or carrying something stops.
func _step_tool(delta: float) -> void:
	if _tool_latched and not Input.is_action_pressed(&"fire"):
		_tool_latched = false
	var holding: bool = (
		input_enabled
		and not _tool_latched
		and not DebugPanel.is_open()
		and ActorState.can_act(self)
		and not carry.is_carrying()
		and Input.is_action_pressed(&"fire")
	)
	var tool := inventory.held_tool()
	# Ranged tool targets (the deck aimed at an access point): only looked for while working a tool
	# that nothing within reach takes.
	var aimed: Node = null
	if holding and not tool.is_empty() and ToolUse.find_target(interactor.looked_at, tool) == null:
		aimed = interactor.aimed_at(tool_use.aim_reach)
	tool_use.step(interactor.looked_at, tool, holding, delta, aimed)


# LMB held with a weapon in hand (nothing carried, able to act): an automatic weapon keeps firing
# (hold, not toggle; releasing stops it).
func _trigger_held() -> bool:
	return (
		input_enabled
		and not DebugPanel.is_open()
		and ActorState.can_act(self)
		and not carry.is_carrying()
		and inventory.held == null
		and Input.is_action_pressed(&"fire")
	)


## Losing overlay (dead or knocked out): reloads the level (or only signals, for tests).
func request_reset() -> void:
	reset_requested.emit()
	if reload_on_reset:
		LevelReset.reload_level(get_tree())


func _on_died() -> void:
	_mantle = null
	carry.drop(&"died")
	inventory.put_away()


func _respawn() -> void:
	_mantle = null
	carry.drop(&"respawn")
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	_ground_y = global_position.y
	step.reset()
	_set_view_offset(0.0)


# face_towards(): eases yaw and pitch towards the point for the time left.
func _step_face(delta: float) -> void:
	if _face_left <= 0.0:
		return
	var to := _face_point - eye_transform().origin
	var flat := Vector2(to.x, to.z).length()
	if to.length_squared() < 0.0001:
		_face_left = 0.0
		return
	var share := minf(1.0, delta / _face_left)
	_face_left -= delta
	var yaw := atan2(-to.x, -to.z)
	rotation.y = wrapf(rotation.y + wrapf(yaw - rotation.y, -PI, PI) * share, -PI, PI)
	var limit := deg_to_rad(config.max_pitch_deg)
	pitch = lerpf(pitch, clampf(atan2(to.y, flat), -limit, limit), share)
	_head.rotation.x = pitch


# The camera turns by the weapon's recoil climb (its camera share) on top of the mouse look: mouse
# look moves `pitch` and the yaw as always, so pulling down compensates; the climb returns by itself.
func _apply_view_recoil() -> void:
	var climb := weapons.recoil.view_recoil()
	_camera.rotation = Vector3(deg_to_rad(climb.y), -deg_to_rad(climb.x), 0.0)


# A step moved the body by `rise`: the camera stays where it was and eases after it.
func _on_stepped(rise: float) -> void:
	_set_view_offset(_view_offset - rise)


func _set_view_offset(offset: float) -> void:
	_view_offset = offset
	_camera.position.y = offset


func _move_input() -> Vector2:
	if not _input_allowed():
		return Vector2.ZERO
	return Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")


func _input_allowed() -> bool:
	return input_enabled and not DebugPanel.is_open() and ActorState.can_act(self)
