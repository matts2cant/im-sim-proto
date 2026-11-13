extends GdUnitTestSuite
## Integration (ADR 0085): the shotgun, sniper rifle and assault rifle fired by the player through
## its WeaponHolder emit their damage rays (one per pellet), force rays and muzzle noise; the pistol
## is loud by default; the assault rifle keeps firing while LMB is held and stops on release (never a
## dry click); reloads take each weapon's own ammo item.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const ROOM := "res://tests/objects/fixtures/carry_room.tscn"
## The room's wall face is at z = -5.8.
const WALL_POINT := Vector3(0, 1.5, -5.8)
const PISTOL: ItemData = preload("res://items/weapons/pistol/pistol_item.tres")
const SHOTGUN: ItemData = preload("res://items/weapons/shotgun/shotgun_item.tres")
const SNIPER: ItemData = preload("res://items/weapons/sniper_rifle/sniper_rifle_item.tres")
const RIFLE: ItemData = preload("res://items/weapons/assault_rifle/assault_rifle_item.tres")

var _driver: PlayerDriver
var _player: Player


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_pistol_is_loud_by_default() -> void:
	await _load(PISTOL)
	await _shoot_once()
	assert_array(_rays(&"damage.ballistic")).has_size(1)
	assert_float(_muzzle_noise()).is_equal(25.0)
	assert_str(_player.inventory.in_hand().display_name()).is_equal("Pistol")


func test_shotgun_fires_eight_pellets_of_twelve() -> void:
	await _load(SHOTGUN)
	await _shoot_once()

	var pellets := _rays(&"damage.ballistic")
	assert_array(pellets).has_size(8)
	for entry in pellets:
		assert_float(entry.data["intensity"]).is_equal(12.0)
	assert_array(_rays(&"force.impact")).has_size(8)
	assert_float(_muzzle_noise()).is_equal(30.0)
	var fired := EventLog.find(&"weapon.fired")
	assert_int(fired[0].data["projectiles"]).is_equal(8)
	assert_int(fired[0].data["hits"]).is_equal(8)
	assert_int(fired[0].data["magazine"]).is_equal(5)


func test_sniper_rifle_fires_one_heavy_round() -> void:
	await _load(SNIPER)
	await _shoot_once()
	var rounds := _rays(&"damage.ballistic")
	assert_array(rounds).has_size(1)
	assert_float(rounds[0].data["intensity"]).is_equal(90.0)
	assert_float(_muzzle_noise()).is_equal(35.0)


func test_rifle_fires_while_held_and_stops_on_release() -> void:
	await _load(RIFLE)
	_driver.runner.simulate_action_press(&"fire")
	# 0.5 s held: a shot at once, then one every 0.1 s (6 ticks).
	await _driver.frames(30)
	_driver.runner.simulate_action_release(&"fire")
	await _driver.frames(3)
	var held_shots := EventLog.find(&"weapon.fired").size()
	assert_int(held_shots).is_between(5, 6)
	var rounds := _rays(&"damage.ballistic")
	assert_float(rounds[0].data["intensity"]).is_equal(14.0)
	assert_float(_muzzle_noise()).is_equal(28.0)

	await _driver.frames(30)
	assert_int(EventLog.find(&"weapon.fired").size()).is_equal(held_shots)
	assert_bool(_player.weapons.trigger_held).is_false()


func test_rifle_burst_stops_at_an_empty_magazine_without_clicking() -> void:
	await _load(RIFLE)
	_player.weapons.state().magazine = 3
	_driver.runner.simulate_action_press(&"fire")
	await _driver.frames(40)
	_driver.runner.simulate_action_release(&"fire")
	assert_array(EventLog.find(&"weapon.fired")).has_size(3)
	assert_array(EventLog.find(&"weapon.dry_fire")).is_empty()


func test_each_weapon_reloads_from_its_own_ammo() -> void:
	await _load(SHOTGUN)
	_player.inventory.add(_catalog().find(&"pistol_ammo"), 50)
	_player.weapons.state().magazine = 0
	await _driver.hold(&"reload", 2)
	await _driver.frames(ceili(SHOTGUN.weapon.reload_time * 60.0) + 4)
	assert_int(_player.weapons.state().magazine).is_equal(6)
	assert_int(_player.inventory.grid.count_of(&"shotgun_shells")).is_equal(30 - 6)
	assert_int(_player.inventory.grid.count_of(&"pistol_ammo")).is_equal(50)


func _shoot_once() -> void:
	await _driver.hold(&"fire", 2)
	await _driver.frames(4)


func _rays(type: StringName) -> Array[EventLogEntry]:
	return EventLog.find(&"stimulus.emitted").filter(
		func(entry: EventLogEntry) -> bool: return entry.data["shape"] == "ray" and entry.data["type"] == type
	)


# The first noise of the log: the muzzle (the impact noise follows it).
func _muzzle_noise() -> float:
	for entry in EventLog.find(&"stimulus.emitted"):
		if entry.data["type"] == &"noise":
			return entry.data["intensity"]
	return -1.0


func _catalog() -> ItemCatalog:
	return _player.inventory.catalog


func _load(item: ItemData) -> void:
	_driver = PlayerDriver.new(scene_runner(ROOM))
	_player = _driver.player
	_player.weapons.seed_rng(4242)
	await _driver.settle()
	_player.inventory.add(item, 1)
	_player.inventory.add(_catalog().find(item.weapon.ammo_item), 30)
	await _driver.hold(&"belt_1", 2)
	await _driver.frames(1)
	_player.load_state(Objects.aiming_state(_player, Vector3.ZERO, WALL_POINT))
	await _driver.frames(5)
	_player.weapons.settle()
	EventLog.clear()
