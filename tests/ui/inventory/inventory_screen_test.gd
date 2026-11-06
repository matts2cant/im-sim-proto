extends GdUnitTestSuite
## Integration: the inventory screen (I opens / pauses / frees the mouse, I or Esc closes), mouse
## drag-and-drop on the grid and belt (events sent to the InventoryView like the viewport would:
## headless GUI does not route pushed mouse events), the context menu (Use, Split, Drop, belt),
## hover + belt key, and the datapad reading overlay.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const Items := preload("res://tests/items/item_test_helpers.gd")
const ROOM := "res://tests/objects/fixtures/carry_room.tscn"

var _driver: PlayerDriver
var _player: Player
var _screen: InventoryScreen
var _view: InventoryView


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	PauseScreens.reset(get_tree())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_inventory_key_opens_pauses_and_closes() -> void:
	await _load()

	await _press(&"inventory")
	assert_bool(_screen.is_open()).is_true()
	assert_bool(_screen.visible).is_true()
	assert_bool(get_tree().paused).is_true()
	assert_int(Input.mouse_mode).is_equal(Input.MOUSE_MODE_VISIBLE)
	# Paused: the player does not move.
	var start := _player.global_position
	await _driver.hold(&"move_forward", 10)
	assert_float(_player.global_position.distance_to(start)).is_less(0.001)

	await _press(&"inventory")
	assert_bool(_screen.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()

	await _press(&"inventory")
	await _press(&"ui_cancel")
	assert_bool(_screen.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()


func test_does_not_open_while_dead() -> void:
	await _load()
	_player.body.take_damage(&"damage.ballistic", 30.0, &"head")

	await _press(&"inventory")

	assert_bool(_screen.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()


func test_drag_moves_a_stack_with_a_fit_check() -> void:
	await _load()
	_player.inventory.give(Items.PISTOL, 1)
	_player.inventory.give(Items.BATON, 1)
	var pistol := _player.inventory.inventory.stacks[0]
	var baton := _player.inventory.inventory.stacks[1]
	await _open()

	# Grab the pistol by its right cell and drop that cell on (4, 3): the pistol lands at (3, 3).
	_drag(_view.cell_center(Vector2i(1, 0)), _view.cell_center(Vector2i(4, 3)))
	assert_vector(pistol.cell).is_equal(Vector2i(3, 3))
	# Onto the baton (2, 0..2): refused, nothing moves.
	_drag(_view.cell_center(Vector2i(3, 3)), _view.cell_center(Vector2i(2, 1)))
	assert_vector(pistol.cell).is_equal(Vector2i(3, 3))
	# Partly out of the grid: refused.
	_drag(_view.cell_center(Vector2i(3, 3)), _view.cell_center(Vector2i(5, 3)))
	assert_vector(pistol.cell).is_equal(Vector2i(3, 3))
	assert_vector(baton.cell).is_equal(Vector2i(2, 0))


func test_drag_preview_is_green_or_red() -> void:
	await _load()
	_player.inventory.give(Items.PISTOL, 1)
	_player.inventory.give(Items.BATON, 1)
	await _open()

	_view._gui_input(_button(MOUSE_BUTTON_LEFT, true, _view.cell_center(Vector2i(0, 0))))
	_view._gui_input(_motion(_view.cell_center(Vector2i(2, 1))))
	assert_object(_view.dragging()).is_same(_player.inventory.inventory.stacks[0])
	var inventory := _player.inventory.inventory
	assert_bool(inventory.can_place(Vector2i(2, 1), Vector2i(2, 1), _view.dragging())).is_false()
	assert_bool(inventory.can_place(Vector2i(2, 1), Vector2i(0, 4), _view.dragging())).is_true()
	_view._gui_input(_button(MOUSE_BUTTON_LEFT, false, _view.cell_center(Vector2i(0, 4))))
	assert_object(_view.dragging()).is_null()
	assert_vector(inventory.stacks[0].cell).is_equal(Vector2i(0, 4))


func test_drag_to_a_belt_slot_assigns_and_off_the_belt_clears() -> void:
	await _load()
	_player.inventory.give(Items.AMMO, 40)
	var ammo := _player.inventory.inventory.stacks[0]
	await _open()

	_drag(_view.cell_center(Vector2i(0, 0)), _view.belt_slot_rect(4).get_center())
	assert_int(_player.inventory.belt.slot_of(ammo)).is_equal(4)
	_drag(_view.belt_slot_rect(4).get_center(), _view.belt_slot_rect(6).get_center())
	assert_int(_player.inventory.belt.slot_of(ammo)).is_equal(6)
	_drag(_view.belt_slot_rect(6).get_center(), _view.cell_center(Vector2i(3, 3)))
	assert_int(_player.inventory.belt.slot_of(ammo)).is_equal(-1)
	assert_vector(ammo.cell).is_equal(Vector2i(0, 0))


func test_drag_out_of_the_panel_drops_into_the_world() -> void:
	await _load()
	_player.inventory.give(Items.LOCKPICK, 4)
	await _open()

	_drag(_view.cell_center(Vector2i(0, 0)), Vector2(-120, 40))

	assert_array(_player.inventory.inventory.stacks).is_empty()
	var dropped := EventLog.find(&"item.dropped")
	assert_array(dropped).has_size(1)
	assert_int(dropped[0].data["count"]).is_equal(4)
	var body := _driver.runner.scene().find_child("Lockpick", false, false) as RigidBody3D
	assert_int(ItemPickup.of(body).count).is_equal(4)


func test_right_click_menu_use_heals() -> void:
	await _load()
	_player.inventory.give(Items.MEDKIT, 3)
	_player.body.take_damage(&"damage.blunt", 40.0, &"torso")
	await _open()

	_view._gui_input(_button(MOUSE_BUTTON_RIGHT, true, _view.cell_center(Vector2i(0, 0))))
	await _driver.frames(1)

	assert_str(_screen.menu.get_item_text(0)).is_equal("Use")
	assert_str(_screen.menu.get_item_text(1)).is_equal("Drop")
	assert_str(_screen.menu.get_item_text(2)).is_equal("Split stack")
	_screen.choose(InventoryScreen.MENU_USE)
	assert_array(EventLog.find(&"actor.healed")).has_size(1)
	assert_int(_player.inventory.inventory.count_of(&"medkit")).is_equal(2)
	assert_bool(_screen.is_open()).is_true()


func test_menu_split_and_assign() -> void:
	await _load()
	_player.inventory.give(Items.AMMO, 41)
	await _open()
	var ammo := _player.inventory.inventory.stacks[0]
	_screen.show_menu(ammo, Vector2(300, 200))

	_screen.choose(InventoryScreen.MENU_SPLIT)
	_screen.choose(InventoryScreen.MENU_BELT + 9)

	assert_int(ammo.count).is_equal(21)
	assert_int(_player.inventory.inventory.stacks[1].count).is_equal(20)
	assert_int(_player.inventory.belt.slot_of(ammo)).is_equal(9)


func test_hover_and_belt_key_assigns() -> void:
	await _load()
	_player.inventory.give(Items.KEYCARD, 1, {"key_id": "office"})
	await _open()

	_view._gui_input(_motion(_view.cell_center(Vector2i(0, 0))))
	await _press(&"belt_3")

	assert_object(_player.inventory.belt.stack_in(2)).is_same(_player.inventory.inventory.stacks[0])
	assert_str(InventoryView.tooltip_text(_player.inventory.inventory.stacks[0])).contains("Key: office")


func test_datapad_opens_the_reading_overlay_over_the_inventory() -> void:
	await _load()
	_player.inventory.give(Items.DATAPAD, 1, {"title": "Shift notes", "text": "Code: 0451"})
	var overlay := _player.get_node("ReadingOverlay") as ReadingOverlay
	await _open()

	_screen.show_menu(_player.inventory.inventory.stacks[0], Vector2(300, 200))
	assert_str(_screen.menu.get_item_text(0)).is_equal("Read")
	_screen.choose(InventoryScreen.MENU_USE)

	assert_bool(overlay.is_open()).is_true()
	assert_str(overlay.title_label.text).is_equal("Shift notes")
	assert_str(overlay.text_label.text).is_equal("Code: 0451")
	await _press(&"ui_cancel")
	assert_bool(overlay.is_open()).is_false()
	assert_bool(_screen.is_open()).is_true()
	assert_bool(get_tree().paused).is_true()
	await _press(&"ui_cancel")
	assert_bool(get_tree().paused).is_false()


func test_datapad_from_the_belt_reads_and_e_closes() -> void:
	await _load()
	_player.inventory.give(Items.DATAPAD, 1, {"title": "Memo", "text": "Hello"})
	_player.inventory.belt.assign(0, _player.inventory.inventory.stacks[0])
	var overlay := _player.get_node("ReadingOverlay") as ReadingOverlay
	var medkit := Items.spawn_pickup(_driver.runner.scene(), Items.MEDKIT, Vector3(0, 0.05, -0.9))
	await _driver.frames(20)
	_player.load_state(Objects.aiming_state(_player, Vector3.ZERO, medkit.global_position))
	await _driver.frames(3)
	assert_str(_player.interactor.prompt).is_equal("E: pick up Medkit")

	await _press(&"belt_1")
	assert_bool(overlay.is_open()).is_true()
	assert_bool(get_tree().paused).is_true()

	await _press(&"use")
	assert_bool(overlay.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()
	# The E that closed it is not also a pick-up press.
	await _driver.frames(3)
	assert_bool(is_instance_valid(medkit)).is_true()
	assert_int(_player.inventory.inventory.count_of(&"medkit")).is_equal(0)


func _drag(from: Vector2, to: Vector2) -> void:
	_view._gui_input(_button(MOUSE_BUTTON_LEFT, true, from))
	_view._gui_input(_motion(to))
	_view._gui_input(_button(MOUSE_BUTTON_LEFT, false, to))


static func _button(index: MouseButton, pressed: bool, at: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = index
	event.pressed = pressed
	event.position = at
	return event


static func _motion(at: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = at
	return event


func _open() -> void:
	await _press(&"inventory")
	assert_bool(_screen.is_open()).is_true()


func _press(action: StringName) -> void:
	await _driver.hold(action, 2)
	await _driver.frames(1)


func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(ROOM))
	_player = _driver.player
	_screen = _player.get_node("InventoryScreen") as InventoryScreen
	_view = _screen.view
	await _driver.settle()
	await _driver.place(Vector3.ZERO)
