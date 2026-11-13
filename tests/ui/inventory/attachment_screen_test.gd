extends GdUnitTestSuite
## Integration (ADR 0085): fitting the silencer in the Inventory tab. While it is dragged, every
## weapon it fits is highlighted (grid and belt), never the shotgun; dropped on the pistol (grid) or
## the sniper rifle (belt slot) it is fitted: the silencer stack is used up, the weapon's state
## records it, its shots are a quarter as loud (pistol 25 -> 6.25). Dropped on the shotgun it is just
## a refused move. It stays fitted through save/load and drop/pick-up (the pickup shows it). Mouse
## events are sent to the Inventory tab's InventoryView like the viewport would (inventory_tab_test.gd).

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const ROOM := "res://tests/objects/fixtures/carry_room.tscn"
const WALL_POINT := Vector3(0, 1.5, -5.8)
const PISTOL: ItemData = preload("res://items/weapons/pistol/pistol_item.tres")
const SHOTGUN: ItemData = preload("res://items/weapons/shotgun/shotgun_item.tres")
const SNIPER: ItemData = preload("res://items/weapons/sniper_rifle/sniper_rifle_item.tres")
const SILENCER: ItemData = preload("res://items/attachments/silencer/silencer.tres")
const AMMO: ItemData = preload("res://items/pistol_ammo/pistol_ammo.tres")

var _driver: PlayerDriver
var _player: Player
var _screen: TabInterface
var _view: InventoryView
var _pistol: ItemStack
var _shotgun: ItemStack
var _sniper: ItemStack
var _silencer: ItemStack


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	PauseScreens.reset(get_tree())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_dragging_the_silencer_highlights_compatible_weapons_only() -> void:
	await _load()
	await _open()

	_view._gui_input(_button(true, _view.cell_center(_silencer.cell)))
	_view._gui_input(_motion(_view.cell_center(Vector2i(3, 3))))

	var targets := _view.attach_targets()
	assert_array(targets).contains_exactly_in_any_order([_pistol, _sniper])
	assert_bool(targets.has(_shotgun)).is_false()
	_view._gui_input(_button(false, _view.cell_center(Vector2i(3, 3))))
	# Not an attachment: no highlight.
	_view._gui_input(_button(true, _view.cell_center(_shotgun.cell)))
	_view._gui_input(_motion(_view.cell_center(Vector2i(3, 4))))
	assert_array(_view.attach_targets()).is_empty()
	_view._gui_input(_button(false, _view.cell_center(Vector2i(3, 4))))


func test_dropping_it_on_the_pistol_fits_it_and_quiets_the_shots() -> void:
	await _load()
	await _open()

	_drag(_view.cell_center(_silencer.cell), _view.cell_center(_pistol.cell))

	assert_bool(_player.inventory.inventory.stacks.has(_silencer)).is_false()
	assert_int(_player.inventory.inventory.count_of(&"silencer")).is_equal(0)
	assert_dict(Attachments.fitted_ids(_pistol.state)).is_equal({"muzzle": "silencer"})
	assert_str(_pistol.display_name()).is_equal("Pistol (silenced)")
	assert_str(InventoryView.tooltip_text(_pistol)).contains("Fitted: silenced")
	assert_array(EventLog.find(&"item.attached")).has_size(1)
	assert_float(_player.inventory.weapon_state(_pistol).stat(&"fire_noise")).is_equal_approx(6.25, 0.0001)

	await _driver.press(&"inventory")
	await _driver.press(&"belt_1")
	_player.load_state(Objects.aiming_state(_player, Vector3.ZERO, WALL_POINT))
	await _driver.frames(5)
	EventLog.clear()
	await _driver.hold(&"fire", 2)
	await _driver.frames(4)
	var fired := EventLog.find(&"weapon.fired")
	assert_array(fired).has_size(1)
	assert_float(fired[0].data["noise"]).is_equal_approx(6.25, 0.0001)
	assert_bool(_player.weapons.flash.visible).is_false()
	assert_array(_player.weapons.view_pivot().model.fitted_models()).has_size(1)


func test_dropping_it_on_the_sniper_rifle_belt_slot_fits_it() -> void:
	await _load()
	await _open()
	var slot := _player.inventory.belt.slot_of(_sniper)
	assert_int(slot).is_greater_equal(0)

	_drag(_view.cell_center(_silencer.cell), _view.belt_slot_rect(slot).get_center())

	assert_dict(Attachments.fitted_ids(_sniper.state)).is_equal({"muzzle": "silencer"})
	assert_object(_player.inventory.belt.stack_in(slot)).is_same(_sniper)


