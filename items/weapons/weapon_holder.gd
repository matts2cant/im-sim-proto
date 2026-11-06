class_name WeaponHolder
extends Node3D
## Component of a character, child of its camera: the weapons it holds, the equipped one and its
## AimModel. Ranged weapons emit a `damage.*` RAY per damage entry along a direction sampled inside
## the aim cone (PhysicsLayers.WEAPON_MASK, the user's own body and hitboxes excluded), a muzzle
## `noise`, an impact `noise` and an impulse on a physics object hit. Melee weapons sweep a sphere
## along the view and send `damage.*` CONTACT to what they hit (a hitbox carries its part).
## The view model is a placeholder box. Until the M5 belt, the player toggles slots with belt_1/2.

signal changed

const ATTRIBUTE_SPREAD: StringName = &"aim_spread_add"
const ATTRIBUTE_SWAY: StringName = &"aim_sway_mult"
## Recoil time of a shot; a swing animates over half its cycle.
const KICK_TIME: float = 0.12

@export var weapons: Array[WeaponData] = []
@export var aim_config: AimConfig
## Seed of the shot RandomNumberGenerator; 0 = random (tests seed it).
@export var rng_seed: int = 0

## The character holding the weapons (shots come from it; its body and hitboxes are excluded).
var user: CollisionObject3D
## Eye: shots and sweeps start here along -Z.
var camera: Camera3D
var states: Array[WeaponState] = []
## Index into `weapons` of the equipped one, -1 when holstered.
var current: int = -1
var aim: AimModel
## Last hit of the equipped weapon, for tests and the debug panel: {collider, position} or {}.
var last_hit: Dictionary = {}

var _look_pixels: float = 0.0
var _floor: float = 0.0
var _kick: float = 0.0
var _kick_length: float = KICK_TIME
var _sway: Vector2 = Vector2.ZERO
var _view: MeshInstance3D
var _audio: AudioStreamPlayer3D


func _ready() -> void:
	add_to_group(&"saveable")
	aim = AimModel.new(aim_config, rng_seed)
	for data in weapons:
		states.append(WeaponState.new(data))
	_view = MeshInstance3D.new()
	_view.name = "ViewModel"
	_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_view.visible = false
	add_child(_view)
	_audio = AudioStreamPlayer3D.new()
	_audio.name = "Audio"
	_audio.max_polyphony = 3
	add_child(_audio)


func setup(p_user: CollisionObject3D, p_camera: Camera3D) -> void:
	user = p_user
	camera = p_camera


## Reseeds the shot generator (tests).
func seed_rng(value: int) -> void:
	aim.rng.seed = value


func weapon() -> WeaponData:
	return weapons[current] if current >= 0 else null


func state() -> WeaponState:
	return states[current] if current >= 0 else null


func is_armed() -> bool:
	return current >= 0


## belt key: equips slot `index`, or holsters when it is already equipped.
func toggle(index: int) -> void:
	if index == current:
		holster()
	else:
		equip(index)


func equip(index: int) -> void:
	if index < 0 or index >= weapons.size() or index == current:
		return
	if current >= 0:
		states[current].cancel_reload()
	current = index
	_build_view(weapons[index])
	_log(&"weapon.equipped", {"weapon": weapons[index].id})
	changed.emit()


func holster() -> void:
	if current < 0:
		return
	var data := weapons[current]
	states[current].cancel_reload()
	current = -1
	_view.visible = false
	_log(&"weapon.holstered", {"weapon": data.id})
	changed.emit()


## Mouse look this frame (pixels); applied as bloom once per physics step.
func add_look(pixels: float) -> void:
	_look_pixels += absf(pixels)


## Called by the user every physics tick with its movement stance.
func physics_step(delta: float, stance: AimModel.Stance) -> void:
	if _look_pixels > 0.0:
		aim.add_look(_look_pixels)
		_look_pixels = 0.0
	_floor = aim.floor_for(stance, _attribute(ATTRIBUTE_SPREAD, 0.0))
	aim.step(delta, _floor)
	_sway = aim.sway(_attribute(ATTRIBUTE_SWAY, 1.0))
	for weapon_state in states:
		var was_reloading := weapon_state.is_reloading()
		weapon_state.step(delta)
		if was_reloading and not weapon_state.is_reloading():
			_log(&"weapon.reloaded", {"weapon": weapon_state.data.id, "magazine": weapon_state.magazine})
			changed.emit()
	_kick = maxf(_kick - delta, 0.0)
	_animate_view()


