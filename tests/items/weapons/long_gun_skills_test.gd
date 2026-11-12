extends GdUnitTestSuite
## Measured outcomes of the Rifles and Sniper skills (ADR 0101), Untrained vs Master, fired by the
## player through its WeaponHolder in a small range (tests/items/weapons/fixtures/skill_range.tscn):
## a 0.5 x 0.5 m plate and a 12 x 8 m wall, each moved in front of the player (or out of reach) per
## test. Distances are centre to centre, from the player's feet (eye straight above, 1.65 m) to the
## plate or wall centre at eye height. Each test prints a MEASURED line for the report.
## - Assault rifle: the group of a full 30-round magazine held on the wall at 15 m, the recoil pattern
##   pulled against with the mouse (M13a, ADR 0123) (mean distance of
##   the hits from their centre).
## - Sniper rifle: scoped and still, the time for the cone to settle from the hip floor to 0.25
##   degrees and to its own floor.
## - Shotgun: pellets on the plate at 10 m over 8 seeds.
## Also: reload time and damage scale of the three weapons at Master.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const RANGE := "res://tests/items/weapons/fixtures/skill_range.tscn"
const SHOTGUN: ItemData = preload("res://items/weapons/shotgun/shotgun_item.tres")
const SNIPER: ItemData = preload("res://items/weapons/sniper_rifle/sniper_rifle_item.tres")
const RIFLE: ItemData = preload("res://items/weapons/assault_rifle/assault_rifle_item.tres")
const SEEDS: Array[int] = [11, 23, 37, 41, 59, 61, 73, 89]
const FRAME := 1.0 / 60.0
const EYE := 1.65
## Out of every weapon's reach (the sniper rifle's 150 m included).
const FAR := Vector3(0, EYE, -400)

var _driver: PlayerDriver
var _player: Player
var _plate: StaticBody3D
var _wall: StaticBody3D
var _hits: Array[Vector3] = []
var _fired: int = 0


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	_hits.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if EventLog.entry_added.is_connected(_on_entry):
		EventLog.entry_added.disconnect(_on_entry)


func test_rifles_master_tightens_the_assault_rifle_group_at_15_m() -> void:
	await _load(RIFLE)
	_plate.position = FAR
	_wall.position = Vector3(0, EYE, -15)
	var untrained := await _group_radius(SEEDS[0])
	_player.skills.set_tier(&"rifles", 3)
	var master := await _group_radius(SEEDS[0])
	print(
		(
			"MEASURED assault rifle 30-round group at 15 m, mean radius (m): untrained %.3f, master %.3f"
			% [untrained, master]
		)
	)

	# M13a (ADR 0123), recoil pulled against: Untrained blooms 1.4 per shot to the 5 degree cap (a
	# 1.3 m cone at 15 m, mean radius about 2/3 of it) plus twice the recoil noise; Master 0.56 per
	# shot settling near 2.5 degrees, half the noise.
	assert_float(untrained).is_between(0.6, 1.3)
	assert_float(master).is_less(untrained * 0.7)


func test_sniper_master_settles_the_scope_faster() -> void:
	await _load(SNIPER)
	_plate.position = FAR
	var untrained := await _scoped_settle()
	_player.skills.set_tier(&"sniper", 3)
	await _driver.frames(2)
	var master := await _scoped_settle()
	print(
		(
			"MEASURED sniper scoped settle (s) to 0.25 deg / to its floor: untrained %.2f / %.2f, master %.2f / %.2f"
			% [untrained.x, untrained.y, master.x, master.y]
		)
	)

	# Untrained: from 6 to 0.25 degrees with tau 0.3 s, 0.3 x ln(5.8 / 0.05) = 1.43 s. Master: from
	# 2.4 with tau 0.12 s and a 0.08 floor, 0.12 x ln(2.32 / 0.17) = 0.31 s.
	assert_float(untrained.x).is_between(1.3, 1.6)
	assert_float(master.x).is_between(0.2, 0.45)
	assert_float(master.y).is_less(untrained.y * 0.5)


func test_rifles_master_puts_every_shotgun_pellet_on_a_half_metre_plate_at_10_m() -> void:
	await _load(SHOTGUN)
	_plate.position = Vector3(0, EYE, -10)
	_wall.position = FAR
	var untrained := await _pellets_on_plate()
	_player.skills.set_tier(&"rifles", 3)
	var master := await _pellets_on_plate()
	print(
		"MEASURED shotgun pellets (of 8) on a 0.5 m plate at 10 m per seed: untrained ", untrained, " master ", master
	)

	# Untrained: the 2.5 degree cone is 0.44 m across at 10 m, the plate's half-width 0.25 m: about
	# 3 of 8. Master: 1.0 degree (0.17 m) plus a 0.2 degree aim cone: all 8.
	var untrained_total := 0
	for count in untrained:
		untrained_total += count
		assert_int(count).is_less(8)
	assert_float(untrained_total / float(SEEDS.size())).is_between(1.5, 5.0)
	for count in master:
		assert_int(count).is_equal(8)


