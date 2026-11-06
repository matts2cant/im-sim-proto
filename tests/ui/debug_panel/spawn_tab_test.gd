extends GdUnitTestSuite
## Integration: debug panel Spawn tab (catalogue spawning, ignite / damage the looked-at object),
## Time tab and the Heat overlay.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const ROOM := "res://tests/objects/fixtures/carry_room.tscn"
const CATALOG: ObjectCatalog = preload("res://objects/object_catalog.tres")

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

	assert_int(CATALOG.scenes.size()).is_equal(8)
	assert_int(buttons.size()).is_equal(CATALOG.scenes.size())
	assert_str((buttons[0] as Button).text).is_equal("small crate")


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