## Snaps the cone to the floor of the last step (tests; a level start).
func settle() -> void:
	aim.spread = maxf(_floor, 0.0) if _floor > 0.0 else aim.config.base_min_deg


## Current aim sway in degrees (HUD: the reticle moves with it).
func sway() -> Vector2:
	return _sway


## Fire / swing the equipped weapon (press edge). Returns the WeaponState result, or -1 when
## nothing happened (holstered, or the user cannot use weapons).
func trigger() -> int:
	var data := weapon()
	if data == null:
		return -1
	var body := BodyParts.of(user)
	if body != null and (not body.can_act() or body.arms_disabled()):
		_log(&"weapon.refused", {"weapon": data.id, "reason": "arms_disabled" if body.can_act() else "incapacitated"})
		return -1
	var result := states[current].try_fire()
	match result:
		WeaponState.Result.FIRED:
			_kick_length = data.cycle_time * 0.5 if data.is_melee() else KICK_TIME
			_kick = _kick_length
			if data.is_melee():
				_swing(data)
			else:
				_shoot(data)
			changed.emit()
		WeaponState.Result.DRY:
			_play(data.dry_fire_sound, 0.0)
			_log(&"weapon.dry_fire", {"weapon": data.id})
	return result


## Starts reloading the equipped weapon; false when there is nothing to do.
func reload() -> bool:
	var weapon_state := state()
	if weapon_state == null or not weapon_state.start_reload():
		return false
	_play(weapon_state.data.reload_sound, -8.0)
	_log(&"weapon.reload_started", {"weapon": weapon_state.data.id, "time": weapon_state.data.reload_time})
	changed.emit()
	return true


## The eye transform shots use: the camera turned by the current sway.
func aim_transform() -> Transform3D:
	var eye := camera.global_transform
	return Transform3D(AimModel.swayed(eye.basis, _sway), eye.origin)


func save_state() -> Dictionary:
	var ammo: Array[Dictionary] = []
	for weapon_state in states:
		ammo.append(weapon_state.to_dict())
	return {"current": current, "ammo": ammo}


func load_state(data: Dictionary) -> void:
	var ammo: Array = data.get("ammo", [])
	for i in mini(ammo.size(), states.size()):
		states[i].from_dict(ammo[i] as Dictionary)
	var wanted := int(data.get("current", -1))
	if wanted < 0:
		holster()
	else:
		equip(wanted)
	changed.emit()


func _shoot(data: WeaponData) -> void:
	var eye := aim_transform()
	var direction := aim.sample_direction(eye.basis)
	var spread := aim.spread
	var exclude := _own_rids()
	var query := PhysicsRayQueryParameters3D.create(
		eye.origin, eye.origin + direction * data.max_range, PhysicsLayers.WEAPON_MASK, exclude
	)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	for type: StringName in data.damage:
		var ray := Stimulus.make_ray(
			type, data.damage[type], eye.origin, direction, data.max_range, user, PhysicsLayers.WEAPON_MASK
		)
		ray.exclude = exclude
		StimulusSystem.emit(ray)
	StimulusSystem.emit(Stimulus.make_noise(data.fire_noise, _muzzle(), user))
	last_hit = {}
	var hit_name := ""
	if not hit.is_empty():
		var point: Vector3 = hit["position"]
		var collider := hit["collider"] as Node
		hit_name = String(collider.name)
		last_hit = {"collider": collider, "position": point}
		StimulusSystem.emit(Stimulus.make_noise(data.impact_noise, point, user))
		var body := collider as RigidBody3D
		if body != null and data.impact_impulse > 0.0:
			body.apply_impulse(direction * data.impact_impulse, point - body.global_position)
		_play_at(data.hit_sound, point)
	aim.add_shot()
	_play(data.fire_sound, data.fire_volume_db)
	var logged := {
		"weapon": data.id,
		"magazine": states[current].magazine,
		"spread": spread,
		"hit": hit_name,
	}
	_log(&"weapon.fired", logged)


