extends GdUnitTestSuite
## Integration: LevelSnapshot on the physics & fire gallery room: what is captured as removed and
## spawned, and restoring a snapshot onto a fresh instance of the room.

const Wait := preload("res://tests/helpers/wait.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const ROOM := "res://levels/gallery/physics_fire/physics_fire_room.tscn"
const CRATE := "BarricadeRoom/SideRoomCrate"


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	StimulusSystem.clear()


func _room() -> Node3D:
	var room: Node3D = auto_free((load(ROOM) as PackedScene).instantiate())
	get_tree().root.add_child(room)
	await Wait.frames(get_tree(), 5)
	return room


func test_packed_index_lists_the_scene_and_its_saveable_entities() -> void:
	var index := LevelSnapshot.packed_index(ROOM)

	assert_str(index.scenes[CRATE]).is_equal(Objects.SMALL_CRATE)
	assert_str(index.scenes["BarricadeRoom"]).is_equal("")
	assert_array(index.saveable_roots).contains([CRATE, CRATE + "/Flammable", "BarricadeRoom"])
	assert_array(index.saveable_roots).not_contains(["Lights", "Labels"])


func test_capture_lists_removed_and_spawned_entities() -> void:
	var room := await _room()
	# Two bottles fall out of the side room crate; debris is not saved.
	Breakable.of(room.get_node(CRATE)).break_apart(&"destroyed")
	Objects.spawn(room, Objects.CARDBOARD_BOX, Vector3(0, 0.25, -8), "SpawnedBox")
	Flammable.of(room.get_node("FireSpread/FireCrate1")).ignite(null)

	var snapshot := LevelSnapshot.capture(room)

	assert_array(snapshot["removed"]).contains_exactly([CRATE])
	var spawned: Dictionary = snapshot["spawned"]
	assert_str(spawned["SpawnedBox"]).is_equal(Objects.CARDBOARD_BOX)
	var bottles := spawned.keys().filter(func(path: String) -> bool: return path.begins_with("BarricadeRoom/"))
	assert_int(bottles.size()).is_equal(2)
	for path: String in bottles:
		assert_str(spawned[path]).is_equal(Objects.GLASS_BOTTLE)
	var states: Dictionary = snapshot["states"]
	assert_int(states["FireSpread/FireCrate1/Flammable"]["state"]).is_equal(Flammable.State.BURNING)
	assert_bool(states.has(CRATE)).is_false()
	assert_bool(states.has("SpawnedBox")).is_true()


func test_apply_restores_removed_spawned_and_states_on_a_fresh_room() -> void:
	var room := await _room()
	Breakable.of(room.get_node(CRATE)).break_apart(&"destroyed")
	var box := Objects.spawn(room, Objects.CARDBOARD_BOX, Vector3(0, 0.25, -8), "SpawnedBox")
	Flammable.of(room.get_node("FireSpread/FireCrate1")).ignite(null)
	await Wait.frames(get_tree(), 3)
	var snapshot := LevelSnapshot.capture(room)
	var box_transform := box.global_transform
	room.free()
	var fresh := await _room()

	var report := LevelSnapshot.apply(fresh, snapshot)

	assert_array(report.skipped).is_empty()
	assert_bool(report.geometry_removed).is_false()
	assert_object(fresh.get_node_or_null(CRATE)).is_null()
	var restored := fresh.get_node_or_null("SpawnedBox") as Node3D
	assert_object(restored).is_not_null()
	assert_str(restored.scene_file_path).is_equal(Objects.CARDBOARD_BOX)
	assert_bool(restored.global_transform.is_equal_approx(box_transform)).is_true()
	for path: String in snapshot["spawned"]:
		assert_object(fresh.get_node_or_null(path)).is_not_null()
	assert_bool(Flammable.of(fresh.get_node("FireSpread/FireCrate1")).is_burning()).is_true()
	# A second capture of the restored room matches the first.
	var again := LevelSnapshot.capture(fresh)
	assert_array(again["removed"]).is_equal(snapshot["removed"])
	assert_array((again["spawned"] as Dictionary).keys()).contains_exactly_in_any_order(
		(snapshot["spawned"] as Dictionary).keys()
	)


func test_removing_the_barricade_reports_removed_geometry() -> void:
	var room := await _room()
	Breakable.of(room.get_node("BarricadeRoom/Barricade")).break_apart(&"burnt_out")
	var snapshot := LevelSnapshot.capture(room)
	room.free()
	var fresh := await _room()

	var report := LevelSnapshot.apply(fresh, snapshot)

	assert_array(snapshot["removed"]).contains(["BarricadeRoom/Barricade"])
	assert_bool(report.geometry_removed).is_true()
	assert_object(fresh.get_node_or_null("BarricadeRoom/Barricade")).is_null()


func test_a_spawned_node_with_a_removed_node_name_is_saved_as_spawned() -> void:
	var room := await _room()
	room.get_node("FireSpread/FireCrate1").free()
	Objects.spawn(room.get_node("FireSpread"), Objects.CARDBOARD_BOX, Vector3(0, 0.25, -8), "FireCrate1")
	# ImpactNoise adds its player deferred: let it, or freeing the room orphans it.
	await Wait.frames(get_tree(), 1)

	var snapshot := LevelSnapshot.capture(room)
	room.free()
	var fresh := await _room()
	LevelSnapshot.apply(fresh, snapshot)

	assert_array(snapshot["removed"]).contains(["FireSpread/FireCrate1"])
	assert_str((snapshot["spawned"] as Dictionary)["FireSpread/FireCrate1"]).is_equal(Objects.CARDBOARD_BOX)
	assert_str(fresh.get_node("FireSpread/FireCrate1").scene_file_path).is_equal(Objects.CARDBOARD_BOX)


func test_paths_missing_from_the_level_are_skipped() -> void:
	var room := await _room()
	var snapshot := {
		"states": {"Nowhere/Thing": {"x": 1}},
		"removed": ["Gone"],
		"spawned": {"Nowhere/Box": Objects.CARDBOARD_BOX, "Ghost": "res://does_not_exist.tscn"},
	}

	var report := LevelSnapshot.apply(room, snapshot)

	assert_array(report.skipped).contains_exactly_in_any_order(["Nowhere/Thing", "Gone", "Nowhere/Box", "Ghost"])
	assert_object(room.get_node_or_null("Ghost")).is_null()
