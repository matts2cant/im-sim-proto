class_name WeaponHolder
extends Node3D
## Component of any character (the player, guards; ADR 0070), child of its eye (the player's camera,
## a guard's Aim node): the weapons it holds, the equipped one and its AimModel. Shots and sweeps
## start at the eye along its -Z; whoever drives the holder points the eye (mouse look, or a combat
## component aiming at a target) and calls physics_step() and trigger(). Nothing here reads input.
## Ranged weapons emit a `damage.*` RAY per damage entry along a direction sampled inside the aim
## cone (PhysicsLayers.WEAPON_MASK, the user's own body and hitboxes excluded), a `force.impact` RAY
## along the same line (WeaponData.impact_impulse in N s: whatever it hits and has a `force`
## receptron is pushed at the hit point; ADR 0057), a muzzle `noise` and an impact `noise`.
## Melee weapons sweep a sphere along the view and send `damage.*` CONTACT to what they hit (a hitbox
## carries its part).
## The user's attributes of the weapon's class (WeaponData.attribute_class, ADR 0061) scale it: damage
## (through Stimulus.scale_attribute), cycle, reload, cone floors, bloom and the pellet cone, settle
## time, sway (on top of `aim_sway_mult`); crouching (`stance.crouch`) settles faster
## (AimConfig.crouch_settle_factor).
## Per weapon (ADR 0085): several projectiles per shot spread inside a cone (WeaponData.pellets,
## PelletPattern), automatic fire while `trigger_held`, the weapon's own aim cone
## (WeaponData.aim_config) and a scope (toggle_scope(); `scope`, a ScopeState: the scope's cone, the
## view model hidden; it comes off when the weapon is switched or put away, a reload starts or the
## user cannot use its arms; whoever owns the camera reads scope.view_fov()). Fitted attachments
## change the weapon's stats (WeaponState.stat(): fire noise, flash, volume, `suppressed` shot sound)
## and show on its model.
## The first-person view (model or placeholder box, recoil and swing, muzzle flash, cloak) is the
## WeaponView child "ViewPivot" (view_pivot()); on a guard it is the box it holds. Two ways to arm it:
## a fixed loadout (`weapons`, equip(index); guards' loadouts) that the holder saves itself, or
## equip_state() with a WeaponState owned elsewhere (the player's inventory weapon stacks, saved by
## PlayerInventory; ADR 0050). Fixed-loadout weapons can be taken out (remove_from_loadout(): a
## dropped weapon, WeaponDrop, ADR 0087); the save lists the ones left.
## `cause_id` (ADR 0087): when set, every stimulus the holder emits names it as its cause, so what
## the weapon does traces back to whoever made it fire (a turret's last command).
## A character with a model hangs the view from its hand (WeaponView.hang_from(), CharacterAnimator,
## ADR 0103): the weapon follows the arm; shots still leave the eye.

signal changed
## A shot or a swing of `weapon` happened (the trigger fired it): animation, effects.
signal fired(weapon: WeaponData)

const ATTRIBUTE_SPREAD: StringName = &"aim_spread_add"
const ATTRIBUTE_SWAY: StringName = &"aim_sway_mult"

## Fixed loadout (optional): one WeaponState each in `states`, saved by the holder.
@export var weapons: Array[WeaponData] = []
@export var aim_config: AimConfig
## Seed of the shot RandomNumberGenerator; 0 = random (tests seed it).
@export var rng_seed: int = 0
## First-person view: every weapon's grip pivot (WeaponData.view_offset) moved on screen by this
## angle, degrees (x: to the right, y: down; WeaponView.shift_deg), one rule for every weapon. The
## player's camera holder lowers its view models with it (ADR 0101); zero leaves the pose as the
## weapon's data has it (guards: the gun they hold).
@export var view_shift_deg: Vector2 = Vector2.ZERO:
	set(value):
		view_shift_deg = value
		if _view != null:
			_view.shift_deg = value

