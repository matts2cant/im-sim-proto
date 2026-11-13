extends GdUnitTestSuite
## Integration in the real inventory bay (inside the hub) with the player: the table pickups stay on
## their tables once physics runs; E on the item table's pistol (prompt) puts it in the inventory and
## on belt slot 1, and key 1 draws it; taking the whole "Fill the grid" table ends in "No room in
## inventory" with something left on the table.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const HUB := "res://levels/hub/hub.tscn"
const TABLE_TOP := 1.0
## Room-local feet beside the item table's pistol (room origin on the hub wall, -Z into the room).
const BESIDE_PISTOL := Vector3(-4.6, 0, -6.4)

var _driver: PlayerDriver
var _player: Player
var _room: Node3D


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_table_pickups_stay_on_their_tables() -> void:
	await _load_hub()
	await _driver.frames(60)

	for station: String in ["ItemTable", "Stacks", "FillGrid"]:
		for child: Node in _room.get_node(station).get_children():
			if ItemPickup.of(child) == null:
				continue
			# The bottom of its collision box rests on the top (weapons lying on their side are taller).
			var shape := (child.get_node("Collision") as CollisionShape3D).shape as BoxShape3D
			var y := _room.to_local((child as Node3D).global_position).y - shape.size.y * 0.5
			assert_float(y).override_failure_message("%s/%s" % [station, child.name]).is_between(
				TABLE_TOP - 0.05, TABLE_TOP + 0.05
			)


func test_e_takes_the_item_table_pistol_onto_the_belt_and_key_1_draws_it() -> void:
	await _load_hub()
	var pistol := _room.get_node("ItemTable/Pistol") as RigidBody3D
	assert_bool(_player.weapons.is_armed()).is_false()
	_player.load_state(Objects.aiming_state(_player, _room.to_global(BESIDE_PISTOL), pistol.global_position))
	await _driver.frames(3)
	assert_str(_player.interactor.prompt).is_equal("E: pick up Pistol")

	await _driver.hold(&"use", 2)
	await _driver.frames(1)

	assert_bool(is_instance_valid(pistol)).is_false()
	var inventory := _player.inventory
	assert_int(inventory.grid.count_of(&"pistol")).is_equal(1)
	assert_str(String(inventory.belt.stack_in(0).item.id)).is_equal("pistol")
	assert_array(Objects.logged(&"item.picked_up", "item", "pistol")).has_size(1)

	await _driver.hold(&"belt_1", 2)
	await _driver.frames(1)

	assert_bool(_player.weapons.is_armed()).is_true()
	assert_str(String(_player.weapons.weapon().id)).is_equal("pistol")


func test_taking_the_fill_the_grid_table_runs_out_of_room() -> void:
	await _load_hub()
	var hud := _player.get_node("Hud") as Hud
	var refused := 0
	var first_refusal_message := ""

	for child: Node in _room.get_node("FillGrid").get_children():
		var pickup := ItemPickup.of(child)
		if pickup != null and not _player.inventory.pick_up(pickup):
			refused += 1
			if refused == 1:
				first_refusal_message = hud.message_label.text
	await _driver.frames(1)

	assert_int(refused).is_greater(0)
	assert_array(EventLog.find(&"item.pickup_refused")).has_size(refused)
	assert_str(first_refusal_message).is_equal(Inventory.NO_ROOM)
	# Something is still on the table.
	var left := _room.get_node("FillGrid").get_children().filter(func(n: Node) -> bool: return ItemPickup.of(n) != null)
	assert_array(left).is_not_empty()


func _load_hub() -> void:
	_driver = PlayerDriver.new(scene_runner(HUB))
	_player = _driver.player
	_room = _driver.runner.find_child("InventoryBayRoom") as Node3D
	await _driver.settle()
	EventLog.clear()
