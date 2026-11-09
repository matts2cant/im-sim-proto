extends GdUnitTestSuite
## Measured outcomes of the ADR 0085 weapons, fired by the player through its WeaponHolder at a
## standing target with the guards' body (guard_body.tres: head 40, torso 80, limbs 50, head x2
## ballistic), aimed at the torso centre, over fixed seeds. Targets (brief): shotgun one shot at 5 m
## downs it, 3 or more at 15 m; sniper rifle scoped and still kills with one torso shot at 40 m;
## assault rifle held on the torso at 10 m kills in under 1.2 s. Distances are centre to centre
## (eye over the feet to the target's feet). Each run prints a MEASURED line for the report.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const RANGE := "res://tests/items/weapons/fixtures/weapon_range.tscn"
const SHOTGUN: ItemData = preload("res://items/weapons/shotgun/shotgun_item.tres")
const SNIPER: ItemData = preload("res://items/weapons/sniper_rifle/sniper_rifle_item.tres")
const RIFLE: ItemData = preload("res://items/weapons/assault_rifle/assault_rifle_item.tres")
const SEEDS: Array[int] = [11, 23, 37, 41, 59, 61, 73, 89]
const FRAME := 1.0 / 60.0

var _driver: PlayerDriver
var _player: Player
var _target: TrainingDummy


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_target_has_the_guard_body() -> void:
	await _load(SHOTGUN)
	var guard_body: BodyProfile = load("res://actors/guard/guard_body.tres")
	assert_object(_target.body.profile).is_same(guard_body)
	assert_float(_target.body.health(&"torso")).is_equal(80.0)


func test_shotgun_one_torso_shot_at_5_m_downs_a_guard() -> void:
	await _load(SHOTGUN)
	var results: Array[int] = []
	for seed in SEEDS:
		results.append(await _shots_to_kill(5.0, seed, 1))
	print("MEASURED shotgun 5 m shots to kill per seed: ", results)
	for i in SEEDS.size():
		assert_int(results[i]).override_failure_message("seed %d: %s" % [SEEDS[i], results]).is_equal(1)


func test_shotgun_takes_three_or_more_shots_at_15_m() -> void:
	await _load(SHOTGUN)
	var results: Array[int] = []
	for seed in SEEDS:
		results.append(await _shots_to_kill(15.0, seed, 6))
	print("MEASURED shotgun 15 m shots to kill per seed (7 = alive after 6): ", results)
	for i in SEEDS.size():
		assert_int(results[i]).override_failure_message("seed %d: %s" % [SEEDS[i], results]).is_greater_equal(3)


func test_sniper_scoped_and_still_kills_with_one_torso_shot_at_40_m() -> void:
	await _load(SNIPER)
	var results: Array[int] = []
	var settle_frames := 0
	for seed in SEEDS:
		await _place_target(40.0)
		await _aim_at_torso()
		await _driver.hold(&"alt_fire", 2)
		assert_bool(_player.weapons.scope.scoped).is_true()
		# Still: the scoped cone settles from the hip's 6 degrees to its 0.2 floor.
		var waited := 0
		while _player.weapons.aim.spread > 0.25 and waited < 240:
			await _driver.frames(1)
			waited += 1
		settle_frames = maxi(settle_frames, waited)
		_player.weapons.seed_rng(seed)
		results.append(await _fire_until_dead(1))
		await _driver.hold(&"alt_fire", 2)
	print(
		"MEASURED sniper 40 m scoped shots to kill: ", results, " settle to 0.25 deg: %.2f s" % (settle_frames * FRAME)
	)
	for i in SEEDS.size():
		assert_int(results[i]).override_failure_message("seed %d: %s" % [SEEDS[i], results]).is_equal(1)
	# Scoping in and holding still is a short wait, not a long one.
	assert_float(settle_frames * FRAME).is_less(2.0)


func test_rifle_held_on_the_torso_at_10_m_kills_in_under_1_2_s() -> void:
	await _load(RIFLE)
	var times: Array[float] = []
	for seed in SEEDS:
		await _place_target(10.0)
		await _aim_at_torso()
		_player.weapons.state().magazine = 30
		_player.weapons.seed_rng(seed)
		_driver.runner.simulate_action_press(&"fire")
		var frames := 0
		while not _target.body.is_dead() and frames < 120:
			await _driver.frames(1)
			frames += 1
		_driver.runner.simulate_action_release(&"fire")
		await _driver.frames(8)
		times.append(frames * FRAME)
	print("MEASURED rifle 10 m time to kill (s): ", times)
	for i in SEEDS.size():
		assert_float(times[i]).override_failure_message("seed %d: %s" % [SEEDS[i], times]).is_less(1.2)


# Shots of the drawn weapon (cone settled before each, as a patient shooter) until the target at
# `distance` m dies; `max_shots` + 1 when it survives them all.
func _shots_to_kill(distance: float, seed: int, max_shots: int) -> int:
	await _place_target(distance)
	await _aim_at_torso()
	_player.weapons.seed_rng(seed)
	return await _fire_until_dead(max_shots)


func _fire_until_dead(max_shots: int) -> int:
	var state := _player.weapons.state()
	var cycle := ceili(state.data.cycle_time / FRAME) + 2
	for i in max_shots:
		state.magazine = state.data.magazine_size
		_player.weapons.settle()
		assert_int(_player.weapons.trigger()).is_equal(WeaponState.Result.FIRED)
		await _driver.frames(cycle)
		if _target.body.is_dead():
			return i + 1
	return max_shots + 1


func _place_target(distance: float) -> void:
	_target.reset()
	_target.position = Vector3(0, 0, -distance)
	await _driver.frames(3)


# Stands the player at the origin looking at the target's torso hitbox centre; the cone settled.
func _aim_at_torso() -> void:
	var torso := _target.hitboxes.box(&"torso").global_position
	_player.load_state(Objects.aiming_state(_player, Vector3.ZERO, torso))
	await _driver.frames(5)
	_player.weapons.settle()


func _load(item: ItemData) -> void:
	_driver = PlayerDriver.new(scene_runner(RANGE))
	_player = _driver.player
	_target = _driver.runner.find_child("Target") as TrainingDummy
	await _driver.settle()
	var inventory := _player.inventory
	inventory.give(item, 1)
	inventory.give(inventory.catalog.find(item.weapon.ammo_item), 60)
	inventory.select_slot(0)
	await _driver.frames(2)
