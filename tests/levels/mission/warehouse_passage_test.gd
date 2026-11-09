extends GdUnitTestSuite
## Integration: the player walks, crawls and drops along the warehouse's connections
## (design/levels/mission-warehouse.md, route table): annex roof door onto the catwalks, the annex
## and fire escape stairs to the roof, the skylight drop to the bridge (harmless), ducts A
## (catwalk <-> roof), B (roof -> manager office) and C (boiler room -> security room), the culvert,
## the service tunnel, the hall hatch stair, the service stair and the hall and office stairs.

const Helpers := preload("res://tests/levels/mission/warehouse_helpers.gd")

var _helpers: Helpers


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	_helpers = Helpers.new()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	StimulusSystem.clear()


func test_stairs_and_roof_doors_connect_every_level() -> void:
	await _helpers.setup(scene_runner(Helpers.fixture(self)))
	# name -> [feet, yaw, frames walked, expected feet y, region the feet end in (x0, z0, x1, z1)]
	var walks: Dictionary[String, Array] = {
		"annex roof door to the west catwalk":
		[Vector3(-23, 4.75, 2.1), Helpers.EAST, 90, 4.5, Rect2(-20, -10, 1.6, 25)],
		"annex stair to the roof landing":
		[Vector3(-21.25, 4.75, 12.0), Helpers.NORTH, 300, 9.5, Rect2(-22, 2.3, 1.6, 1.4)],
		"fire escape to the roof landing":
		[Vector3(21.2, 4.5, 5.6), Helpers.NORTH, 300, 9.5, Rect2(20.4, -4.6, 1.5, 1.4)],
		"fire escape bottom to the door":
		[Vector3(21.2, 1.44, 12.6), Helpers.NORTH, 90, 4.5, Rect2(20.5, 4.8, 2.4, 2.4)],
		"north-east hall stair": [Vector3(17.8, 0, -0.9), Helpers.NORTH, 240, 4.5, Rect2(-20, -10, 40, 1.6)],
		"south-west hall stair": [Vector3(-10.8, 0, 12.8), Helpers.WEST, 240, 4.5, Rect2(-20, -10, 1.6, 25)],
		"office stair": [Vector3(12.35, 0, 7.8), Helpers.SOUTH, 240, 4.5, Rect2(11.7, 13.8, 1.3, 1.0)],
		"service stair down": [Vector3(8.9, 0, 7.6), Helpers.SOUTH, 300, -4.0, Rect2(8, 13, 2, 1.8)],
		"hatch stair up": [Vector3(11.1, -4, -0.9), Helpers.NORTH, 300, 0.0, Rect2(10, -10, 2.5, 3.6)],
		"tunnel to the boiler room": [Vector3(36.0, -2.4, -5), Helpers.WEST, 330, -4.0, Rect2(8, -9, 11.6, 8.5)],
		"drain chamber to the tunnel": [Vector3(33.4, -2.4, -7.6), Helpers.SOUTH, 40, -2.4, Rect2(31, -6, 4, 2)],
	}
	var failures: PackedStringArray = []
	for walk: String in walks:
		var spec: Array = walks[walk]
		await _helpers.play(spec[0], spec[1], [Helpers.walk(int(spec[2]))])
		var feet := _helpers.player.global_position
		if absf(feet.y - float(spec[3])) > 0.15 or not (spec[4] as Rect2).has_point(Vector2(feet.x, feet.z)):
			failures.append("%s: ended at %s" % [walk, feet])
	assert_array(failures).is_empty()


func test_skylight_drop_lands_on_the_bridge_unhurt() -> void:
	await _helpers.setup(scene_runner(Helpers.fixture(self)))
	var legs := _helpers.leg_health()

	# On the roof north of the rack R2 skylight: walk off its open north edge onto the goods 1.4 m down.
	await _helpers.play(Vector3(-5, 9.5, 1.5), Helpers.SOUTH, [Helpers.walk(25), Helpers.wait(30)])
	assert_float(_helpers.player.global_position.y).is_equal_approx(8.1, 0.1)
	# Off the goods (1.5 m) and the rack's south end (2.1 m) onto the bridge.
	await _helpers.play(_helpers.player.global_position, Helpers.SOUTH, [Helpers.walk(60), Helpers.wait(40)])

	var feet := _helpers.player.global_position
	assert_float(feet.y).is_between(4.35, 4.55)
	assert_float(feet.z).is_between(5.2, 11.0)
	assert_float(_helpers.leg_health()).is_equal(legs)


func test_ducts_connect_roof_catwalk_office_and_basement() -> void:
	await _helpers.setup(scene_runner(Helpers.fixture(self)))
	var legs := _helpers.leg_health()

	# Duct A: catwalk alcove (mantle 1.1 into the mouth) up to the roof.
	await _helpers.play(
		Vector3(14, 4.5, -8.2), Helpers.SOUTH, [Helpers.mantle(6), Helpers.wait(40), Helpers.crawl(330)]
	)
	var feet := _helpers.player.global_position
	assert_float(feet.y).override_failure_message("duct A: %s" % feet).is_between(9.45, 9.75)
	assert_float(feet.z).override_failure_message("duct A: %s" % feet).is_greater(-0.2)
	# Duct B: roof mouth down over the office roof, through the hole onto the cabinet.
	await _helpers.play(Vector3(11, 9.5, -6.5), Helpers.SOUTH, [Helpers.crawl(330), Helpers.wait(30)])
	feet = _helpers.player.global_position
	var office := AABB(Vector3(8.25, 4.4, 0.25), Vector3(5.5, 2.0, 4.75))
	assert_bool(office.has_point(feet)).override_failure_message("duct B: %s" % feet).is_true()
	# Duct C: boiler room mouth facing west (mantle 1.1), right turn, up into the security room.
	await _helpers.play(Vector3(12.7, -4, -8.3), Helpers.EAST, [Helpers.mantle(6), Helpers.wait(40), Helpers.crawl(40)])
	await _helpers.turn_and_play(Helpers.SOUTH, [Helpers.crawl(330)])
	feet = _helpers.player.global_position
	var security := AABB(Vector3(14.0, -0.1, 0.4), Vector3(5.75, 0.5, 4.6))
	assert_bool(security.has_point(feet)).override_failure_message("duct C: %s" % feet).is_true()
	# Culvert: ditch -> drain chamber, crawling.
	await _helpers.play(Vector3(37.7, -2.4, -7.6), Helpers.WEST, [Helpers.crawl(150)])
	feet = _helpers.player.global_position
	assert_float(feet.x).override_failure_message("culvert: %s" % feet).is_less(33.8)
	assert_float(_helpers.leg_health()).is_equal(legs)