func _swing(data: WeaponData) -> void:
	var eye := camera.global_transform
	var forward := -eye.basis.z.normalized()
	var sphere := SphereShape3D.new()
	sphere.radius = data.sweep_radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = sphere
	params.collision_mask = PhysicsLayers.WEAPON_MASK
	params.exclude = _own_rids()
	params.transform = Transform3D(Basis.IDENTITY, eye.origin)
	# The sphere's front reaches max_range from the eye.
	params.motion = forward * maxf(data.max_range - data.sweep_radius, 0.0)
	var space := get_world_3d().direct_space_state
	var fractions := space.cast_motion(params)
	StimulusSystem.emit(Stimulus.make_noise(data.fire_noise, eye.origin, user))
	_play(data.fire_sound, data.fire_volume_db)
	last_hit = {}
	var hit_name := ""
	if fractions.size() == 2 and fractions[1] < 1.0:
		params.transform.origin += params.motion * fractions[1]
		params.motion = Vector3.ZERO
		var info := space.get_rest_info(params)
		var collider: Node = null
		if not info.is_empty():
			collider = instance_from_id(int(info["collider_id"])) as Node
		if collider != null:
			var point: Vector3 = info["point"]
			hit_name = String(collider.name)
			last_hit = {"collider": collider, "position": point}
			for type: StringName in data.damage:
				StimulusSystem.emit(Stimulus.make_contact(type, data.damage[type], collider, user))
			StimulusSystem.emit(Stimulus.make_noise(data.impact_noise, point, user))
			_play_at(data.hit_sound, point)
	_log(&"weapon.swung", {"weapon": data.id, "hit": hit_name})


func _own_rids() -> Array[RID]:
	var rids: Array[RID] = []
	if is_instance_valid(user):
		rids.append(user.get_rid())
		rids.append_array(Hitboxes.rids_of(user))
	return rids


func _muzzle() -> Vector3:
	if _view != null and _view.visible:
		return _view.global_position
	return camera.global_position


func _attribute(attribute: StringName, fallback: float) -> float:
	var attributes := user.get_node_or_null(^"Attributes") as Attributes if is_instance_valid(user) else null
	if attributes == null or not attributes.attribute_set.has(attribute):
		return fallback
	return attributes.value(attribute)


func _build_view(data: WeaponData) -> void:
	var mesh := BoxMesh.new()
	mesh.size = data.view_size
	var material := StandardMaterial3D.new()
	material.albedo_color = data.view_color
	material.roughness = 0.6
	mesh.material = material
	_view.mesh = mesh
	_view.visible = true
	_animate_view()


# Recoil (pistol) or a downward chop (baton) while the kick timer runs.
func _animate_view() -> void:
	var data := weapon()
	if data == null:
		return
	var t := _kick / _kick_length if _kick_length > 0.0 else 0.0
	var view := Transform3D(Basis.IDENTITY, data.view_offset)
	if data.is_melee():
		view.basis = Basis(Vector3.RIGHT, -1.2 * t)
		view.origin += Vector3(0, 0.05 * t, -0.1 * t)
	else:
		view.basis = Basis(Vector3.RIGHT, 0.25 * t)
		view.origin += Vector3(0, 0, 0.04 * t)
	_view.transform = view


func _play(stream: AudioStream, volume_db: float) -> void:
	if stream == null:
		return
	_audio.stream = stream
	_audio.volume_db = volume_db
	_audio.play()


func _play_at(stream: AudioStream, point: Vector3) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.name = "HitSound"
	player.stream = stream
	player.volume_db = -6.0
	player.finished.connect(player.queue_free)
	get_viewport().add_child(player)
	player.global_position = point
	player.play()


func _log(kind: StringName, data: Dictionary) -> void:
	var source := String(user.name) if is_instance_valid(user) else ""
	EventLog.record(kind, source, "", data)
