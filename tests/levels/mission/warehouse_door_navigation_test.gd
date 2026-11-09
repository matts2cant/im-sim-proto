extends GdUnitTestSuite
## Warehouse doors on the navmesh (ADR 0078, ADR 0090): guards reach every post and patrol point
## from the reinforcements' arrival through the doors their keys open (the security operator's
## post needs `access.warehouse_security`); the large doors (front gate, roller doors) open and
## close and keep guards out while locked, and let them through once unlocked or open.

const Helpers := preload("res://tests/levels/mission/warehouse_security_helpers.gd")
const REACH := 0.35
## Road in front of the gate, gate lane inside it, dock apron, dock inside (warehouse coordinates).
const ROAD := Vector3(-5, 0, -30)
const GATE_LANE := Vector3(-5, 0, -20)
const APRON := Vector3(-8, 0, -14)
const DOCK := Vector3(-8, 0, -6)

var _helpers: Helpers


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_helpers = Helpers.new()


func after_test() -> void:
	_helpers.teardown()
	StimulusSystem.clear()


func test_guards_reach_their_posts_through_the_doors_their_keys_open() -> void:
	await _helpers.load_level(self, true)
	var start := (_helpers.level.get_node("ReinforcementSpawn") as Node3D).global_position
	var keys := (
		AccessLayers.WALK
		| AccessLayers.access_layer(&"warehouse_security")
		| AccessLayers.access_layer(&"warehouse_vault")
	)
	var missing: PackedStringArray = []
	for group: String in ["Guards", "PatrolPoints"]:
		for marker: Node3D in _helpers.level.get_node("LayoutMarkers/" + group).get_children():
			if not _reaches(start, marker.global_position, keys):
				missing.append(String(marker.name))
	assert_array(missing).is_empty()
	# The security operator's post is behind the keycard door: without the access, no path.
	var operator := (_helpers.level.get_node("LayoutMarkers/Guards/G5SecurityOperator") as Node3D).global_position
	assert_bool(_reaches(start, operator, AccessLayers.WALK)).is_false()


func test_large_doors_open_close_and_keep_guards_out_while_locked() -> void:
	await _helpers.load_level(self, true)
	var gate := _helpers.door("FrontGate")
	assert_bool(_reaches(ROAD, GATE_LANE, AccessLayers.WALK)).is_true()

	Lockable.of(gate.entity).lock(null, &"test")
	await _helpers.frames(2)
	assert_bool(_reaches(ROAD, GATE_LANE, AccessLayers.WALK)).is_false()
	# An authorised open (the console) lets guards through while it stays open.
	gate.open()
	await _helpers.frames(2)
	assert_bool(_reaches(ROAD, GATE_LANE, AccessLayers.WALK)).is_true()
	# 3 s to open the 6 m gate.
	await _helpers.seconds(3.2)
	assert_float(gate.openness).is_equal_approx(1.0, 0.001)

	# Both roller doors locked: the dock is shut to guards from the yard.
	var rollers: Array[Door] = [_helpers.door("RollerDoor1"), _helpers.door("RollerDoor2")]
	assert_bool(_reaches(APRON, DOCK, AccessLayers.WALK)).is_true()
	for roller in rollers:
		Lockable.of(roller.entity).lock(null, &"test")
	await _helpers.frames(2)
	assert_bool(_reaches(APRON, DOCK, AccessLayers.WALK)).is_false()
	Lockable.of(rollers[0].entity).unlock(null, &"test")
	await _helpers.frames(2)
	assert_bool(_reaches(APRON, DOCK, AccessLayers.WALK)).is_true()

	# A roller door rises in 2.5 s, clears the doorway and comes down again.
	var panel := rollers[0].entity.get_node("Panel") as CollisionShape3D
	var closed_y := panel.position.y
	assert_bool(rollers[0].open()).is_true()
	await _helpers.seconds(2.7)
	assert_float(panel.position.y - closed_y).is_equal_approx(4.1, 0.01)
	assert_bool(rollers[0].close()).is_true()
	await _helpers.seconds(2.7)
	assert_float(panel.position.y).is_equal_approx(closed_y, 0.01)


func _reaches(from: Vector3, to: Vector3, layers: int) -> bool:
	var path := NavigationServer3D.map_get_path(_helpers.map, from, to, true, layers)
	return not path.is_empty() and path[-1].distance_to(to) < REACH
