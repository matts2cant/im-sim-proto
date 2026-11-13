extends GdUnitTestSuite
## Shooting range M13a tools (ADR 0125) in the hub with the player, one hub load: the widened booth
## and the new lanes are on the navmesh; the player walks up to the counter in the moving-target
## lane; E on the tuning terminal opens the panel with a slider per range value of the pistol in
## hand (whatever TuningProperties finds), Esc closes it and gives the controls back; a pistol shot
## at the spray wall leaves a mark there and the stats board counts the hit. Room-local points.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Weapons := preload("res://tests/items/weapons/weapon_test_helpers.gd")
const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const HUB := "res://levels/hub/hub.tscn"
## The new floor: the east booth, lane 5 in front of the spray wall, lane 6 at the walker's line.
const NAV_POINTS: Array[Vector3] = [
	Vector3(12, 0, -6), Vector3(19, 0, -6.5), Vector3(12.5, 0, -16), Vector3(17.5, 0, -30)
]
const LANE_6_BOOTH := Vector3(17.5, 0, -6)
const AT_TERMINAL := Vector3(15, 0, -7.45)
const TERMINAL_SCREEN := Vector3(15, 1.27, -8.3)
const LANE_5_LINE := Vector3(12.5, 0, -7.45)
const SPRAY_AIM := Vector3(12.5, 1.4, -18)

var _driver: PlayerDriver
var _weapons: Weapons
var _room: Node3D


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_walk_tune_and_shoot_the_spray_wall() -> void:
	_driver = PlayerDriver.new(scene_runner(HUB))
	_room = _driver.runner.find_child("ShootingRangeRoom") as Node3D
	var nav := _driver.runner.find_child("Navigation") as LevelNavigation
	await _driver.settle()
	var spawn := (_driver.runner.find_child("PlayerSpawn") as Node3D).global_position
	assert_bool(await KitGeometry.wait_for_navigation(get_tree(), nav.get_navigation_map(), spawn)).is_true()
	for local: Vector3 in NAV_POINTS:
		var target := _room.to_global(local)
		var path := NavigationServer3D.map_get_path(nav.get_navigation_map(), spawn, target, true)
		assert_float(path[-1].distance_to(target)).override_failure_message(str(local)).is_less(0.3)

	# Walk up to the counter in lane 6 (room -Z is hub +X: yaw -90 degrees).
	await _driver.place(_room.to_global(LANE_6_BOOTH), -PI / 2.0)
	await _driver.hold(&"move_forward", 60)
	var feet := _room.to_local(_driver.player.global_position)
	assert_float(feet.z).is_between(-8.0, -7.3)

	# E on the tuning terminal with the pistol drawn.
	_weapons = Weapons.new(_driver)
	await _weapons.equip(1)
	await _weapons.aim_at(_room.to_global(AT_TERMINAL), _room.to_global(TERMINAL_SCREEN))
	await _driver.hold(&"use", 2)
	var panel := Screens.screen_of(_driver.player, TuningDesk.SCREEN) as TuningPanel
	assert_object(panel).is_not_null()
	assert_bool(panel.is_open()).is_true()
	assert_bool(_driver.player.accepts_input()).is_false()
	var pistol := _driver.player.weapons.weapon()
	var expected := 0
	for entry in TuningProperties.entries(pistol):
		expected += TuningProperties.sliders(entry.resource).size()
	assert_int(panel.slider_keys().size()).is_equal(expected)
	assert_int(expected).is_greater(0)
	await _driver.hold(&"ui_cancel", 2)
	assert_bool(panel.is_open()).is_false()
	assert_bool(_driver.player.accepts_input()).is_true()

	# A shot at the spray wall's aim mark from the lane 5 line.
	var marks := ImpactMarks.of(_room.get_node("SprayWall/Board"))
	var board := _room.get_node("FiringLine/StatsBoard") as StatsBoard
	await _weapons.aim_at(_room.to_global(LANE_5_LINE), _room.to_global(SPRAY_AIM))
	await _weapons.fire()
	assert_int(marks.count()).is_equal(1)
	assert_float(_room.to_local(marks.points()[0]).z).is_equal_approx(-18.0, 0.01)
	assert_int(board.stats.shots(&"Board")).is_equal(1)
	assert_int(board.stats.hits(&"Board")).is_equal(1)
