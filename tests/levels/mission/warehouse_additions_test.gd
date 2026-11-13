extends GdUnitTestSuite
## Integration (design/levels/mission-warehouse.md "Routes", M9f additions, ADR 0093): two optional
## spots that give stacking props and Combat Strength a use in the warehouse, played by the real
## player in the populated level (its guards removed: these tests are about the moves).
## - The annex's high window (sill 2.9 m, south wall): out of reach from the ground (even with Speed
##   Enhancement: 2.5 m) and from one small crate (2.3 m), reached from two stacked small crates
##   (1.2 + a 1.7 m mantle): the player carries the two crates beside it under the window, stacks
##   them, climbs in and takes the biocell inside (and could cut breaker A).
## - The cache shed (back strip, south-west corner): its opening is closed by a large crate (60 kg)
##   that the player cannot carry (20 kg limit) until Combat Strength is on (70 kg); then the crate
##   is put aside and the medkit and pistol rounds inside are picked up.

const Route := preload("res://tests/levels/mission/warehouse_route_driver.gd")
const Helpers := preload("res://tests/levels/mission/warehouse_helpers.gd")
const PROPS := "Population/People/Props/"
const ITEMS := "Population/People/Items/"
## The window's sill (top of the annex south wall's opening) and the wall's outer face.
const SILL := 2.9
const WALL_FACE_Z := 13.0
const WINDOW_X := -23.0

var _route: Route


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	_route = Route.new()


func after_test() -> void:
	_route.teardown()
	StimulusSystem.clear()


func test_the_annex_window_is_reached_only_from_two_stacked_crates() -> void:
	await _setup()
	var hands := _route.hands
	var player := _route.player
	# From the ground the sill is out of reach, also with Speed Enhancement (mantle 2.5 m).
	await _route.place(Vector3(WINDOW_X, 0, 13.8), Route.NORTH)
	assert_bool(await _route.climb(Route.NORTH, SILL, 6, 60)).is_false()
	await hands.press(&"aug_3")
	assert_bool(player.augmentations.is_active(&"speed_enhancement")).is_true()
	await _route.place(Vector3(WINDOW_X, 0, 13.8), Route.NORTH)
	assert_bool(await _route.climb(Route.NORTH, SILL, 6, 60)).is_false()
	await hands.press(&"aug_3")
	assert_bool(player.augmentations.is_active(&"speed_enhancement")).is_false()
	_route.notes.clear()

	# Carry the first crate under the window and set it down against the wall.
	var ok := await _route.go([Vector3(-21.7, 0, 15.2)])
	ok = ok and await hands.use_node(PROPS + "WindowCrate1")
	ok = ok and player.carry.is_carrying()
	ok = ok and await _route.go([Vector3(WINDOW_X, 0, WALL_FACE_Z + 1.3)])
	ok = ok and await hands.put_down(Route.NORTH)
	await _route.frames(30)
	var crate1 := _route.level.get_node(PROPS + "WindowCrate1") as Node3D
	assert_bool(ok).override_failure_message(_route.report()).is_true()
	assert_float(crate1.global_position.z).override_failure_message("crate 1 at %s" % crate1.global_position).is_less(
		WALL_FACE_Z + 0.7
	)
	# One crate (0.6 m) leaves 2.3 m to the sill: no mantle without Speed Enhancement.
	await _route.place(Vector3(WINDOW_X, 0, crate1.global_position.z + 1.05), Route.NORTH)
	ok = await _route.climb(Route.NORTH, 0.6, 20, 60)
	ok = ok and not await _route.climb(Route.NORTH, SILL, 6, 60)
	assert_bool(ok).override_failure_message("one crate: %s\n%s" % [player.global_position, _route.report()]).is_true()
	_route.notes.clear()

	# The second crate on top of the first: from the stack (1.2 m) the sill is a 1.7 m mantle.
	await _route.place(Vector3(-20.9, 0, 16.0), Route.NORTH)
	ok = await hands.use_node(PROPS + "WindowCrate2")
	ok = ok and player.carry.is_carrying()
	ok = ok and await _route.go([Vector3(WINDOW_X, 0, WALL_FACE_Z + 1.3)])
	ok = ok and await hands.put_down(Route.NORTH)
	await _route.frames(30)
	var crate2 := _route.level.get_node(PROPS + "WindowCrate2") as Node3D
	assert_bool(ok).override_failure_message(_route.report()).is_true()
	(
		assert_float(crate2.global_position.y)
		. override_failure_message("crate 2 at %s" % crate2.global_position)
		. is_greater(0.8)
	)
	await _route.place(Vector3(WINDOW_X, 0, crate1.global_position.z + 1.05), Route.NORTH)
	ok = await _route.climb(Route.NORTH, 1.2)
	ok = ok and await _route.climb(Route.NORTH, SILL)
	# Through the window: down onto the ledge inside (1.5 m) and the floor, to the biocell.
	ok = ok and await _route.go([Vector3(WINDOW_X, 0, 11.0), Vector3(-24.5, 0, 11.6)], Route.Stance.CROUCH)
	ok = ok and await hands.use_node(ITEMS + "Biocell1")
	assert_bool(ok).override_failure_message("%s\n%s" % [player.global_position, _route.report()]).is_true()
	assert_int(player.inventory.grid.count_of(&"biocell")).is_equal(1)


func test_the_cache_crate_moves_only_with_combat_strength() -> void:
	await _setup()
	var hands := _route.hands
	var player := _route.player
	var crate_path := PROPS + "CacheCrate"
	await _route.place(Vector3(-33.8, 0, 20.6), Route.SOUTH)
	# 60 kg: too heavy without Combat Strength (20 kg limit).
	await hands.use_node(crate_path)
	assert_bool(player.carry.is_carrying()).is_false()
	assert_str(player.interactor.prompt).is_equal("Too heavy")
	# Combat Strength on (70 kg): carried, put down west of the shed's opening.
	await hands.press(&"aug_5")
	assert_bool(player.augmentations.is_active(&"combat_strength")).is_true()
	var ok := await hands.use_node(crate_path)
	ok = ok and player.carry.is_carrying()
	ok = ok and await _route.go([Vector3(-32.5, 0, 18.0)])
	ok = ok and await hands.put_down(Route.NORTH)
	await hands.press(&"aug_5")
	# The opening is clear: crouch in front of it and take the medkit and the rounds.
	var medkits := player.inventory.grid.count_of(&"medkit")
	var rounds := player.inventory.grid.count_of(&"pistol_ammo")
	ok = ok and await _route.go([Vector3(-33.8, 0, 22.7)], Route.Stance.CROUCH)
	runner_crouch(true)
	ok = ok and await hands.use_node(ITEMS + "CacheMedkit")
	ok = ok and await hands.use_node(ITEMS + "CacheAmmo")
	runner_crouch(false)
	assert_bool(ok).override_failure_message("%s\n%s" % [player.global_position, _route.report()]).is_true()
	assert_int(player.inventory.grid.count_of(&"medkit")).is_equal(medkits + 1)
	assert_int(player.inventory.grid.count_of(&"pistol_ammo")).is_equal(rounds + 10)


func runner_crouch(down: bool) -> void:
	if down:
		_route.runner.simulate_action_press(&"crouch")
	else:
		_route.runner.simulate_action_release(&"crouch")


# The warehouse with its population (props, items) but no guards: the moves are under test.
func _setup() -> void:
	var level := Route.fixture(self)
	for guard in level.get_node(Route.GUARDS).get_children():
		guard.free()
	await _route.setup(scene_runner(level))