## The character holding the weapons (shots come from it; its body and hitboxes are excluded).
var user: CollisionObject3D
## Eye: shots and sweeps start here along -Z (the player's camera, a guard's Aim node).
var eye: Node3D
var states: Array[WeaponState] = []
## Index into `weapons` of the equipped one, -1 when holstered or armed through equip_state().
var current: int = -1
var aim: AimModel
## Last hit of the equipped weapon, for tests and the debug panel: {collider, position} or {}.
var last_hit: Dictionary = {}
## The muzzle flash of the view (MuzzleFlash.hold() freezes it for screenshots).
var flash: MuzzleFlash
## Scope of the equipped weapon (ADR 0085).
var scope := ScopeState.new()
## The trigger is held now (the user's input or AI sets it every tick): an automatic weapon fires
## again each cycle while it is (ADR 0085); false stops it.
var trigger_held: bool = false
## Stimulus id every shot, swing and noise names as its cause (Stimulus.cause_id); 0: none (the
## stimulus system fills in the stimulus being delivered, if any).
var cause_id: int = 0

var _equipped: WeaponState = null
var _look_pixels: float = 0.0
var _floor: float = 0.0
var _sway: Vector2 = Vector2.ZERO
var _view: WeaponView
var _audio: AudioStreamPlayer3D


func _ready() -> void:
	if not weapons.is_empty():
		add_to_group(&"saveable")
	# Its own copy: instances of one scene may share the exported array, and a drop removes from it.
	weapons = weapons.duplicate()
	aim = AimModel.new(aim_config, rng_seed)
	for data in weapons:
		states.append(WeaponState.new(data))
	_view = WeaponView.new()
	_view.shift_deg = view_shift_deg
	add_child(_view)
	flash = _view.flash
	_audio = AudioStreamPlayer3D.new()
	_audio.name = "Audio"
	_audio.max_polyphony = 3
	add_child(_audio)


func setup(p_user: CollisionObject3D, p_eye: Node3D) -> void:
	user = p_user
	eye = p_eye


## Reseeds the shot generator (tests).
func seed_rng(value: int) -> void:
	aim.rng.seed = value


func weapon() -> WeaponData:
	return _equipped.data if _equipped != null else null


func state() -> WeaponState:
	return _equipped


func is_armed() -> bool:
	return _equipped != null


## Fixed loadout: equips `weapons[index]`.
func equip(index: int) -> void:
	if index >= 0 and index < states.size():
		equip_state(states[index])


## Draws the weapon of `weapon_state` (owned by the caller, e.g. an inventory stack's).
func equip_state(weapon_state: WeaponState) -> void:
	if weapon_state == null or weapon_state == _equipped:
		return
	if _equipped != null:
		_equipped.cancel_reload()
		_equipped.attached.disconnect(_on_attached)
	_equipped = weapon_state
	_equipped.attached.connect(_on_attached)
	current = states.find(weapon_state)
	scope.reset()
	scope.zoom_time = weapon_state.data.scope_time
	trigger_held = false
	_view.show_weapon(weapon_state)
	_log(&"weapon.equipped", {"weapon": weapon_state.data.id})
	changed.emit()


func holster() -> void:
	if _equipped == null:
		return
	var data := _equipped.data
	_equipped.cancel_reload()
	_equipped.attached.disconnect(_on_attached)
	_equipped = null
	current = -1
	scope.reset()
	trigger_held = false
	_view.hide_weapon()
	_log(&"weapon.holstered", {"weapon": data.id})
	changed.emit()


## Mouse look this frame (pixels); applied as bloom once per physics step.
func add_look(pixels: float) -> void:
	_look_pixels += absf(pixels)


