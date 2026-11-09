class_name WeaponView
extends Node3D
## First-person view of a WeaponHolder's equipped weapon (ADR 0085), the holder's child "ViewPivot":
## this node is the grip pivot that recoil and melee swings turn (WeaponData.view_offset,
## view_rest_deg, view_swing_deg, view_chop_share). Under it hangs the weapon's model scene
## (WeaponData.view_scene: a WeaponModel showing the fitted attachments) or, for weapons without one,
## a placeholder box ("ViewModel", WeaponData.view_size and view_color), both at view_box_offset. The
## MuzzleFlash sits at the model's muzzle or the box's front. While the user is cloaked the view is
## translucent. Visual only: shots, sweeps and timings live in the holder.
## In a character's hand (`in_hand`, hang_from(), ADR 0103) the pivot sits at its
## mount instead of the camera offset, the arm's animation carries the swing (only the recoil stays)
## (it casts no shadow, like the animated arm holding it).

## Recoil time of a shot; a swing animates over half its cycle.
const KICK_TIME: float = 0.12
## Opacity while the user is cloaked.
const CLOAKED_ALPHA: float = 0.3

## Screen shift of the grip pivot, degrees (x: right, y: down; WeaponHolder.view_shift_deg): the
## pivot moves sideways and down by its depth x tan(angle), so every weapon moves by the same angle
## on screen whatever its distance from the eye. Zero: the pose of the weapon's data.
var shift_deg := Vector2.ZERO:
	set(value):
		shift_deg = value
		_animate()
## The muzzle flash (MuzzleFlash.hold() freezes it for screenshots).
var flash: MuzzleFlash
## The weapon shown, or null.
var data: WeaponData
## Its model, or null (the box, or nothing shown).
var model: WeaponModel

## Held in a character's hand (third person) rather than in front of a camera.
var in_hand: bool = false

var _box: MeshInstance3D
# The holder this view belongs to (its parent before it hung from a hand).
var _home: Node
var _box_material: StandardMaterial3D
var _cloaked: bool = false
var _kick: float = 0.0
var _kick_length: float = KICK_TIME


func _init() -> void:
	name = "ViewPivot"
	visible = false
	_box = MeshInstance3D.new()
	_box.name = "ViewModel"
	_box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_box)
	flash = MuzzleFlash.new()
	flash.name = "MuzzleFlash"
	_box.add_child(flash)


## Shows the weapon of `weapon_state` (its model with the fitted attachments, or the box).
func show_weapon(weapon_state: WeaponState) -> void:
	data = weapon_state.data
	if flash.get_parent() != _box:
		flash.reparent(_box, false)
	if model != null:
		model.free()
		model = null
	_box_material = null
	_cloaked = false
	if data.view_scene != null:
		model = data.view_scene.instantiate() as WeaponModel
		model.name = "Model"
		model.position = data.view_box_offset
		add_child(model)
		model.fit(weapon_state.attachments)
		for geometry in model.geometry():
			geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_box.mesh = null
		flash.reparent(model.muzzle_point(), false)
		flash.front = 0.0
	else:
		var mesh := BoxMesh.new()
		mesh.size = data.view_size
		_box_material = StandardMaterial3D.new()
		_box_material.albedo_color = data.view_color
		_box_material.roughness = 0.6
		mesh.material = _box_material
		_box.mesh = mesh
		_box.position = data.view_box_offset
		flash.front = -1.0
	flash.transform = Transform3D.IDENTITY
	flash.clear()
	visible = true
	_animate()


## Hangs the view from `mount` (a character's hand: the grip pivot sits there and the model's
## animation moves it), or back under its holder in first person when null. Visual
## only: shots still leave the holder's eye.
func hang_from(mount: Node3D) -> void:
	if _home == null:
		_home = get_parent()
	var parent: Node = mount if mount != null else _home
	if get_parent() != parent:
		reparent(parent, false)
	in_hand = mount != null
	_animate()


## Nothing in hand.
func hide_weapon() -> void:
	data = null
	visible = false
	flash.clear()


