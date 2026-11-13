extends GdUnitTestSuite
## Measured outcomes of the ADR 0085 weapons, fired by the player through its WeaponHolder at a
## standing target with the guards' body (guard_body.tres: head 40, torso 80, limbs 50, head x2
## ballistic), aimed at the torso centre, over fixed seeds. Targets (brief): shotgun one shot at 5 m
## downs it, 3 or more at 15 m (ADR 0105: since the head hit zone is the model's 0.53 m head, the
## upper pellets of a torso shot hit it; measured 1-3 shots at 15 m, median 2, was 3-6, median 3:
## fewer than half the seeds die to one shot); sniper rifle scoped and still kills with one torso shot at 40 m;
## assault rifle held on the torso at 10 m kills in under 1.2 s. ADR 0105 (head hit zone the size of
## the model's head): the pistol aimed at the head at 10 m, patient (settled) and snapped (fired at
## its cycle from a 3 degree cone). Distances are centre to centre (eye over the feet to the target's
## feet). Each run prints a MEASURED line for the report.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const RANGE := "res://tests/items/weapons/fixtures/weapon_range.tscn"
const SHOTGUN: ItemData = preload("res://items/weapons/shotgun/shotgun_item.tres")
const SNIPER: ItemData = preload("res://items/weapons/sniper_rifle/sniper_rifle_item.tres")
const RIFLE: ItemData = preload("res://items/weapons/assault_rifle/assault_rifle_item.tres")
const PISTOL: ItemData = preload("res://items/weapons/pistol/pistol_item.tres")
const SEEDS: Array[int] = [11, 23, 37, 41, 59, 61, 73, 89]
const FRAME := 1.0 / 60.0

var _driver: PlayerDriver
var _player: Player
var _target: TrainingDummy
var _pulled: int = 0


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


func test_shotgun_rarely_kills_with_one_shot_at_15_m() -> void:
	await _load(SHOTGUN)
	var results: Array[int] = []
	for seed in SEEDS:
		results.append(await _shots_to_kill(15.0, seed, 6))
	print("MEASURED shotgun 15 m shots to kill per seed (7 = alive after 6): ", results)
	assert_int(results.count(1)).override_failure_message("one-shot kills: %s" % [results]).is_less(SEEDS.size() / 2)


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


func test_rifle_master_pulling_the_recoil_kills_at_10_m_in_about_0_6_s() -> void:
	# M13a (ADR 0123): was Untrained without recoil (0.53-0.63 s). Now the Master holds the trigger and
	# pulls the mouse against the learned pattern (the noise is not pulled). Master's 18.2 damage per
	# hit needs 5 torso hits: 0.4 s at 0.1 s a shot when none misses.
	await _load(RIFLE)
	_player.skills.set_tier(&"rifles", 3)
	EventLog.entry_added.connect(_pull_against_recoil)
	var times: Array[float] = []
	for seed in SEEDS:
		await _place_target(10.0)
		await _aim_at_torso()
		_player.weapons.state().magazine = 30
		_player.weapons.seed_rng(seed)
		_pulled = 0
		_driver.runner.simulate_action_press(&"fire")
		var frames := 0
		while not _target.body.is_dead() and frames < 120:
			await _driver.frames(1)
			frames += 1
		_driver.runner.simulate_action_release(&"fire")
		await _driver.frames(30)
		times.append(frames * FRAME)
	EventLog.entry_added.disconnect(_pull_against_recoil)
	times.sort()
	print("MEASURED rifle Master 10 m time to kill pulling the recoil (s, sorted): ", times)
	assert_float(times[SEEDS.size() / 2]).override_failure_message("%s" % [times]).is_between(0.38, 0.75)
	assert_float(times[-1]).override_failure_message("%s" % [times]).is_less(1.2)


func test_pistol_at_the_head_at_10_m() -> void:
	await _load(PISTOL)
	var patient: Array[int] = []
	var snapped: Array[float] = []
	for seed in SEEDS:
		await _place_target(10.0)
		await _aim_at(&"head")
		_player.weapons.seed_rng(seed)
		patient.append(await _fire_until_dead(3))
		await _place_target(10.0)
		await _aim_at(&"head")
		_player.weapons.seed_rng(seed)
		# Snapped onto the head: a 3 degree cone, then a shot every cycle without settling.
		_player.weapons.aim.spread = 3.0
		var state := _player.weapons.state()
		var frames := 0
		while not _target.body.is_dead() and frames < 240:
			state.magazine = state.data.magazine_size
			_player.weapons.trigger()
			await _driver.frames(1)
			frames += 1
		snapped.append(frames * FRAME)
		# The last shot's cycle runs out before the next seed's patient shot.
		await _driver.frames(ceili(state.data.cycle_time / FRAME) * 2)
	print("MEASURED pistol 10 m at the head: patient shots to kill ", patient, ", snapped time to kill (s) ", snapped)
	# Patient: one or two head hits (the untrained pistol's head hit is just short of 40 on most
	# seeds). Snapped: most seeds kill within 2 s (with the old 0.14 m head sphere one of eight did,
	# five survived 4 s).
	for i in SEEDS.size():
		assert_int(patient[i]).override_failure_message("seed %d: %s" % [SEEDS[i], patient]).is_less_equal(2)
	var quick := snapped.filter(func(time: float) -> bool: return time < 2.0).size()
	assert_int(quick).override_failure_message("snapped: %s" % [snapped]).is_greater_equal(5)


# The player pulls the mouse against each shot's pattern step (at the skill's size) as it fires.
func _pull_against_recoil(entry: EventLogEntry) -> void:
	if entry.kind != &"weapon.fired":
		return
	var data := _player.weapons.weapon()
	var size := Attributes.read(_player, data.class_attribute("recoil_size_mult"), 1.0)
	var step := data.recoil.pattern_step(_pulled) * data.recoil.pattern_scale * size
	_pulled += 1
	_player.look(Vector2(-step.x, step.y) / rad_to_deg(_player.config.mouse_sensitivity))


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
	await _aim_at(&"torso")


# Stands the player at the origin looking at the centre of the target's `part` hitbox; the cone
# settled.
func _aim_at(part: StringName) -> void:
	var point := _target.hitboxes.box(part).global_position
	_player.load_state(Objects.aiming_state(_player, Vector3.ZERO, point))
	await _driver.frames(5)
	_player.weapons.settle()


func _load(item: ItemData) -> void:
	_driver = PlayerDriver.new(scene_runner(RANGE))
	_player = _driver.player
	_target = _driver.runner.find_child("Target") as TrainingDummy
	await _driver.settle()
	var inventory := _player.inventory
	inventory.add(item, 1)
	inventory.add(inventory.catalog.find(item.weapon.ammo_item), 60)
	inventory.select_slot(0)
	await _driver.frames(2)
