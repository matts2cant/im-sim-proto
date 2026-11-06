extends GdUnitTestSuite
## Integration: the player's WeaponHolder (belt equip, shots and their stimuli, impulse, barrels,
## ammo, dry fire, reload, injured arms, baton swings).

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Weapons := preload("res://tests/items/weapons/weapon_test_helpers.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const ROOM := "res://tests/objects/fixtures/carry_room.tscn"
## The room's wall face is at z = -5.8.
const WALL_POINT := Vector3(0, 1.5, -5.8)

var _driver: PlayerDriver
var _weapons: Weapons
var _player: Player


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_belt_keys_equip_and_holster() -> void:
	await _load()

	await _weapons.equip(1)
	assert_str(_player.weapons.weapon().id).is_equal("pistol")
	await _weapons.equip(2)
	assert_str(_player.weapons.weapon().id).is_equal("baton")
	await _weapons.equip(2)
	assert_bool(_player.weapons.is_armed()).is_false()
	assert_array(EventLog.find(&"weapon.equipped")).has_size(2)
	assert_array(EventLog.find(&"weapon.holstered")).has_size(1)


func test_holstered_fire_does_nothing() -> void:
	await _load()
	await _weapons.aim_at(Vector3.ZERO, WALL_POINT)

	await _weapons.fire()

	assert_array(EventLog.find(&"weapon.fired")).is_empty()
	assert_array(EventLog.find(&"stimulus.emitted")).is_empty()


func test_shot_emits_ray_muzzle_noise_and_impact_noise() -> void:
	await _load()
	await _weapons.equip(1)
	await _weapons.aim_at(Vector3.ZERO, WALL_POINT)

	await _weapons.fire()

	var emitted := EventLog.find(&"stimulus.emitted")
	var rays := emitted.filter(func(entry: EventLogEntry) -> bool: return entry.data["shape"] == "ray")
	assert_array(rays).has_size(1)
	assert_str(rays[0].data["type"]).is_equal("damage.ballistic")
	assert_float(rays[0].data["intensity"]).is_equal(25.0)
	var noises := emitted.filter(func(entry: EventLogEntry) -> bool: return entry.data["type"] == &"noise")
	(
		assert_array(noises.map(func(entry: EventLogEntry) -> float: return entry.data["intensity"]))
		. contains_exactly([6.0, 4.0])
	)
	var impact: Vector3 = noises[1].data["origin"]
	assert_float(impact.z).is_equal_approx(-5.8, 0.01)
	assert_float(impact.distance_to(WALL_POINT)).is_less(0.3)
	var muzzle: Vector3 = noises[0].data["origin"]
	assert_float(muzzle.distance_to(_player.eye_transform().origin)).is_less(0.6)
	var fired := EventLog.find(&"weapon.fired")
	assert_array(fired).has_size(1)
	assert_int(fired[0].data["magazine"]).is_equal(9)


func test_shots_land_inside_the_cone() -> void:
	await _load()
	await _weapons.equip(1)
	await _weapons.aim_at(Vector3.ZERO, WALL_POINT)
	var eye := _player.eye_transform()

	for shot in 4:
		await _weapons.fire(25)
		var fired := EventLog.find(&"weapon.fired")
		var spread: float = fired[fired.size() - 1].data["spread"]
		var point: Vector3 = _player.weapons.last_hit["position"]
		var sway := _player.weapons.aim.config.sway_deg
		assert_float(AimModel.angle_off(eye.basis, (point - eye.origin).normalized())).is_less_equal(spread + sway)
	# Each shot blooms the cone: the later shots were taken with a wider spread.
	var spreads := EventLog.find(&"weapon.fired").map(func(entry: EventLogEntry) -> float: return entry.data["spread"])
	assert_float(spreads[1]).is_greater(spreads[0])


func test_shot_pushes_a_physics_object() -> void:
	await _load()
	var medkit := Objects.spawn(_driver.runner.scene(), "res://items/medkit/medkit.tscn", Vector3(0, 0.06, -3))
	await _driver.frames(30)
	var start := medkit.global_position
	await _weapons.equip(1)
	await _weapons.aim_at(Vector3.ZERO, start)

	await _weapons.fire(20)

	# 3 N s on 1 kg, partly into the floor: it slides away from the shooter.
	assert_str(EventLog.find(&"weapon.fired")[0].data["hit"]).is_equal("Medkit")
	assert_float(medkit.global_position.z - start.z).is_less(-0.03)


func test_shooting_a_barrel_explodes_it() -> void:
	await _load()
	var barrel := Objects.spawn(_driver.runner.scene(), Objects.EXPLOSIVE_BARREL, Vector3(0, 0.45, -5))
	await _driver.frames(20)
	await _weapons.equip(1)
	await _weapons.aim_at(Vector3.ZERO, barrel.global_position)

	await _weapons.fire()

	assert_array(Objects.logged(&"object.exploded", "object", "ExplosiveBarrel")).has_size(1)
	assert_array(Objects.logged(&"object.damaged", "type", &"damage.ballistic")).has_size(1)


func test_fire_rate_limits_shots() -> void:
	await _load()
	await _weapons.equip(1)
	await _weapons.aim_at(Vector3.ZERO, WALL_POINT)

	await _weapons.fire(2)
	await _weapons.fire(2)
	assert_array(EventLog.find(&"weapon.fired")).has_size(1)
	await _driver.frames(20)
	await _weapons.fire(2)
	assert_array(EventLog.find(&"weapon.fired")).has_size(2)


func test_dry_fire_and_reload() -> void:
	await _load()
	await _weapons.equip(1)
	await _weapons.aim_at(Vector3.ZERO, WALL_POINT)
	_player.weapons.state().magazine = 1

	await _weapons.fire(25)
	await _weapons.fire(25)
	assert_array(EventLog.find(&"weapon.fired")).has_size(1)
	assert_array(EventLog.find(&"weapon.dry_fire")).has_size(1)

	await _driver.hold(&"reload", 2)
	assert_bool(_player.weapons.state().is_reloading()).is_true()
	await _driver.frames(90)
	assert_int(_player.weapons.state().magazine).is_equal(0)
	await _driver.frames(10)
	assert_int(_player.weapons.state().magazine).is_equal(10)
	assert_int(_player.weapons.state().reserve).is_equal(20)
	assert_array(EventLog.find(&"weapon.reloaded")).has_size(1)


func test_one_disabled_arm_widens_the_cone() -> void:
	await _load()
	await _weapons.equip(1)
	await _weapons.aim_at(Vector3.ZERO, WALL_POINT)

	_player.body.take_damage(&"damage.blunt", 100.0, &"arm_r")
	await _driver.frames(2)

	assert_float(_player.attributes.value(&"aim_spread_add")).is_equal(3.0)
	assert_float(_player.attributes.value(&"aim_sway_mult")).is_equal(2.0)
	assert_float(_player.weapons.aim.spread).is_equal_approx(4.5, 0.001)


func test_jumping_widens_the_cone_after_the_grace_time() -> void:
	await _load()
	await _weapons.equip(1)
	await _weapons.aim_at(Vector3.ZERO, WALL_POINT)

	_driver.runner.simulate_action_press(&"jump")
	await _driver.frames(4)
	assert_int(_player.aim_stance()).is_equal(AimModel.Stance.STILL)
	await _driver.frames(6)
	_driver.runner.simulate_action_release(&"jump")

	assert_int(_player.aim_stance()).is_equal(AimModel.Stance.AIR)
	assert_float(_player.weapons.aim.spread).is_equal_approx(7.5, 0.001)


func test_both_arms_disabled_cannot_fire() -> void:
	await _load()
	await _weapons.equip(1)
	await _weapons.aim_at(Vector3.ZERO, WALL_POINT)
	_player.body.take_damage(&"damage.blunt", 100.0, &"arm_l")
	_player.body.take_damage(&"damage.blunt", 100.0, &"arm_r")

	await _weapons.fire()

	assert_array(EventLog.find(&"weapon.fired")).is_empty()
	var refused := EventLog.find(&"weapon.refused")
	assert_array(refused).has_size(1)
	assert_str(refused[0].data["reason"]).is_equal("arms_disabled")


func test_baton_swing_and_hit_noises() -> void:
	await _load()
	await _weapons.equip(2)
	await _weapons.aim_at(Vector3(0, 0, -4.5), WALL_POINT)

	await _weapons.fire()

	var noises := EventLog.find(&"stimulus.emitted").filter(
		func(entry: EventLogEntry) -> bool: return entry.data["type"] == &"noise"
	)
	(
		assert_array(noises.map(func(entry: EventLogEntry) -> float: return entry.data["intensity"]))
		. contains_exactly([3.0, 6.0])
	)
	assert_array(EventLog.find(&"weapon.swung")).has_size(1)


func test_baton_misses_beyond_reach() -> void:
	await _load()
	await _weapons.equip(2)
	await _weapons.aim_at(Vector3(0, 0, -3.5), Vector3(0, 1.65, -5.8))

	await _weapons.fire()

	var swung := EventLog.find(&"weapon.swung")
	assert_str(swung[0].data["hit"]).is_equal("")
	var contacts := EventLog.find(&"stimulus.emitted").filter(
		func(entry: EventLogEntry) -> bool: return entry.data["shape"] == "contact"
	)
	assert_array(contacts).is_empty()


func test_baton_stun_does_not_hurt_objects() -> void:
	await _load()
	var crate := Objects.spawn(_driver.runner.scene(), Objects.SMALL_CRATE, Vector3(0, 0.3, -1.4))
	await _driver.frames(20)
	await _weapons.equip(2)
	await _weapons.aim_at(Vector3.ZERO, crate.global_position)

	await _weapons.fire()

	# Blunt 5 hurts the wooden crate; stun 20 does nothing to objects (stun x0 on every material).
	assert_float(Breakable.of(crate).health()).is_equal_approx(25.0, 0.001)


func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(ROOM))
	_weapons = Weapons.new(_driver)
	_player = _driver.player
	await _driver.settle()