## Called by the user every physics tick with its movement stance. `floor_add` (degrees) widens the
## cone floor on top of the stance (a combat component's range and target-motion terms).
func physics_step(delta: float, stance: AimModel.Stance, floor_add: float = 0.0) -> void:
	aim.config = _aim_config()
	var spread_mult := _class_value("spread_mult", 1.0)
	if _look_pixels > 0.0:
		aim.add_look(_look_pixels, spread_mult)
		_look_pixels = 0.0
	var stance_floor := aim.floor_for(stance, _attribute(ATTRIBUTE_SPREAD, 0.0), spread_mult)
	_floor = minf(stance_floor + floor_add, aim.config.max_spread_deg)
	aim.step(delta, _floor, _settle_time())
	_sway = aim.sway(_attribute(ATTRIBUTE_SWAY, 1.0) * _class_value("sway_mult", 1.0))
	# Automatic fire before the cooldowns tick: one shot every cycle_time while held.
	_auto_fire()
	var stepped := states.duplicate()
	if _equipped != null and not stepped.has(_equipped):
		stepped.append(_equipped)
	for weapon_state: WeaponState in stepped:
		var was_reloading := weapon_state.is_reloading()
		weapon_state.step(delta)
		if was_reloading and not weapon_state.is_reloading():
			_log(&"weapon.reloaded", {"weapon": weapon_state.data.id, "magazine": weapon_state.magazine})
			changed.emit()
	if scope.step(delta, _can_scope()):
		_on_scope_changed("auto")
	_view.step(delta, ActorState.has(user, ActorState.CLOAKED))


# Settle time constant of the cone now: AimConfig.settle_time through the user's
# `<class>_settle_time` attribute, x crouch_settle_factor while the user is crouched.
func _settle_time() -> float:
	var settle := _class_value("settle_time", aim.config.settle_time)
	if ActorState.has(user, ActorState.CROUCHING):
		settle *= aim.config.crouch_settle_factor
	return settle


## Snaps the cone to the floor of the last step (tests; a level start).
func settle() -> void:
	aim.config = _aim_config()
	aim.spread = maxf(_floor, 0.0) if _floor > 0.0 else aim.config.base_min_deg


## Current aim sway in degrees (HUD: the reticle moves with it).
func sway() -> Vector2:
	return _sway


## RMB: scopes in or out (a weapon with a scope, the user able to use its arms, not reloading).
## Returns true when the scope changed.
func toggle_scope() -> bool:
	if not scope.toggle(_can_scope()):
		return false
	_on_scope_changed("toggle")
	return true


## Fire / swing the equipped weapon (press edge). Returns the WeaponState result, or -1 when
## nothing happened (holstered, or the user cannot use weapons).
func trigger() -> int:
	var data := weapon()
	if data == null:
		return -1
	# State tags (ActorState): injuries, sleep gas or cuffs all block it the same way.
	if not ActorState.can_use_arms(user):
		_log(
			&"weapon.refused",
			{"weapon": data.id, "reason": "arms_disabled" if ActorState.can_act(user) else "incapacitated"}
		)
		return -1
	aim.config = _aim_config()
	var result := _equipped.try_fire(_class_value("cycle_mult", 1.0))
	match result:
		WeaponState.Result.FIRED:
			_view.kick()
			if data.is_melee():
				_swing(data)
			else:
				_shoot(data)
			fired.emit(data)
			changed.emit()
		WeaponState.Result.DRY:
			_play(data.dry_fire_sound, 0.0)
			_log(&"weapon.dry_fire", {"weapon": data.id})
	return result


## Starts reloading the equipped weapon; false when there is nothing to do.
func reload() -> bool:
	var weapon_state := state()
	if weapon_state == null or not weapon_state.start_reload(_class_value("reload_mult", 1.0)):
		return false
	_play(weapon_state.data.reload_sound, -8.0)
	_log(&"weapon.reload_started", {"weapon": weapon_state.data.id, "time": weapon_state.reload_left})
	if scope.step(0.0, false):
		_on_scope_changed("reload")
	changed.emit()
	return true


## The eye transform shots use: the eye turned by the current sway.
func aim_transform() -> Transform3D:
	var eye_transform := eye.global_transform
	return Transform3D(AimModel.swayed(eye_transform.basis, _sway), eye_transform.origin)


## Takes `weapon_state` out of the fixed loadout (its weapon was dropped): holstered first when it is
## drawn. False when it is not part of the loadout (a weapon armed through equip_state()).
func remove_from_loadout(weapon_state: WeaponState) -> bool:
	var index := states.find(weapon_state)
	if index < 0:
		return false
	if _equipped == weapon_state:
		holster()
	states.remove_at(index)
	weapons.remove_at(index)
	current = states.find(_equipped) if _equipped != null else -1
	_log(&"weapon.removed", {"weapon": weapon_state.data.id})
	changed.emit()
	return true


