extends GdUnitTestSuite
## Warehouse sightlines (design/levels/mission-warehouse.md "Sightlines"): from the water tower perch
## (eyes 1.65 m above its deck) the yard is in clear view over the fence and down through the
## skylights at guards on the catwalks or the floor; inside the hall the long sniper lines (north catwalk,
## bridge, aisle) are clear. Rays use the world layer (geometry and the palisade fence's bars).

const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const Helpers := preload("res://tests/levels/mission/warehouse_helpers.gd")
const LEVEL: PackedScene = preload("res://levels/mission/warehouse.tscn")
## Standing at the deck's west railing (x 42). Targets right below the tower (the east yard) are
## steeply below the railing; the tests cover the yard beyond them.
const PERCH_EYE := Vector3(42.45, 21.65, -16.0)
## Chest height of a standing target.
const CHEST := 1.3
const YARD_TARGETS: Dictionary[String, Vector3] = {
	"gate booth door": Vector3(-8.5, CHEST, -22.0),
	"yard west": Vector3(-14.0, CHEST, -18.0),
	"forklift": Vector3(-11.5, CHEST, -13.5),
	"dock door 2 east": Vector3(8.0, CHEST, -14.0),
	"yard north-east": Vector3(14.0, CHEST, -20.0),
	"fire escape": Vector3(23.0, CHEST, 2.0),
}
## Height of the targets seen through skylights: a guard's chest on the catwalks (4.5 m).
const CATWALK_CHEST := 5.8
const SNIPER_LINES: Dictionary[String, Array] = {
	"north catwalk": [Vector3(-19.0, 6.1, -9.25), Vector3(17.0, 6.1, -9.25)],
	"bridge": [Vector3(-18.0, 6.1, 6.0), Vector3(7.5, 6.1, 6.0)],
	"aisle R1-R2": [Vector3(-9.0, CHEST, -9.0), Vector3(-9.0, CHEST, 13.0)],
	"west aisle": [Vector3(-16.0, CHEST, -8.0), Vector3(-16.0, CHEST, 11.5)],
}

var _level: Node3D


func test_water_tower_sees_the_yard() -> void:
	await _load()
	var blocked: PackedStringArray = []
	for target: String in YARD_TARGETS:
		var hit := KitGeometry.ray(_level.get_world_3d(), PERCH_EYE, YARD_TARGETS[target])
		if not hit.is_empty():
			blocked.append("%s: %s" % [target, hit["collider"]])
	assert_array(blocked).is_empty()


func test_water_tower_sees_into_the_hall_through_skylights() -> void:
	await _load()
	var seen: PackedStringArray = []
	var hall := AABB(Vector3(-20, 0, -10), Vector3(40, 9, 25))
	for skylight: Node in _level.get_node("Hall/Shell/Hall").get_children():
		if not skylight.name.begins_with("Skylight"):
			continue
		var cut := skylight as CSGBox3D
		var centre := (_level.get_node("Hall/Shell/Hall") as Node3D).to_global(cut.position)
		centre.y = 9.25
		var direction := (centre - PERCH_EYE).normalized()
		for height: float in [CATWALK_CHEST, CHEST]:
			var target := PERCH_EYE + direction * ((PERCH_EYE.y - height) / -direction.y)
			if hall.has_point(target) and KitGeometry.ray(_level.get_world_3d(), PERCH_EYE, target).is_empty():
				seen.append("%s at %.1f m" % [skylight.name, height])
	# The perch looks down through several skylights at guards on the catwalks or the floor.
	assert_int(seen.size()).override_failure_message(str(seen)).is_greater_equal(3)


func test_long_sniper_lines_inside_the_hall_are_clear() -> void:
	await _load()
	var blocked: PackedStringArray = []
	for line: String in SNIPER_LINES:
		var ends: Array = SNIPER_LINES[line]
		var hit := KitGeometry.ray(_level.get_world_3d(), ends[0], ends[1])
		if not hit.is_empty():
			blocked.append("%s: %s at %s" % [line, hit["collider"], hit["position"]])
	assert_array(blocked).is_empty()


func _load() -> void:
	_level = auto_free(LEVEL.instantiate())
	_level.get_node("Mission").free()
	# The geometry's lines: guards standing in them (wave 2's population) are what they are for.
	Helpers.strip_population(_level)
	add_child(_level)
	await KitGeometry.settle(get_tree(), 5)