## Shown (a weapon drawn) or hidden while it is (the scope view).
func set_shown(shown: bool) -> void:
	visible = shown and data != null


## Starts the recoil (ranged) or the swing over half the cycle (melee).
func kick() -> void:
	_kick_length = data.cycle_time * 0.5 if data.is_melee() else KICK_TIME
	_kick = _kick_length


## Every physics tick: the kick runs down, the pose follows, the flash fades, cloaking applies.
func step(delta: float, cloaked: bool) -> void:
	_kick = maxf(_kick - delta, 0.0)
	_animate()
	_set_cloaked(cloaked)
	flash.step(delta)


## Shows the swing frozen at `progress` (0 = start, 1 = end); screenshots and tests. The next step
## carries on from the real kick timer.
func preview_swing(progress: float) -> void:
	_kick = _kick_length * (1.0 - clampf(progress, 0.0, 1.0))
	_animate()


## Where shots leave the weapon: the model's muzzle (a fitted silencer's end), else the box.
func muzzle_position() -> Vector3:
	if model != null:
		return model.muzzle_point().global_position
	return _box.global_position


## Opacity now (CLOAKED_ALPHA while the user is cloaked).
func alpha() -> float:
	return CLOAKED_ALPHA if _cloaked else 1.0


func _set_cloaked(cloaked: bool) -> void:
	if data == null or cloaked == _cloaked:
		return
	_cloaked = cloaked
	if _box_material != null:
		_box_material.transparency = (
			BaseMaterial3D.TRANSPARENCY_ALPHA if cloaked else BaseMaterial3D.TRANSPARENCY_DISABLED
		)
		_box_material.albedo_color.a = CLOAKED_ALPHA if cloaked else 1.0
	if model != null:
		for geometry in model.geometry():
			geometry.transparency = 1.0 - CLOAKED_ALPHA if cloaked else 0.0


# Recoil (ranged) or a chop about the grip (melee) while the kick timer runs. In a hand the pivot
# rests at the mount and only the recoil moves it (the arm swings a melee weapon).
func _animate() -> void:
	if data == null:
		return
	var t := _kick / _kick_length if _kick_length > 0.0 else 0.0
	if in_hand:
		var held := Transform3D.IDENTITY
		if not data.is_melee():
			held.basis = Basis(Vector3.RIGHT, 0.25 * t)
			held.origin = Vector3(0, 0, 0.04 * t)
		transform = held
		return
	var pose := Transform3D(_euler_deg(data.view_rest_deg), rest_position(data.view_offset, shift_deg))
	if data.is_melee():
		# Fast chop to the bottom of the swing, slower return to the ready pose.
		var progress := 1.0 - t
		var chop := data.view_chop_share
		var amount := 0.0
		if t > 0.0:
			if progress < chop:
				amount = sin(progress / chop * PI * 0.5)
			else:
				amount = cos((progress - chop) / (1.0 - chop) * PI * 0.5)
		pose.basis = _euler_deg(data.view_rest_deg + data.view_swing_deg * amount)
	else:
		pose.basis = Basis(Vector3.RIGHT, 0.25 * t) * pose.basis
		pose.origin += Vector3(0, 0, 0.04 * t)
	transform = pose


## The grip pivot of a weapon whose data puts it at `offset` (camera frame, -Z ahead), moved on
## screen by `shift` degrees (x right, y down): sideways and down by its depth x tan(angle).
static func rest_position(offset: Vector3, shift: Vector2) -> Vector3:
	var depth := absf(offset.z)
	return offset + Vector3(depth * tan(deg_to_rad(shift.x)), -depth * tan(deg_to_rad(shift.y)), 0.0)


# Pitch (about X), then yaw (Y), then roll (Z) in the camera's frame, degrees.
static func _euler_deg(angles: Vector3) -> Basis:
	return (
		Basis(Vector3.BACK, deg_to_rad(angles.z))
		* Basis(Vector3.UP, deg_to_rad(angles.y))
		* Basis(Vector3.RIGHT, deg_to_rad(angles.x))
	)