## Fixed loadout only (the holder is saveable when `weapons` is not empty): the weapons left (ids, in
## order), the equipped one and each one's ammo.
func save_state() -> Dictionary:
	var ammo: Array[Dictionary] = []
	var ids: Array[String] = []
	for weapon_state in states:
		ammo.append(weapon_state.to_dict())
		ids.append(String(weapon_state.data.id))
	return {"current": current, "ammo": ammo, "weapons": ids}


func load_state(data: Dictionary) -> void:
	if data.get("weapons") is Array:
		_keep_loadout(data["weapons"] as Array)
	var ammo: Array = data.get("ammo", [])
	for i in mini(ammo.size(), states.size()):
		states[i].from_dict(ammo[i] as Dictionary)
	var wanted := int(data.get("current", -1))
	if wanted < 0:
		holster()
	else:
		equip(wanted)
	changed.emit()


# Keeps the loadout entries named in `ids` (in that order, each entry used once): the weapons a save
# still had; the others were dropped.
func _keep_loadout(ids: Array) -> void:
	var kept_weapons: Array[WeaponData] = []
	var kept_states: Array[WeaponState] = []
	var used: Array[int] = []
	for id: Variant in ids:
		for i in states.size():
			if not used.has(i) and String(states[i].data.id) == str(id):
				used.append(i)
				kept_weapons.append(weapons[i])
				kept_states.append(states[i])
				break
	if kept_states.size() == states.size():
		return
	if _equipped != null and not kept_states.has(_equipped):
		holster()
	weapons = kept_weapons
	states = kept_states
	current = states.find(_equipped) if _equipped != null else -1


func _shoot(data: WeaponData) -> void:
	var from := aim_transform()
	var centre := aim.sample_direction(from.basis)
	var spread := aim.spread
	# The pellet cone narrows with the shooter's skill like the aim cone (`<class>_spread_mult`).
	var pellet_spread := data.pellet_spread_deg * _class_value("spread_mult", 1.0)
	var directions := PelletPattern.spread(centre, from.basis.y, data.pellets, pellet_spread, aim.rng)
	var exclude := _own_rids()
	var space := get_world_3d().direct_space_state
	var rays: Dictionary[StringName, float] = data.damage.duplicate()
	if data.impact_impulse > 0.0:
		rays[&"force.impact"] = data.impact_impulse
	var hits: Array[Dictionary] = []
	# Each projectile: one ray per damage entry and the push, along its own direction.
	for direction in directions:
		var query := PhysicsRayQueryParameters3D.create(
			from.origin, from.origin + direction * data.max_range, PhysicsLayers.WEAPON_MASK, exclude
		)
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			hits.append(hit)
		for type: StringName in rays:
			var ray := Stimulus.make_ray(
				type, rays[type], from.origin, direction, data.max_range, user, PhysicsLayers.WEAPON_MASK
			)
			ray.exclude = exclude
			if data.damage.has(type):
				ray.scale_attribute = data.class_attribute("damage_mult")
			_emit(ray)
	_emit(Stimulus.make_noise(_equipped.stat(&"fire_noise"), _muzzle(), user))
	last_hit = {}
	var hit_name := ""
	if not hits.is_empty():
		# One impact noise and sound per shot, where the first projectile struck.
		var point: Vector3 = hits[0]["position"]
		var collider := hits[0]["collider"] as Node
		hit_name = String(collider.name)
		last_hit = {"collider": collider, "position": point}
		_emit(Stimulus.make_noise(_equipped.stat(&"impact_noise"), point, user))
		_play_at(data.hit_sound, point)
	aim.add_shot(_class_value("spread_mult", 1.0))
	_play(_fire_sound(data), _equipped.stat(&"fire_volume_db"))
	flash.fire(data, _equipped.stat(&"muzzle_flash_size"))
	var logged := {
		"weapon": data.id,
		"magazine": _equipped.magazine,
		"spread": spread,
		"hit": hit_name,
		"projectiles": directions.size(),
		"hits": hits.size(),
		"noise": _equipped.stat(&"fire_noise"),
	}
	_log(&"weapon.fired", logged)


