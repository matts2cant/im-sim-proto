extends GdUnitTestSuite
## Integration (ADR 0110): the Inventory tab of the Tab interface. Mouse drag-and-drop on the grid and
## belt (events sent to the InventoryView like the viewport would: headless GUI does not route pushed
## mouse events), click to select, the right-click menu (Use, Drop, Split, belt), and the actions
## (Use while the world runs, Drop, the belt-slot picker). The details panel: inventory_details_test.gd.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Items := preload("res://tests/items/item_test_helpers.gd")
const ROOM := "res://tests/objects/fixtures/carry_room.tscn"

var _driver: PlayerDriver
var _player: Player
var _tabs: TabInterface
var _tab: InventoryTab
var _view: InventoryView


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	PauseScreens.reset(get_tree())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


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


func test_drag_out_of_the_view_drops_into_the_world() -> void:
	await _load()
	_player.inventory.give(Items.LOCKPICK, 4)
	await _open()

	_drag(_view.cell_center(Vector2i(0, 0)), Vector2(-120, 40))

	assert_array(_player.inventory.inventory.stacks).is_empty()
	var dropped := EventLog.find(&"item.dropped")
	assert_array(dropped).has_size(1)
	assert_int(dropped[0].data["count"]).is_equal(4)


func test_a_click_selects_and_the_details_follow() -> void:
	await _load()
	_player.inventory.give(Items.PISTOL, 1)
	_player.inventory.give(Items.MEDKIT, 2)
	await _open()
	# Nothing in hand: the first stack is selected on open.
	assert_object(_tab.selected_stack()).is_same(_player.inventory.inventory.stacks[0])

	_click(_view.cell_center(_player.inventory.inventory.stacks[1].cell))

	var medkit := _player.inventory.inventory.stacks[1]
	assert_object(_tab.selected_stack()).is_same(medkit)
	assert_str((_tab.detail_box.get_node("Head/Title") as Label).text).is_equal("Medkit  x2")
	assert_str(_tab.use_button.text).is_equal("Use")


func test_use_heals_while_the_world_runs() -> void:
	await _load()
	_player.inventory.give(Items.MEDKIT, 3)
	_player.body.take_damage(&"damage.blunt", 40.0, &"torso")
	await _open()

	_tab.use_button.pressed.emit()

	assert_bool(get_tree().paused).is_false()
	assert_array(EventLog.find(&"actor.healed")).has_size(1)
	assert_int(_player.inventory.inventory.count_of(&"medkit")).is_equal(2)
	assert_bool(_tabs.is_open()).is_true()
	# Unhurt now: refused, and the tab says why.
	_player.body.heal(1000.0)
	_tab.use_button.pressed.emit()
	assert_int(_player.inventory.inventory.count_of(&"medkit")).is_equal(2)
	assert_str(_tab.status_label.text).is_equal(Items.MEDKIT.refused_message)


func test_equip_drop_and_the_belt_picker() -> void:
	await _load()
	_player.inventory.give(Items.PISTOL, 1)
	_player.inventory.give(Items.AMMO, 20)
	var pistol := _player.inventory.inventory.stacks[0]
	await _open()
	_tab.select(pistol)

	_tab.use_button.pressed.emit()
	assert_object(_player.inventory.in_hand()).is_same(pistol)
	_tab.refresh()
	assert_str(_tab.use_button.text).is_equal("Put away")

	# The picker lists "not on the belt" then the ten slots; the pistol took belt 1 when given.
	assert_int(_tab.belt_picker.item_count).is_equal(11)
	assert_int(_tab.belt_picker.selected).is_equal(1)
	_tab.belt_picker.select(8)
	_tab.belt_picker.item_selected.emit(8)
	assert_int(_player.inventory.belt.slot_of(pistol)).is_equal(7)
	_tab.assign_belt(InventoryTab.OFF_BELT)
	assert_int(_player.inventory.belt.slot_of(pistol)).is_equal(-1)

	_tab.drop_button.pressed.emit()
	assert_int(_player.inventory.inventory.count_of(&"pistol")).is_equal(0)
	assert_array(EventLog.find(&"item.dropped")).has_size(1)
	# The selection is gone; the details say so.
	_tab.refresh()
	assert_object(_tab.selected_stack()).is_null()
	assert_object(_tab.use_button).is_null()


func test_right_click_menu_use_split_and_assign() -> void:
	await _load()
	_player.inventory.give(Items.AMMO, 41)
	await _open()
	var ammo := _player.inventory.inventory.stacks[0]

	_view._gui_input(_button(MOUSE_BUTTON_RIGHT, true, _view.cell_center(Vector2i(0, 0))))
	await _driver.frames(1)
	assert_str(_tab.menu.get_item_text(0)).is_equal("Use")
	assert_str(_tab.menu.get_item_text(1)).is_equal("Drop")
	assert_str(_tab.menu.get_item_text(2)).is_equal("Split stack")

	_tab.choose(InventoryTab.MENU_SPLIT)
	_tab.show_menu(ammo, Vector2(300, 200))
	_tab.choose(InventoryTab.MENU_BELT + 9)

	assert_int(ammo.count).is_equal(21)
	assert_int(_player.inventory.inventory.stacks[1].count).is_equal(20)
	assert_int(_player.inventory.belt.slot_of(ammo)).is_equal(9)


func _click(at: Vector2) -> void:
	_view._gui_input(_button(MOUSE_BUTTON_LEFT, true, at))
	_view._gui_input(_button(MOUSE_BUTTON_LEFT, false, at))


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
	await _driver.hold(&"inventory", 2)
	await _driver.frames(1)
	assert_bool(_tabs.is_open()).is_true()
	assert_object(_tabs.current_page()).is_same(_tab)


func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(ROOM))
	_player = _driver.player
	_tabs = TabInterface.of(_player)
	_tab = _tabs.page(0) as InventoryTab
	_view = _tab.view
	await _driver.settle()
	await _driver.place(Vector3.ZERO)
