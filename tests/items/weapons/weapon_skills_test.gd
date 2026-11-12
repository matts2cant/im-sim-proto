extends GdUnitTestSuite
## Integration: skills on the player's weapons and medkit through attributes (ADR 0061): Pistols
## (cone floor, settle, reload, damage; stacks with an arm injury), crouched settling, Low-Tech
## knockouts, Medicine heals. Combat Strength is off by default (M4 baton numbers); on (F5) it stacks.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Weapons := preload("res://tests/items/weapons/weapon_test_helpers.gd")
const Items := preload("res://tests/items/item_test_helpers.gd")
const ROOM := "res://tests/objects/fixtures/carry_room.tscn"
const WALL_POINT := Vector3(0, 1.5, -5.8)
## Untrained standing floor of the pistol (pistol_aim.tres base_min_deg); Master's still cone is 0
## (pistol_still_mult, ADR 0123).
const BASE_FLOOR := 2.0

var _driver: PlayerDriver
var _weapons: Weapons
var _player: Player


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_pistols_master_still_cone_settles_to_zero() -> void:
	await _load(ROOM)
	await _weapons.equip(1)
	_player.skills.set_tier(&"pistols", 3)
	await _weapons.aim_at(Vector3.ZERO, WALL_POINT)
	# From the Untrained floor of 2 degrees with Master's 0.2 s settle: below the 0.005 snap in 1.2 s.
	await _driver.frames(90)

	assert_float(_player.weapons.aim.spread).is_equal(0.0)


func test_pistols_master_settle_time_is_0_2_seconds() -> void:
	await _load(ROOM)
	await _weapons.equip(1)
	await _weapons.aim_at(Vector3.ZERO, WALL_POINT)
	var untrained := await _excess_after(12)
	_player.skills.set_tier(&"pistols", 3)
	await _driver.frames(5)
	var master := await _excess_after(12)

	# 0.2 s after a 5 degree bloom: 5 x exp(-0.2 / 0.8) = 3.9 untrained, 5 x exp(-1) = 1.84 at Master.
	assert_float(untrained).is_between(3.6, 4.1)
	assert_float(master).is_between(1.5, 2.2)


func test_crouching_settles_faster_and_stacks_with_pistols_master() -> void:
	await _load(ROOM)
	await _weapons.equip(1)
	await _weapons.aim_at(Vector3.ZERO, WALL_POINT)
	var standing := await _frames_to_settle()
	_driver.runner.simulate_action_press(&"crouch")
	await _driver.frames(20)
	var crouched := await _frames_to_settle()
	_player.skills.set_tier(&"pistols", 3)
	await _driver.frames(2)
	var master_crouched := await _frames_to_settle()
	_driver.runner.simulate_action_release(&"crouch")

	# ln(50) x settle: standing 0.8 s -> ~188 frames, crouched 0.48 s -> ~113, Master crouched
	# 0.12 s -> ~28.
	assert_int(standing).is_between(175, 200)
	assert_int(crouched).is_between(100, 125)
	assert_int(master_crouched).is_between(22, 35)


func test_arm_injury_still_widens_the_master_cone() -> void:
	await _load(ROOM)
	await _weapons.equip(1)
	_player.skills.set_tier(&"pistols", 3)
	_player.body.take_damage(&"damage.ballistic", 70.0, &"arm_l")
	await _weapons.aim_at(Vector3.ZERO, WALL_POINT)
	await _driver.frames(30)

	assert_float(_player.weapons.aim.spread).is_equal_approx(3.0, 0.001)


func test_pistols_master_reloads_in_half_the_time() -> void:
	await _load(ROOM)
	await _weapons.equip(1)
	_player.weapons.state().magazine = 4
	_player.skills.set_tier(&"pistols", 3)

	await _driver.hold(&"reload", 2)

	var started := EventLog.find(&"weapon.reload_started")
	assert_array(started).has_size(1)
	assert_float(started[0].data["time"]).is_equal_approx(0.8, 0.001)
	await _driver.frames(54)
	assert_int(_player.weapons.state().magazine).is_equal(10)