func test_master_reload_times_and_damage_scale_of_the_long_guns() -> void:
	await _load(SHOTGUN)
	_plate.position = Vector3(0, EYE, -10)
	_wall.position = FAR
	_player.skills.set_tier(&"rifles", 3)
	_player.skills.set_tier(&"sniper", 3)
	var inventory := _player.inventory
	for item: ItemData in [SNIPER, RIFLE]:
		inventory.give(item, 1)
		inventory.give(inventory.catalog.find(item.weapon.ammo_item), 20)
	# Reload 2.4 / 2.5 / 2.2 s x0.5; damage x1.3.
	var expected := {&"shotgun": 1.2, &"sniper_rifle": 1.25, &"assault_rifle": 1.1}
	for stack: ItemStack in inventory.inventory.stacks.filter(func(s: ItemStack) -> bool: return s.item.weapon != null):
		inventory.hold(stack)
		await _driver.frames(2)
		EventLog.clear()
		_player.weapons.state().cooldown = 0.0
		assert_int(_player.weapons.trigger()).is_equal(WeaponState.Result.FIRED)
		await _driver.frames(2)
		assert_bool(_player.weapons.reload()).is_true()
		var id := _player.weapons.weapon().id
		var started := EventLog.find(&"weapon.reload_started")
		assert_float(float(started[0].data["time"])).override_failure_message(String(id)).is_equal_approx(
			float(expected[id]), 0.001
		)
		var damage := EventLog.find(&"stimulus.emitted").filter(
			func(entry: EventLogEntry) -> bool: return entry.data["type"] == &"damage.ballistic"
		)
		assert_array(damage).is_not_empty()
		for entry: EventLogEntry in damage:
			assert_float(float(entry.data["scale"])).override_failure_message(String(id)).is_equal_approx(1.3, 0.0001)
		_player.weapons.state().cancel_reload()


# Holds the trigger through a full magazine aimed at the wall centre; the mean distance (m) of the
# hits from their centre.
func _group_radius(seed: int) -> float:
	await _aim_at(_wall.position)
	_player.weapons.state().magazine = 30
	_player.weapons.seed_rng(seed)
	_hits.clear()
	_fired = 0
	_driver.runner.simulate_action_press(&"fire")
	var frames := 0
	while _player.weapons.state().magazine > 0 and frames < 240:
		await _driver.frames(1)
		frames += 1
	_driver.runner.simulate_action_release(&"fire")
	await _driver.frames(30)
	assert_int(_hits.size()).is_equal(30)
	var centre := Vector3.ZERO
	for hit in _hits:
		centre += hit / float(_hits.size())
	var total := 0.0
	for hit in _hits:
		total += hit.distance_to(centre)
	return total / float(_hits.size())


# Scopes in from a settled hip cone, holds still; seconds until the cone is at 0.25 degrees (x) and
# at its floor (y); scopes out again.
func _scoped_settle() -> Vector2:
	await _aim_at(Vector3(0, EYE, -40))
	await _driver.hold(&"alt_fire", 2)
	assert_bool(_player.weapons.scope.scoped).is_true()
	var frames := 0
	var to_quarter := -1
	var previous := INF
	while frames < 240:
		var spread := _player.weapons.aim.spread
		if to_quarter < 0 and spread <= 0.25:
			to_quarter = frames
		# At its floor: the cone snapped and stopped moving.
		if spread == previous and to_quarter >= 0:
			break
		previous = spread
		await _driver.frames(1)
		frames += 1
	await _driver.hold(&"alt_fire", 2)
	await _driver.frames(2)
	return Vector2(to_quarter, frames) * FRAME


# One settled shotgun shot per seed at the plate; the pellets that hit it (nothing else is in reach).
func _pellets_on_plate() -> Array[int]:
	await _aim_at(_plate.position)
	var counts: Array[int] = []
	var state := _player.weapons.state()
	for seed in SEEDS:
		state.cooldown = 0.0
		state.magazine = state.data.magazine_size
		_player.weapons.seed_rng(seed)
		_player.weapons.settle()
		EventLog.clear()
		assert_int(_player.weapons.trigger()).is_equal(WeaponState.Result.FIRED)
		var fired := EventLog.find(&"weapon.fired")
		counts.append(int(fired[0].data["hits"]))
		await _driver.frames(1)
	return counts


# Stands the player at the origin looking at `point`, the cone settled to its floor.
func _aim_at(point: Vector3) -> void:
	_player.load_state(Objects.aiming_state(_player, Vector3.ZERO, point))
	await _driver.frames(5)
	_player.weapons.settle()


func _on_entry(entry: EventLogEntry) -> void:
	if entry.kind != &"weapon.fired":
		return
	if not _player.weapons.last_hit.is_empty():
		_hits.append(_player.weapons.last_hit["position"] as Vector3)
	# M13a (ADR 0123): the player pulls the mouse against the assault rifle's learned pattern (each
	# shot's step at the skill's size); the noise is not pulled.
	var recoil := _player.weapons.weapon().recoil
	if recoil == null or not recoil.has_pattern():
		return
	var size := Attributes.read(_player, &"rifle_recoil_size_mult", 1.0)
	var step := recoil.pattern_step(_fired) * recoil.pattern_scale * size
	_fired += 1
	var degrees_per_pixel := rad_to_deg(_player.config.mouse_sensitivity)
	_player.look(Vector2(-step.x, step.y) / degrees_per_pixel)


func _load(item: ItemData) -> void:
	_driver = PlayerDriver.new(scene_runner(RANGE))
	_player = _driver.player
	_plate = _driver.runner.find_child("Plate") as StaticBody3D
	_wall = _driver.runner.find_child("Wall") as StaticBody3D
	await _driver.settle()
	var inventory := _player.inventory
	inventory.give(item, 1)
	inventory.give(inventory.catalog.find(item.weapon.ammo_item), 60)
	inventory.select_slot(0)
	await _driver.frames(2)
	EventLog.entry_added.connect(_on_entry)
