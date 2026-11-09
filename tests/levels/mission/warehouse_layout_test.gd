extends GdUnitTestSuite
## Warehouse mission level (design/levels/mission-warehouse.md): the contract nodes for the mission
## systems (PlayerSpawn facing the compound, ReinforcementSpawn with room for two guards, the
## extraction zone on the pontoon, the Mission with the warehouse data), the area sub-scenes and
## LevelNavigation last, no two CSG roots rendering different materials on one plane, every listed
## doorway open for a standing capsule, and every kit part inside its metric bands (no warnings).

const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const LEVEL: PackedScene = preload("res://levels/mission/warehouse.tscn")
const DATA: MissionData = preload("res://levels/mission/mission_kit/warehouse_mission.tres")
const AREAS: Array[String] = ["Exterior", "Hall", "Underground", "LayoutMarkers"]
## Compound fence (x, z) and the hall's interior (layout doc).
const COMPOUND := Rect2(-35, -25, 70, 50)
const HALL_CENTRE := Vector3(0, 0, 2.5)

var _level: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	StimulusSystem.clear()


func test_contract_nodes_for_the_mission_systems() -> void:
	var level: Node3D = auto_free(LEVEL.instantiate())
	var spawn := level.get_node("PlayerSpawn") as Marker3D
	var reinforcements := level.get_node("ReinforcementSpawn") as Marker3D
	var zone := level.get_node("Extraction") as ExtractionZone
	var mission := level.get_node("Mission") as Mission

	# The player starts on the north road, outside the fence, facing into the compound.
	assert_bool(COMPOUND.has_point(Vector2(spawn.position.x, spawn.position.z))).is_false()
	assert_float(spawn.position.z).is_between(-36.0, -27.0)
	var facing := -spawn.basis.z
	var to_hall := (HALL_CENTRE - spawn.position).normalized()
	assert_float(rad_to_deg(Vector2(facing.x, facing.z).angle_to(Vector2(to_hall.x, to_hall.z)))).is_between(
		-45.0, 45.0
	)
	# Reinforcements arrive on the road in front of the front gate (x -8 .. -2).
	assert_float(reinforcements.position.x).is_between(-7.0, -3.0)
	assert_float(reinforcements.position.z).is_between(-36.0, -27.0)
	# The extraction zone stands on the pontoon by the boat, inside the river's invisible walls.
	var half := zone.size * 0.5
	assert_float(zone.position.x - half.x).is_greater_equal(4.0)
	assert_float(zone.position.x + half.x).is_less_equal(10.0)
	assert_float(zone.position.z - half.z).is_greater_equal(33.0)
	assert_float(zone.position.z + half.z).is_less_equal(38.0)
	assert_object(mission.data).is_same(DATA)
	assert_object(mission.player_scene).is_not_null()
	# No player placed in the level: the Mission spawns it at PlayerSpawn.
	assert_object(level.get_node_or_null("Player")).is_null()
	for area: String in AREAS:
		assert_bool(level.get_node(area).scene_file_path.begins_with("res://levels/mission/areas/")).is_true()
	var navigation := level.get_child(level.get_child_count() - 1)
	assert_object(navigation).is_instanceof(LevelNavigation)


func test_reinforcements_have_room_to_appear_side_by_side() -> void:
	await _load()
	var marker := _level.get_node("ReinforcementSpawn") as Marker3D
	# Two guards 1.5 m apart along the marker's X (and margin): standing capsules fit.
	for offset: float in [-1.5, -0.75, 0.0, 0.75, 1.5]:
		var feet := marker.global_position + marker.global_basis.x * offset
		assert_bool(_capsule_clear(feet)).override_failure_message("offset %s" % offset).is_true()


func test_no_coplanar_faces_with_different_materials() -> void:
	await _load()

	assert_array(KitGeometry.coplanar_material_overlaps(_level)).is_empty()


func test_every_listed_doorway_is_open() -> void:
	await _load()
	var doorways := _level.get_node("LayoutMarkers/Doorways").get_children()
	assert_int(doorways.size()).is_greater(20)
	var world := _level.get_world_3d()
	for marker: Marker3D in doorways:
		var across := marker.global_basis.z
		var along := marker.global_basis.x
		for height: float in [0.3, 1.1, 1.9]:
			for side: float in [-0.35, 0.0, 0.35]:
				var middle := marker.global_position + Vector3.UP * height + along * side
				var hit := KitGeometry.ray(world, middle - across, middle + across)
				var what := "%s at %s/%s: %s" % [marker.name, height, side, hit.get("collider")]
				assert_bool(hit.is_empty()).override_failure_message(what).is_true()


func test_kit_parts_stay_inside_their_metric_bands() -> void:
	var level: Node3D = auto_free(LEVEL.instantiate())
	var warned: PackedStringArray = []
	for node: Node in level.find_children("*", "", true, false):
		if node is KitPart or node is Fence:
			var warnings: PackedStringArray = node.call("_get_configuration_warnings")
			if not warnings.is_empty():
				warned.append("%s: %s" % [level.get_path_to(node), "; ".join(warnings)])
	assert_array(warned).is_empty()


func _load() -> void:
	_level = auto_free(LEVEL.instantiate())
	# The Mission would spawn a player and open the briefing: not needed here.
	_level.get_node("Mission").free()
	add_child(_level)
	await KitGeometry.settle(get_tree(), 5)


func _capsule_clear(feet: Vector3) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.7
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * 0.95)
	query.collision_mask = PhysicsLayers.WORLD
	return _level.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
