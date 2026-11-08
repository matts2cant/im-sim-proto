extends GdUnitTestSuite
## Scenario: an explosive barrel goes off. Fixture (two rooms split by a wall with a doorway, navmesh
## baked here): barrel A, barrel B 2 m away, crates 1.8 m away, a listener in the next room.
## Expected: crates ignite on the next tick (fire burst 20 / 3 m: 8.0 at 1.8 m >= 6), barrel B
## chain-explodes on the next tick, the listener hears the 60 m noise along the path round the wall.

const Objects := preload("res://tests/objects/object_test_helpers.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const GuardHelpers := preload("res://tests/actors/guard/guard_helpers.gd")
const FIXTURE := "res://tests/scenarios/fixtures/barrel_chain.tscn"
const LISTENER := Vector3(3, 0.5, -3)

var _scene: Node3D
var _map_was_async: bool = true


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_scene = auto_free(load(FIXTURE).instantiate())
	add_child(_scene)
	_map_was_async = NavigationServer3D.map_get_use_async_iterations(_map())
	var region: NavigationRegion3D = _scene.get_node("Rooms/NavigationRegion")
	await GuardHelpers.use_sync_iterations(_map(), region)
	region.navigation_mesh = region.navigation_mesh.duplicate() as NavigationMesh
	region.bake_navigation_mesh(false)
	await Objects.frames(get_tree(), 5)


func after_test() -> void:
	NavigationServer3D.map_set_use_async_iterations(_map(), _map_was_async)


func test_explosion_ignites_crates_chains_barrel_and_is_heard_round_the_corner() -> void:
	var listener := Fixtures.entity(_scene, "Listener", LISTENER, [Fixtures.receptron(&"noise")])
	await Objects.frames(get_tree(), 2)
	EventLog.clear()
	var spark := Stimulus.make_contact(&"fire", 100.0, _scene.get_node("BarrelA"))

	StimulusSystem.emit(spark)
	await Objects.frames(get_tree(), 6)

	var a: EventLogEntry = Objects.logged(&"object.exploded", "object", "BarrelA")[0]
	assert_int(a.data["by"]).is_equal(spark.id)
	var b := Objects.logged(&"object.exploded", "object", "BarrelB")
	assert_array(b).has_size(1)
	assert_int(b[0].tick).is_equal(a.tick + 1)
	for crate: String in ["Crate1", "Crate2"]:
		var ignited := Objects.logged(&"object.ignited", "object", crate)
		assert_array(ignited).has_size(1)
		assert_int(ignited[0].tick).is_equal(a.tick + 1)
		# Ignited by barrel A's fire burst, a child of the spark.
		var burst := Objects.emitted(ignited[0].data["by"])
		assert_str(burst.source).is_equal("BarrelA")
		assert_int(burst.data["cause_id"]).is_equal(spark.id)
		# Wood takes explosive damage x0.5: about 100 x (1 - 1.8 / 4) x 0.5 = 27.5 < 30 from barrel A
		# (the blast impulse has already pushed it a little); barrel B may finish it off later.
		var blast := EventLog.find(&"object.damaged").filter(
			func(entry: EventLogEntry) -> bool: return entry.target == crate and entry.source == "BarrelA"
		)
		assert_float(blast[0].data["amount"]).is_between(25.0, 28.0)
		assert_int(blast[0].tick).is_equal(a.tick + 1)
	assert_bool(is_instance_valid(_scene.get_node_or_null("BarrelA"))).is_false()
	assert_bool(is_instance_valid(_scene.get_node_or_null("BarrelB"))).is_false()

	var heard := EventLog.find(&"stimulus.received").filter(
		func(entry: EventLogEntry) -> bool: return entry.target == "Listener" and entry.source == "BarrelA"
	)
	assert_array(heard).has_size(1)
	assert_str(heard[0].data["propagation"]).is_equal("path")
	var straight := Vector3(-5, 0.45, -2).distance_to(LISTENER)
	assert_float(heard[0].data["distance"]).is_greater(straight + 5.0)
	assert_object(listener).is_not_null()


func _map() -> RID:
	return get_tree().root.find_world_3d().navigation_map
