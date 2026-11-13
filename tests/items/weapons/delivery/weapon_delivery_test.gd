extends GdUnitTestSuite
## Integration (audit Q7, Q8, Q10): what a fired trigger does is the weapon's delivery, picked from
## its WeaponData kind (one shared instance per kind); a melee swing reads its impact noise through
## the weapon's attachments like a gun; a throw without a Thrower does not cycle the weapon; the
## holder's aimed_hit is a shot's centre ray (the crosshair's target), empty for weapons that shoot
## no rays. A minimal character built from components (no Player) holds the weapons.

const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const HITBOXES := preload("res://actors/common/body/hitboxes.tscn")
const PISTOL: WeaponData = preload("res://items/weapons/pistol/pistol.tres")
const SHOTGUN: WeaponData = preload("res://items/weapons/shotgun/shotgun.tres")
const BATON: WeaponData = preload("res://items/weapons/baton/baton.tres")
const FRAG: WeaponData = preload("res://items/grenades/frag/frag_grenade.tres")
const ORIGIN := Vector3(680, 0, 0)

var _root: Node3D
var _user: CharacterBody3D
var _holder: WeaponHolder


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new()) as Node3D
	add_child(_root)
	var ground := Characters.floor_box(_root)
	ground.position += ORIGIN
	_user = Characters.character(_root, "Wielder", ORIGIN, [] as Array[StringName])
	_user.add_child(HITBOXES.instantiate())
	var eye := Node3D.new()
	eye.name = "Eye"
	eye.position.y = 1.6
	_user.add_child(eye)
	_holder = WeaponHolder.new()
	_holder.aim_config = AimConfig.new()
	_holder.rng_seed = 7
	eye.add_child(_holder)
	_holder.setup(_user, eye)


func after_test() -> void:
	StimulusSystem.clear()


func test_each_kind_has_its_delivery_shared_by_its_weapons() -> void:
	assert_bool(PISTOL.delivery() is RangedFire).is_true()
	assert_object(SHOTGUN.delivery()).is_same(PISTOL.delivery())
	assert_bool(BATON.delivery() is MeleeSweep).is_true()
	assert_bool(FRAG.delivery() is ThrowRelease).is_true()


func test_a_swing_reads_its_impact_noise_through_attachments() -> void:
	var baton := BATON.duplicate() as WeaponData
	baton.attachment_slots = [&"grip"] as Array[StringName]
	var padding := AttachmentData.new()
	padding.slot = &"grip"
	padding.modifiers = [Modifier.create(&"impact_noise", Modifier.Op.MULTIPLY, 0.25)] as Array[Modifier]
	var weapon_state := WeaponState.new(baton)
	assert_bool(weapon_state.attach(padding)).is_true()
	_holder.equip_state(weapon_state)
	# A wall 1.1 m ahead of the eye, inside the baton's reach (1.8 m).
	_wall(ORIGIN + Vector3(0, 1.5, -1.2))
	await _physics(2)
	assert_int(_holder.trigger()).is_equal(WeaponState.Result.FIRED)
	await _physics(2)
	assert_object(_holder.last_hit.get("collider")).is_not_null()
	var noises := _noise_intensities()
	assert_array(noises).contains([BATON.fire_noise, BATON.impact_noise * 0.25])
	assert_array(noises).not_contains([BATON.impact_noise])


func test_a_throw_without_a_thrower_does_not_cycle_the_weapon() -> void:
	var weapon_state := WeaponState.new(FRAG)
	_holder.equip_state(weapon_state)
	assert_int(_holder.trigger()).is_equal(-1)
	assert_float(weapon_state.cooldown).is_equal(0.0)
	assert_array(EventLog.find(&"weapon.thrown")).is_empty()


func test_the_aimed_hit_is_the_centre_ray_of_a_shot() -> void:
	_wall(ORIGIN + Vector3(0, 1.5, -6))
	await _physics(2)
	assert_dict(_holder.aimed_hit).is_empty()
	_holder.equip_state(WeaponState.new(PISTOL))
	var hit := _holder.aimed_hit
	assert_str(String((hit["collider"] as Node).name)).is_equal("Wall")
	# The wall's near face, 5.9 m ahead of the eye (the cone's sway barely tilts the ray).
	assert_float((hit["position"] as Vector3).z).is_equal_approx(ORIGIN.z - 5.9, 0.01)
	_holder.equip_state(WeaponState.new(BATON))
	assert_dict(_holder.aimed_hit).is_empty()


func _wall(centre: Vector3) -> void:
	var wall := StaticBody3D.new()
	wall.name = "Wall"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 3, 0.2)
	shape.shape = box
	wall.add_child(shape)
	_root.add_child(wall)
	wall.global_position = centre


func _noise_intensities() -> Array[float]:
	var result: Array[float] = []
	for entry in EventLog.find(&"stimulus.emitted"):
		if entry.data["type"] == &"noise":
			result.append(float(entry.data["intensity"]))
	return result


func _physics(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
