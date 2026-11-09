extends GdUnitTestSuite
## Warehouse night lighting (light-and-visibility.md, metrics.md "Light and guards"): every listed
## hiding spot reads dark (< 0.1) and every lit pool where guards stand or patrol reads lit (>= 0.5)
## for a standing body (the spots are the LayoutMarkers DarkSpots / LitSpots; `crouched` ones are
## measured crouched). Breaker A's circuit (`warehouse_yard`) carries the outdoor lights and
## breaker B's (`warehouse_building`) the building's: cutting one darkens its pools only.

const Helpers := preload("res://tests/levels/mission/warehouse_helpers.gd")
const YARD := &"warehouse_yard"
const BUILDING := &"warehouse_building"
const DARK := 0.1
const LIT := 0.5
## Lit pools on each circuit (LayoutMarkers/LitSpots names).
const YARD_POOLS: Array[String] = ["GateLane", "DockApronWest", "SideDoor", "BackGate", "Booth"]
const BUILDING_POOLS: Array[String] = ["DockInside", "GroundCorridor", "UpperCorridor", "SecurityRoom", "BreakRoom"]

var _level: Node3D


# One level for the suite: its tests only query it (design/tech/testing.md "Writing fast tests").
func before() -> void:
	_level = await Helpers.load_for_queries(self, true, false)


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	StimulusSystem.clear()


func test_hiding_spots_are_dark_and_pools_are_lit() -> void:
	var wrong: PackedStringArray = []
	for marker: Node3D in _level.get_node("LayoutMarkers/DarkSpots").get_children():
		var level := _measure(marker.global_position, marker.get_meta(&"crouched", false))
		if level >= DARK:
			wrong.append("dark %s: %.2f" % [marker.name, level])
	for marker: Node3D in _level.get_node("LayoutMarkers/LitSpots").get_children():
		var level := _measure(marker.global_position, false)
		if level < LIT:
			wrong.append("lit %s: %.2f" % [marker.name, level])
	assert_array(wrong).is_empty()


func test_each_breaker_circuit_darkens_its_own_pools() -> void:
	var spots := _level.get_node("LayoutMarkers/LitSpots")
	assert_int(Powered.set_circuit(get_tree(), YARD, false)).is_greater(5)
	for pool: String in YARD_POOLS:
		var level := _measure((spots.get_node(pool) as Node3D).global_position, false)
		assert_float(level).override_failure_message("yard off, %s: %.2f" % [pool, level]).is_less(LIT)
	for pool: String in BUILDING_POOLS:
		var level := _measure((spots.get_node(pool) as Node3D).global_position, false)
		assert_float(level).override_failure_message("yard off, %s: %.2f" % [pool, level]).is_greater_equal(LIT)
	Powered.set_circuit(get_tree(), YARD, true)
	assert_int(Powered.set_circuit(get_tree(), BUILDING, false)).is_greater(10)
	for pool: String in BUILDING_POOLS:
		var level := _measure((spots.get_node(pool) as Node3D).global_position, false)
		assert_float(level).override_failure_message("building off, %s: %.2f" % [pool, level]).is_less(LIT)
	for pool: String in YARD_POOLS:
		var level := _measure((spots.get_node(pool) as Node3D).global_position, false)
		assert_float(level).override_failure_message("building off, %s: %.2f" % [pool, level]).is_greater_equal(LIT)
	# The suite's level is shared: building power back on.
	Powered.set_circuit(get_tree(), BUILDING, true)


func _measure(feet: Vector3, crouched: bool) -> float:
	var body := StaticBody3D.new()
	body.collision_layer = PhysicsLayers.ACTORS
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 0.95 if crouched else 1.8
	shape.shape = capsule
	shape.position.y = capsule.height * 0.5
	body.add_child(shape)
	var tags := Tags.new()
	if crouched:
		tags.initial_tags = [&"stance.crouch"]
	body.add_child(tags)
	var exposure := LightExposure.new()
	body.add_child(exposure)
	_level.add_child(body)
	body.global_position = feet
	var level := exposure.update_now()
	body.free()
	return level
