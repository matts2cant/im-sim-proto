extends GdUnitTestSuite
## Integration: every climb on the warehouse routes works with the plain mantle (forward + jump), at
## the heights the layout doc lists (design/levels/mission-warehouse.md, route table): pallet
## stacks, containers and crates to the annex roof and the yard perch, the fire escape's raised
## bottom landing, the ditch and drain chamber exits, the duct mouths and the manager office
## cabinet. Also the over-the-fence jump from the outside container.

const Helpers := preload("res://tests/levels/mission/warehouse_helpers.gd")

## name -> [feet, yaw, expected top (y)]. Each starts standing at rest facing the face to climb.
const CLIMBS: Dictionary[String, Array] = {
	"road pallets 1.2": [Vector3(-29, 0, -29.5), Helpers.SOUTH, 1.2],
	"outside container 1.3": [Vector3(-29, 1.2, -28.2), Helpers.SOUTH, 2.5],
	"yard step 1.2": [Vector3(-31.8, 0, -16.8), Helpers.EAST, 1.2],
	"yard low container 1.3": [Vector3(-30.6, 1.2, -16.8), Helpers.EAST, 2.5],
	"yard crate 1.2": [Vector3(-28.2, 2.5, -16.1), Helpers.EAST, 3.7],
	"yard perch 1.3": [Vector3(-27.0, 3.7, -16.1), Helpers.SOUTH, 5.0],
	"annex step 1.2": [Vector3(-30.8, 0, 6.0), Helpers.EAST, 1.2],
	"annex container 1.3": [Vector3(-29.6, 1.2, 6.0), Helpers.EAST, 2.5],
	"annex crate 1.1": [Vector3(-28.4, 2.5, 6.0), Helpers.EAST, 3.6],
	"annex roof 1.15": [Vector3(-27.2, 3.6, 6.0), Helpers.EAST, 4.75],
	"fire escape 1.44": [Vector3(21.2, 0, 13.95), Helpers.NORTH, 1.44],
	"ditch step 1.2": [Vector3(39, -2.4, 20.4), Helpers.SOUTH, -1.2],
	"ditch out 1.2": [Vector3(39, -1.2, 21.4), Helpers.SOUTH, 0.0],
	"chamber step 1.2": [Vector3(32.8, -2.4, -7.6), Helpers.WEST, -1.2],
	"chamber out 1.2": [Vector3(31.6, -1.2, -7.6), Helpers.WEST, 0.0],
	"duct A mouth 1.1": [Vector3(14, 4.5, -8.2), Helpers.SOUTH, 5.6],
	"duct C mouth 1.1": [Vector3(12.7, -4, -8.3), Helpers.EAST, -2.9],
	"office cabinet 1.35": [Vector3(11, 4.5, 4.1), Helpers.NORTH, 5.85],
	"duct B hole 1.7": [Vector3(11, 5.85, 2.9), Helpers.SOUTH, 7.55],
}

var _helpers: Helpers


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	_helpers = Helpers.new()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	StimulusSystem.clear()


func test_every_route_climb_is_a_plain_mantle() -> void:
	await _helpers.setup(scene_runner(Helpers.FIXTURE))
	var failures: PackedStringArray = []
	for climb: String in CLIMBS:
		var spec: Array = CLIMBS[climb]
		var start: Vector3 = spec[0]
		# Jump pressed briefly: the mantle is a scripted move that needs no more input.
		await _helpers.play(start, spec[1], [Helpers.mantle(6), Helpers.wait(50)])
		var feet := _helpers.player.global_position
		var moved := Vector2(feet.x - start.x, feet.z - start.z).length()
		if absf(feet.y - float(spec[2])) > 0.12 or moved < 0.3:
			failures.append("%s: ended at %s" % [climb, feet])
	assert_array(failures).is_empty()


func test_the_outside_container_jumps_the_fence_onto_the_inside_one() -> void:
	await _helpers.setup(scene_runner(Helpers.FIXTURE))
	var legs := _helpers.leg_health()

	# Standing on the outside container 0.65 m from the 3 m fence (its top 0.5 m above the feet):
	# jump while walking forward.
	await _helpers.play(Vector3(-29, 2.5, -25.7), Helpers.SOUTH, [Helpers.mantle(45), Helpers.wait(10)])

	var feet := _helpers.player.global_position
	assert_float(feet.y).is_equal_approx(2.5, 0.1)
	assert_float(feet.z).is_between(-24.9, -22.4)
	assert_float(_helpers.leg_health()).is_equal(legs)
