extends GdUnitTestSuite
## Integration: debug panel Spawn tab (catalogue spawning, ignite / damage the looked-at object),
## Time tab and the Heat overlay.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const ROOM := "res://tests/objects/fixtures/carry_room.tscn"
const CATALOG: ObjectCatalog = preload("res://objects/object_catalog.tres")
const PHYSICS_FIRE_ROOM := "res://levels/gallery/physics_fire/physics_fire_room.tscn"

var _driver: PlayerDriver


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Engine.time_scale = 1.0
	DebugPanel.heat_overlay.enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_catalog_lists_every_object_with_a_button() -> void:
	var tab := _tab("Spawn") as SpawnTab
	var buttons := tab.get_node("Buttons").get_children()

	assert_int(CATALOG.scenes.size()).is_equal(11)
	assert_int(buttons.size()).is_equal(CATALOG.scenes.size())
	assert_str((buttons[0] as Button).text).is_equal("small crate")
	assert_object(tab.get_node("Actions/Reset")).is_not_null()


func test_spawns_two_metres_in_front_of_the_player() -> void:
	await _load()
	await _driver.place(Vector3(1, 0, 1), PI / 2.0)

	var crate := (_tab("Spawn") as SpawnTab).spawn(CATALOG.scenes[0])

	# Yaw 90 degrees: facing -X.
	assert_vector(crate.global_position).is_equal_approx(Vector3(-1, 0.7, 1), Vector3.ONE * 0.001)
	assert_array(Objects.logged(&"debug.spawned", "object", "SmallCrate")).has_size(1)
	await _driver.frames(60)
	assert_float(crate.global_position.y).is_equal_approx(0.3, 0.05)


func test_ignite_and_damage_the_looked_at_object() -> void:
	await _load()
	var crate := Objects.spawn(_driver.runner.scene(), Objects.SMALL_CRATE, Vector3(0, 0.3, -3))
	await _driver.frames(5)
	_driver.player.load_state(Objects.aiming_state(_driver.player, Vector3.ZERO, crate.global_position))
	await _driver.frames(2)
	var tab := _tab("Spawn") as SpawnTab

	assert_object(tab.damage_looked_at()).is_same(crate)
	await _driver.frames(2)
	assert_float(Breakable.of(crate).health()).is_equal_approx(20.0, 0.0001)

	tab.ignite_looked_at()
	await _driver.frames(2)
	assert_bool(Flammable.of(crate).is_burning()).is_true()


func test_reset_level_reloads_the_physics_fire_room() -> void:
	var tree := get_tree()
	var original := tree.current_scene
	var room: Node3D = (load(PHYSICS_FIRE_ROOM) as PackedScene).instantiate()
	tree.root.add_child(room)
	tree.current_scene = room
	await Objects.frames(tree, 5)
	# Use the room up: a crate burns, one is broken, one is spawned.
	Flammable.of(room.get_node("FireSpread/FireCrate1")).ignite(null)
	Breakable.of(room.get_node("Throwables/TableCrate1")).break_apart(&"destroyed")
	Objects.spawn(room, Objects.CARDBOARD_BOX, Vector3(0, 0.25, -8), "SpawnedBox")
	await Objects.frames(tree, 2)
	var tab := _tab("Spawn") as SpawnTab

	var error := tab.reset_level()
	# The queue is cleared by the reset itself; the reloaded room's objects may queue new stimuli
	# (fire pulses, impact noises) within the frames awaited below.
	var pending_after_reset := StimulusSystem.pending_count()
	await tree.process_frame
	await tree.process_frame

	var fresh := tree.current_scene
	tree.current_scene = original
	auto_free(fresh)
	assert_int(error).is_equal(OK)
	assert_bool(is_instance_valid(room)).is_false()
	assert_str(fresh.scene_file_path).is_equal(PHYSICS_FIRE_ROOM)
	assert_object(fresh.get_node_or_null("Throwables/TableCrate1")).is_not_null()
	assert_bool(Flammable.of(fresh.get_node("FireSpread/FireCrate1")).is_burning()).is_false()
	assert_object(fresh.get_node_or_null("SpawnedBox")).is_null()
	assert_array(Objects.logged(&"debug.reset_level", "scene", PHYSICS_FIRE_ROOM)).has_size(1)
	assert_int(pending_after_reset).is_equal(0)


func test_reset_level_without_a_level_does_nothing() -> void:
	var tree := get_tree()
	var original := tree.current_scene
	tree.current_scene = null

	var error := (_tab("Spawn") as SpawnTab).reset_level()

	tree.current_scene = original
	assert_int(error).is_equal(ERR_UNAVAILABLE)
	assert_array(EventLog.find(&"debug.reset_level")).is_empty()


func test_give_item_adds_one_or_a_full_stack() -> void:
	await _load()
	var tab := _tab("Spawn") as SpawnTab
	var items := tab.get_node("Items")
	var inventory := _driver.player.inventory.inventory
	assert_int(items.get_child_count()).is_equal(ItemCatalog.default().items.size() * 3)

	(items.get_node("GiveLockpick") as Button).pressed.emit()
	(items.get_node("StackPistolAmmo") as Button).pressed.emit()

	assert_int(inventory.count_of(&"lockpick")).is_equal(1)
	assert_int(inventory.count_of(&"pistol_ammo")).is_equal(100)
	assert_array(EventLog.find(&"debug.gave_item")).has_size(2)
	# A 6 x 5 grid holds 30 keycards and no more.
	assert_int(tab.give(ItemCatalog.default().find(&"keycard"), 40)).is_equal(12)


func test_time_tab_sets_and_resets_time_scale() -> void:
	var tab := _tab("Time") as TimeTab

	tab.set_time_scale(0.5)
	assert_float(Engine.time_scale).is_equal(0.5)
	tab.set_time_scale(5.0)
	assert_float(Engine.time_scale).is_equal(2.0)
	(tab.get_node("Row/Reset") as Button).pressed.emit()
	assert_float(Engine.time_scale).is_equal(1.0)
	(tab.get_node("Row/Scale") as HSlider).value = 0.1
	assert_float(Engine.time_scale).is_equal_approx(0.1, 0.0001)


func test_heat_overlay_labels_flammables() -> void:
	await _load()
	var crate := Objects.spawn(_driver.runner.scene(), Objects.SMALL_CRATE, Vector3(0, 0.3, -3))
	var barrel := Objects.spawn(_driver.runner.scene(), Objects.EXPLOSIVE_BARREL, Vector3(3, 0.45, -3))
	await _driver.frames(3)
	var overlay := DebugPanel.heat_overlay
	var checkbox := _tab("Overlays").get_node("Heat") as CheckBox

	checkbox.button_pressed = true
	overlay.refresh()
	assert_bool(overlay.enabled).is_true()
	assert_int(overlay.label_count()).is_equal(2)
	assert_str(overlay.label_for(Flammable.of(crate)).text).is_equal("heat 0.0 / 6.0")
	assert_str(overlay.label_for(Explosive.of(barrel)).text).contains("/ 4.0")

	Flammable.of(crate).ignite(null)
	overlay.refresh()
	assert_str(overlay.label_for(Flammable.of(crate)).text).starts_with("BURNING  fuel 20.0")

	checkbox.button_pressed = false
	assert_int(overlay.label_count()).is_equal(0)


func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(ROOM))
	await _driver.settle()


func _tab(title: String) -> Control:
	var tabs: TabContainer = DebugPanel.get_node("TabContainer")
	for i in tabs.get_tab_count():
		if tabs.get_tab_title(i) == title:
			return tabs.get_tab_control(i)
	return null