func test_dropping_it_on_the_shotgun_is_refused_as_a_move() -> void:
	await _load()
	await _open()
	var cell := _silencer.cell

	_drag(_view.cell_center(cell), _view.cell_center(_shotgun.cell))

	assert_bool(_player.inventory.inventory.stacks.has(_silencer)).is_true()
	assert_vector(_silencer.cell).is_equal(cell)
	assert_dict(Attachments.fitted_ids(_shotgun.state)).is_empty()
	assert_array(EventLog.find(&"item.attached")).is_empty()
	assert_bool(_player.inventory.attach(_silencer, _shotgun)).is_false()


func test_a_second_silencer_does_not_fit_the_same_weapon() -> void:
	await _load()
	_player.inventory.give(SILENCER, 1)
	var second := _player.inventory.inventory.stacks[-1]
	assert_bool(_player.inventory.attach(_silencer, _pistol)).is_true()

	assert_bool(_player.inventory.can_attach(second, _pistol)).is_false()
	assert_array(_player.inventory.attach_targets(second)).contains_exactly([_sniper])


func test_it_stays_fitted_through_save_and_load() -> void:
	await _load()
	_player.inventory.attach(_silencer, _pistol)
	var saved := _player.save_state()

	_player.load_state({"inventory": {"inventory": {}, "belt": {}, "in_hand": -1}})
	assert_int(_player.inventory.inventory.stacks.size()).is_equal(0)
	_player.load_state(saved)

	var pistol := _first(&"pistol")
	assert_str(pistol.display_name()).is_equal("Pistol (silenced)")
	assert_float(_player.inventory.weapon_state(pistol).stat(&"fire_noise")).is_equal_approx(6.25, 0.0001)
	assert_int(_player.inventory.inventory.count_of(&"silencer")).is_equal(0)


func test_it_stays_fitted_when_dropped_and_picked_up() -> void:
	await _load()
	_player.inventory.attach(_silencer, _pistol)

	var body := _player.inventory.drop_stack(_pistol)
	await _driver.frames(2)
	var pickup := ItemPickup.of(body)
	assert_str(pickup.label()).is_equal("Pistol (silenced)")
	var model := body.get_node("Model") as WeaponModel
	assert_array(model.fitted_models()).has_size(1)
	# Saved with the level: the pickup's state carries it.
	assert_dict(Attachments.fitted_ids(pickup.save_state()["state"])).is_equal({"muzzle": "silencer"})

	assert_bool(_player.inventory.pick_up(pickup)).is_true()
	var pistol := _first(&"pistol")
	assert_str(pistol.display_name()).is_equal("Pistol (silenced)")
	assert_float(_player.inventory.weapon_state(pistol).stat(&"fire_noise")).is_equal_approx(6.25, 0.0001)


func _first(id: StringName) -> ItemStack:
	for stack in _player.inventory.inventory.stacks:
		if stack.item.id == id:
			return stack
	return null


func _drag(from: Vector2, to: Vector2) -> void:
	_view._gui_input(_button(true, from))
	_view._gui_input(_motion(to))
	_view._gui_input(_button(false, to))


static func _button(pressed: bool, at: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	return event


static func _motion(at: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = at
	return event


func _open() -> void:
	await _driver.press(&"inventory")
	assert_bool(_screen.is_open()).is_true()


# Pistol (0, 0), shotgun (2, 0), sniper rifle (0, 1), silencer (5, 0); the weapons on belt 1-3.
func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(ROOM))
	_player = _driver.player
	_screen = TabInterface.of(_player)
	_view = (_screen.page(0) as InventoryTab).view
	await _driver.settle()
	await _driver.place(Vector3.ZERO)
	var inventory := _player.inventory
	inventory.give(PISTOL, 1)
	inventory.give(SHOTGUN, 1)
	inventory.give(SNIPER, 1)
	inventory.give(SILENCER, 1)
	inventory.give(AMMO, 20)
	var stacks := inventory.inventory.stacks
	_pistol = stacks[0]
	_shotgun = stacks[1]
	_sniper = stacks[2]
	_silencer = stacks[3]
	assert_vector(_silencer.cell).is_equal(Vector2i(5, 0))
	assert_vector(_shotgun.cell).is_equal(Vector2i(2, 0))
	EventLog.clear()
