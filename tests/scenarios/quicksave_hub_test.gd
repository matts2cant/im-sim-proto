extends GdUnitTestSuite
## Scenario: quicksave and quickload on the real hub (the current scene). Change many systems, save,
## change them all again, load: everything is back as saved (a capture of the loaded level matches
## the saved one), removed things stay gone, spawned things are back, nothing is queued.
## Also: real F5 / F9 key presses, and a carried object lands where it was held.

const Saves := preload("res://tests/core/save/save_test_helpers.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const Items := preload("res://tests/items/item_test_helpers.gd")
const HUB := "res://levels/hub/hub.tscn"
const CARRY_ROOM := "res://tests/objects/fixtures/carry_room.tscn"
const CATALOG: ObjectCatalog = preload("res://objects/object_catalog.tres")
const FIRE := "PhysicsFireRoom/FireSpread/FireCrate1"
const BURNT := "PhysicsFireRoom/Throwables/TableCrate2"
const BROKEN := "PhysicsFireRoom/BarricadeRoom/SideRoomCrate"
const BARRICADE := "PhysicsFireRoom/BarricadeRoom/Barricade"
const DATAPAD := "InventoryBayRoom/DatapadPedestal/Datapad/Readable"
const OTHER_DATAPAD := "InventoryBayRoom/DatapadPedestal/StorageAccess/Readable"
const SAVED_SPOT := Vector3(1.0, 0.0, 8.0)

var _original: Node


func before_test() -> void:
	_original = get_tree().current_scene
	Saves.use_test_slot()
	EventLog.clear()
	StimulusSystem.clear()
	DebugPanel.set_open(false)


func after_test() -> void:
	Saves.close_level(get_tree(), _original)
	StimulusSystem.clear()


func _player(level: Node) -> Player:
	return level.get_node("Player") as Player


func _spawn_tab() -> SpawnTab:
	var tabs: TabContainer = DebugPanel.get_node("TabContainer")
	for i in tabs.get_tab_count():
		if tabs.get_tab_title(i) == "Spawn":
			return tabs.get_tab_control(i) as SpawnTab
	return null


func _frames(count: int) -> void:
	await Objects.frames(get_tree(), count)


func _read(level: Node, readable_path: String) -> void:
	(level.get_node(readable_path) as Readable).use(_player(level))
	(_player(level).get_node("ReadingOverlay") as ReadingOverlay).close()


func test_hub_round_trip_restores_what_was_saved() -> void:
	var hub := await Saves.open_level(get_tree(), HUB)
	var player := _player(hub)
	var nav := hub.get_node("Navigation") as NavigationRegion3D
	var nav_vertices := nav.navigation_mesh.get_vertices().size()
	# Player: moved, hurt, items (one in hand), a datapad read.
	player.load_state({"position": SAVED_SPOT, "yaw": 1.0, "pitch": -0.2, "velocity": Vector3.ZERO})
	player.body.take_damage(&"damage.blunt", 20.0, &"arm_l")
	player.inventory.give(Items.MEDKIT, 2)
	player.inventory.give(Items.MULTITOOL, 1)
	player.inventory.give(Items.BIOCELL, 3)
	player.inventory.hold(player.inventory.inventory.stacks[1])
	_read(hub, DATAPAD)
	# Objects: one crate burning, one burnt out, one broken (two bottles fall out), the barricade
	# burnt (level geometry), an item dropped, a crate spawned from the debug panel.
	Flammable.of(hub.get_node(FIRE)).ignite(null)
	var burnt := Flammable.of(hub.get_node(BURNT))
	burnt.ignite(null)
	burnt.burn_out()
	Breakable.of(hub.get_node(BROKEN)).break_apart(&"destroyed")
	Breakable.of(hub.get_node(BARRICADE)).break_apart(&"burnt_out")
	var dropped := player.inventory.drop_stack(player.inventory.inventory.stacks[2], 2)
	var spawned := _spawn_tab().spawn(CATALOG.scenes[0])
	await _frames(10)

	var saved_position := player.global_position
	assert_int(QuickSave.save_game(get_tree())).is_equal(SaveFile.Status.OK)
	var saved := SaveFile.read(Saves.SLOT).data
	var dropped_path := String(hub.get_path_to(dropped))
	var spawned_path := String(hub.get_path_to(spawned))

	# Change everything again.
	player.load_state({"position": Vector3(-3, 0, 12), "yaw": -1.0, "pitch": 0.0, "velocity": Vector3.ZERO})
	player.body.take_damage(&"damage.blunt", 30.0, &"leg_r")
	player.inventory.give(Items.KEYCARD, 1)
	player.inventory.put_away()
	_read(hub, OTHER_DATAPAD)
	Breakable.of(hub.get_node("PhysicsFireRoom/Throwables/TableCrate1")).break_apart(&"destroyed")
	Flammable.of(hub.get_node("PhysicsFireRoom/BrazierCorner/BrazierBox1")).ignite(null)
	dropped.free()
	spawned.free()
	await _frames(5)

	var status: SaveFile.Status = await QuickSave.load_game(get_tree())
	var fresh := get_tree().current_scene

	assert_int(status).is_equal(SaveFile.Status.OK)
	assert_object(fresh).is_not_same(hub)
	assert_int(StimulusSystem.pending_count()).is_equal(0)
	assert_bool(get_tree().paused).is_false()
	# Every saved state is back (floats within tolerance), and removed / spawned match.
	var loaded := LevelSnapshot.capture(fresh)
	var differences: Array[String] = []
	var saved_states: Dictionary = saved["states"]
	var loaded_states: Dictionary = loaded["states"]
	for path: String in saved_states:
		var difference := Saves.difference(saved_states[path], loaded_states.get(path), path)
		if not difference.is_empty():
			differences.append(difference)
	assert_array(differences).is_empty()
	assert_array(loaded_states.keys()).contains_exactly_in_any_order(saved_states.keys())
	assert_array(loaded["removed"]).contains_exactly_in_any_order(saved["removed"])
	assert_array((loaded["spawned"] as Dictionary).keys()).contains_exactly_in_any_order(
		(saved["spawned"] as Dictionary).keys()
	)
	# The same, spelled out.
	var restored := _player(fresh)
	assert_vector(restored.global_position).is_equal_approx(saved_position, Vector3.ONE * 0.001)
	assert_float(restored.body.health(&"arm_l")).is_less(restored.body.model.max_health(&"arm_l"))
	assert_float(restored.body.health(&"leg_r")).is_equal(restored.body.model.max_health(&"leg_r"))
	assert_int(restored.inventory.inventory.count_of(&"medkit")).is_equal(2)
	assert_int(restored.inventory.inventory.count_of(&"biocell")).is_equal(1)
	assert_int(restored.inventory.inventory.count_of(&"keycard")).is_equal(0)
	assert_str(String(restored.inventory.in_hand().item.id)).is_equal("multitool")
	var reader_log := PersonalLog.of(restored)
	assert_bool(reader_log.has(&"gallery.inventory_bay.note")).is_true()
	assert_bool(reader_log.has(&"gallery.inventory_bay.storage_access")).is_false()
	assert_bool(Flammable.of(fresh.get_node(FIRE)).is_burning()).is_true()
	assert_bool(Flammable.of(fresh.get_node("PhysicsFireRoom/BrazierCorner/BrazierBox1")).is_burning()).is_false()
	for path: String in [BURNT, BROKEN, BARRICADE]:
		assert_object(fresh.get_node_or_null(path)).override_failure_message(path + " came back").is_null()
	assert_object(fresh.get_node_or_null("PhysicsFireRoom/Throwables/TableCrate1")).is_not_null()
	var pickup := fresh.get_node_or_null(dropped_path)
	assert_object(pickup).is_not_null()
	assert_int(ItemPickup.of(pickup).count).is_equal(2)
	assert_object(fresh.get_node_or_null(spawned_path)).is_not_null()
	# The burnt barricade left the navmesh rebaked without it.
	var fresh_nav := fresh.get_node("Navigation") as NavigationRegion3D
	assert_int(fresh_nav.navigation_mesh.get_vertices().size()).is_not_equal(nav_vertices)
	var loaded_entries := EventLog.find(&"game.loaded")
	assert_array(loaded_entries).has_size(1)
	assert_int(loaded_entries[0].data["skipped"]).is_equal(0)


func test_f5_and_f9_keys_on_the_hub() -> void:
	var hub := await Saves.open_level(get_tree(), HUB)
	_player(hub).load_state({"position": SAVED_SPOT, "yaw": 0.3, "pitch": 0.0, "velocity": Vector3.ZERO})
	await _frames(3)
	var saved := _player(hub).global_position

	Saves.press(KEY_F5)
	await get_tree().process_frame
	assert_str((_player(hub).get_node("Hud") as Hud).message_label.text).is_equal(QuickSaveKeys.SAVED)
	_player(hub).load_state({"position": Vector3(-3, 0, 12), "yaw": 0.0, "pitch": 0.0, "velocity": Vector3.ZERO})
	await _frames(3)
	Saves.press(KEY_F9)
	var fresh := await Saves.wait_for_load(get_tree(), hub)

	assert_object(fresh).is_not_null()
	assert_vector(_player(fresh).global_position).is_equal_approx(saved, Vector3.ONE * 0.01)
	assert_float(_player(fresh).rotation.y).is_equal_approx(0.3, 0.001)
	assert_str((_player(fresh).get_node("Hud") as Hud).message_label.text).is_equal(QuickSaveKeys.LOADED)


func test_a_carried_object_is_dropped_where_it_was_held() -> void:
	var room := await Saves.open_level(get_tree(), CARRY_ROOM)
	var player := _player(room)
	player.load_state({"position": Vector3.ZERO, "yaw": 0.0, "pitch": 0.0, "velocity": Vector3.ZERO})
	var crate := Objects.spawn(room, Objects.SMALL_CRATE, Vector3(0, 0.3, -1.5), "Crate")
	await _frames(5)
	player.carry.pick_up(crate)
	await _frames(10)
	assert_bool(player.carry.is_carrying()).is_true()
	var held := crate.global_position
	assert_int(QuickSave.save_game(get_tree())).is_equal(SaveFile.Status.OK)
	player.carry.drop()
	player.load_state({"position": Vector3(2, 0, 0), "yaw": 0.0, "pitch": 0.0, "velocity": Vector3.ZERO})

	await QuickSave.load_game(get_tree())
	var fresh := get_tree().current_scene
	var restored := fresh.get_node("Crate") as RigidBody3D
	var fresh_player := _player(fresh)

	assert_bool(fresh_player.carry.is_carrying()).is_false()
	assert_vector(restored.global_position).is_equal_approx(held, Vector3.ONE * 0.01)
	await _frames(40)
	# It fell in front of the player, clear of the capsule (radius 0.35 m, crate half-size 0.3 m).
	var offset := restored.global_position - fresh_player.global_position
	assert_float(Vector2(offset.x, offset.z).length()).is_greater(0.65)
	assert_float(restored.global_position.y).is_equal_approx(0.3, 0.05)