# The shot sound: the suppressed one while an attachment makes the weapon `suppressed`.
func _fire_sound(data: WeaponData) -> AudioStream:
	if _equipped.stat(&"suppressed") > 0.0 and data.suppressed_fire_sound != null:
		return data.suppressed_fire_sound
	return data.fire_sound


# One automatic shot when the trigger is held and the cycle allows it (never a dry click: an empty
# magazine stops the burst).
func _auto_fire() -> void:
	var data := weapon()
	if not trigger_held or data == null or not data.automatic or not ActorState.can_use_arms(user):
		return
	if _equipped.is_reloading() or _equipped.cooldown > WeaponState.EPSILON:
		return
	if data.uses_ammo() and _equipped.magazine <= 0:
		return
	trigger()


# The aim cone in use: the equipped weapon's own (scoped or hip), else the holder's.
func _aim_config() -> AimConfig:
	var data := weapon()
	if data == null:
		return aim_config
	return data.aim_for(scope.scoped, aim_config)


# Scoping is possible: a weapon with a scope, arms usable, not reloading.
func _can_scope() -> bool:
	var data := weapon()
	return data != null and data.has_scope() and ActorState.can_use_arms(user) and not _equipped.is_reloading()


func _on_scope_changed(reason: String) -> void:
	_view.set_shown(not scope.scoped)
	var data := weapon()
	var weapon_id := data.id if data != null else &""
	_log(&"weapon.scoped", {"weapon": weapon_id, "scoped": scope.scoped, "reason": reason})
	changed.emit()


func _swing(data: WeaponData) -> void:
	var from := eye.global_transform
	var forward := -from.basis.z.normalized()
	var sphere := SphereShape3D.new()
	sphere.radius = data.sweep_radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = sphere
	params.collision_mask = PhysicsLayers.WEAPON_MASK
	params.exclude = _own_rids()
	params.transform = Transform3D(Basis.IDENTITY, from.origin)
	# The sphere's front reaches max_range from the eye.
	params.motion = forward * maxf(data.max_range - data.sweep_radius, 0.0)
	var space := get_world_3d().direct_space_state
	var fractions := space.cast_motion(params)
	_emit(Stimulus.make_noise(_equipped.stat(&"fire_noise"), from.origin, user))
	_play(_fire_sound(data), _equipped.stat(&"fire_volume_db"))
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
				var hit_stimulus := Stimulus.make_contact(type, data.damage[type], collider, user)
				hit_stimulus.scale_attribute = data.class_attribute("damage_mult")
				_emit(hit_stimulus)
			_emit(Stimulus.make_noise(data.impact_noise, point, user))
			_play_at(data.hit_sound, point)
	_log(&"weapon.swung", {"weapon": data.id, "hit": hit_name})


# Emits `stimulus` with the holder's cause (cause_id) when one is set.
func _emit(stimulus: Stimulus) -> void:
	if cause_id != 0:
		stimulus.cause_id = cause_id
	StimulusSystem.emit(stimulus)


func _own_rids() -> Array[RID]:
	var rids: Array[RID] = []
	if is_instance_valid(user):
		rids.append(user.get_rid())
		rids.append_array(Hitboxes.rids_of(user))
	return rids


func _muzzle() -> Vector3:
	if _view.visible:
		return _view.muzzle_position()
	return eye.global_position


# An attachment was fitted to the equipped weapon: show it.
func _on_attached(_attachment: AttachmentData) -> void:
	_view.show_weapon(_equipped)
	_view.set_shown(not scope.scoped)
	changed.emit()


# `base` through the user's attribute `<class>_<stat>` of the equipped weapon (base itself unarmed or
# without a class).
func _class_value(stat: String, base: float) -> float:
	var data := weapon()
	if data == null or data.attribute_class.is_empty():
		return base
	return Attributes.read(user, data.class_attribute(stat), base)


func _attribute(attribute: StringName, fallback: float) -> float:
	var attributes := user.get_node_or_null(^"Attributes") as Attributes if is_instance_valid(user) else null
	if attributes == null or not attributes.attribute_set.has(attribute):
		return fallback
	return attributes.value(attribute)


## The first-person view: grip pivot, model or box, flash (tests, screenshots: preview_swing()).
func view_pivot() -> WeaponView:
	return _view


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