func test_pistols_master_shot_deals_1_3_times_damage() -> void:
	await _load(Weapons.DUMMY_RANGE)
	var dummy := _driver.runner.find_child("TrainingDummy") as TrainingDummy
	await _weapons.equip(1)
	_player.skills.set_tier(&"pistols", 3)
	await _weapons.aim_at(Vector3.ZERO, Weapons.part_position(dummy, &"torso"))

	await _weapons.fire()

	var damaged := Weapons.damaged(&"torso")
	assert_array(damaged).has_size(1)
	assert_float(damaged[0].data["amount"]).is_equal_approx(32.5, 0.001)


func test_low_tech_advanced_knocks_out_from_the_front_in_two_hits() -> void:
	await _load(Weapons.DUMMY_RANGE)
	var dummy := _driver.runner.find_child("TrainingDummy") as TrainingDummy
	await _weapons.equip(2)
	_player.skills.set_tier(&"low_tech", 2)
	await _weapons.aim_at(Vector3(0, 0, -1.7), Weapons.part_position(dummy, &"torso"))

	await _weapons.fire(40)
	assert_bool(dummy.body.is_unconscious()).is_false()
	await _weapons.fire(4)

	assert_float(dummy.body.stun).is_equal_approx(60.0, 0.001)
	assert_bool(dummy.body.is_unconscious()).is_true()


func test_combat_strength_on_f6_knocks_out_from_the_front_in_two_hits() -> void:
	await _load(Weapons.DUMMY_RANGE)
	var dummy := _driver.runner.find_child("TrainingDummy") as TrainingDummy
	await _weapons.equip(2)
	await _driver.hold(&"aug_5", 2)
	assert_bool(_player.augmentations.is_active(&"combat_strength")).is_true()
	await _weapons.aim_at(Vector3(0, 0, -1.7), Weapons.part_position(dummy, &"torso"))

	await _weapons.fire(40)
	assert_float(dummy.body.stun).is_equal_approx(30.0, 0.001)
	assert_bool(dummy.body.is_unconscious()).is_false()
	await _weapons.fire(4)

	assert_bool(dummy.body.is_unconscious()).is_true()


func test_low_tech_master_swings_faster() -> void:
	await _load(ROOM)
	await _weapons.equip(2)
	_player.skills.set_tier(&"low_tech", 3)

	await _weapons.fire()

	assert_float(_player.weapons.state().cooldown).is_less(0.6 * 0.7)
	assert_float(_player.weapons.state().cooldown).is_greater(0.6 * 0.7 - 0.15)


func test_medicine_master_medkit_heals_90() -> void:
	await _load(ROOM)
	_player.skills.set_tier(&"medicine", 3)
	_player.body.take_damage(&"damage.ballistic", 50.0, &"leg_l")
	_player.body.take_damage(&"damage.ballistic", 50.0, &"leg_r")
	_player.inventory.give(Items.MEDKIT, 1)
	EventLog.clear()

	assert_bool(_player.inventory.use_stack(_player.inventory.inventory.stacks_of(&"medkit")[0])).is_true()

	var healed := EventLog.find(&"actor.healed")
	assert_array(healed).has_size(1)
	assert_float(healed[0].data["amount"]).is_equal_approx(90.0, 0.001)


# Blooms the cone 5 degrees over its settled floor and returns the excess after `frames` frames.
func _excess_after(frames: int) -> float:
	_player.weapons.settle()
	var floor_deg := _player.weapons.aim.spread
	_player.weapons.aim.spread = floor_deg + 5.0
	await _driver.frames(frames)
	return _player.weapons.aim.spread - floor_deg


# Frames until a 5 degree bloom over the settled floor is back within 0.1 degree of it.
func _frames_to_settle() -> int:
	_player.weapons.settle()
	var floor_deg := _player.weapons.aim.spread
	_player.weapons.aim.spread = floor_deg + 5.0
	for frame in 400:
		await _driver.frames(1)
		if _player.weapons.aim.spread <= floor_deg + 0.1:
			return frame + 1
	return 400


func _load(scene: String) -> void:
	_driver = PlayerDriver.new(scene_runner(scene))
	_weapons = Weapons.new(_driver)
	_player = _driver.player
	await _driver.settle()
	await _driver.place(Vector3.ZERO)
