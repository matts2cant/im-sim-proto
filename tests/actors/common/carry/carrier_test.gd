extends GdUnitTestSuite
## Integration (ADR 0139): carrying and interaction on a minimal non-player character (the walker of
## character_fixtures.gd with Eyes looking 55 degrees down, a Carrier, an Interactor, an Inventory
## and a 20 kg `carry_mass_limit`), driven by the test as a controller would: its Interactor offers a
## small crate (10 kg, centre 1.2 m ahead) to carry, `use` picks it up through the Carrier, which
## holds it at the hold point in front of the Eyes and puts it down; an item pickup goes into its
## Inventory. Without an Inventory or a Carrier nothing of theirs is offered. The player's own carry
## tests: tests/actors/player/player_carry*_test.gd.

const Wait := preload("res://tests/helpers/wait.gd")
const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const Items := preload("res://tests/items/item_test_helpers.gd")
const CARRY: CarryConfig = preload("res://actors/common/carry/carry.tres")
const INVENTORY_CONFIG: InventoryConfig = preload("res://items/inventory/inventory_config.tres")
const ORIGIN := Vector3(-420, 0, 260)
## Eyes 1.6 m above the feet, pitched down 55 degrees: within the 2 m reach the ray meets the front
## face of a 0.6 m crate centred 1.2 m ahead 0.32 m up (face 0.9 m ahead), and the top of a medkit
## (0.09 m high, 0.17 m deep, centred 1.06 m ahead) 1.058 m ahead.
const EYE_HEIGHT := 1.6
const PITCH_DEG := -55.0
## The crate's centre ahead of the feet (m, along -Z).
const AHEAD := 1.2
## The medkit's centre ahead of the feet (m, along -Z).
const ITEM_AHEAD := 1.06

var _root: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new()) as Node3D
	add_child(_root)
	Characters.floor_box(_root, 0.0).position = ORIGIN + Vector3(0, -0.5, 0)


func after_test() -> void:
	StimulusSystem.clear()


func test_a_minimal_character_picks_up_carries_and_puts_down_a_prop() -> void:
	var walker := _walker("Porter", [&"Carrier", &"Interactor", &"Inventory"])
	var crate := Objects.spawn(_root, Objects.SMALL_CRATE, ORIGIN + Vector3(0, 0.3, -AHEAD)) as RigidBody3D
	await Wait.frames(get_tree(), 10)
	var interactor := Interactor.of(walker)
	var carrier := Carrier.of(walker)

	interactor.refresh()
	assert_int(interactor.kind).is_equal(Interactor.Kind.CARRY)
	assert_object(interactor.target).is_same(crate)
	assert_bool(interactor.perform()).is_true()

	assert_object(carrier.held).is_same(crate)
	assert_int(crate.collision_layer).is_equal(0)
	for i in 30:
		carrier.physics_step()
		await Wait.frames(get_tree(), 1)
	var hold := CarryRules.hold_point(Eyes.view_of(walker), 0.3, CARRY)
	assert_float(crate.global_position.distance_to(hold)).is_less(0.001)
	interactor.refresh()
	assert_int(interactor.kind).is_equal(Interactor.Kind.PUT_DOWN)

	assert_bool(interactor.perform()).is_true()
	assert_bool(carrier.is_carrying()).is_false()
	assert_int(crate.collision_layer).is_equal(PhysicsLayers.OBJECTS)
	assert_array(EventLog.find(&"carry.dropped")).has_size(1)
	await Wait.frames(get_tree(), 90)
	assert_float(crate.global_position.y).is_equal_approx(0.3, 0.05)


func test_a_minimal_character_picks_up_an_item_into_its_inventory() -> void:
	var walker := _walker("Looter", [&"Carrier", &"Interactor", &"Inventory"])
	Items.spawn_pickup(_root, Items.MEDKIT, ORIGIN + Vector3(0, 0.05, -ITEM_AHEAD), 2)
	await Wait.frames(get_tree(), 30)
	var interactor := Interactor.of(walker)

	interactor.refresh()
	assert_int(interactor.kind).is_equal(Interactor.Kind.PICK_UP)
	assert_bool(interactor.perform()).is_true()

	assert_int(Inventory.of(walker).count(Items.MEDKIT)).is_equal(2)
	assert_object(EventLog.find(&"item.picked_up")[0].source_entity()).is_same(walker)


func test_without_an_inventory_or_a_carrier_nothing_of_theirs_is_offered() -> void:
	var walker := _walker("EmptyHanded", [&"Interactor"])
	Objects.spawn(_root, Objects.SMALL_CRATE, ORIGIN + Vector3(0, 0.3, -AHEAD))
	await Wait.frames(get_tree(), 10)
	var interactor := Interactor.of(walker)

	interactor.refresh()

	assert_int(interactor.kind).is_equal(Interactor.Kind.NONE)
	assert_object(interactor.looked_at).is_not_null()


# The minimal walker at ORIGIN facing -Z with Eyes (a head 1.6 m up, pitched down) and `parts`
# (Carrier, Interactor, Inventory); a carry limit of 20 kg.
func _walker(walker_name: String, parts: Array[StringName]) -> CharacterBody3D:
	var walker := Characters.character(_root, walker_name, ORIGIN, [])
	walker.set_physics_process(false)
	(walker.get_node("Attributes") as Attributes).attribute_set.set_base(Carrier.LIMIT_ATTRIBUTE, 20.0)
	var head := Node3D.new()
	head.name = "Head"
	head.position.y = EYE_HEIGHT
	head.rotation.x = deg_to_rad(PITCH_DEG)
	walker.add_child(head)
	var eyes := Eyes.new()
	eyes.name = "Eyes"
	eyes.view_path = ^"../Head"
	walker.add_child(eyes)
	if parts.has(&"Inventory"):
		var inventory := Inventory.new()
		inventory.name = "Inventory"
		inventory.config = INVENTORY_CONFIG
		walker.add_child(inventory)
	if parts.has(&"Carrier"):
		var carrier := Carrier.new()
		carrier.name = "Carrier"
		walker.add_child(carrier)
	if parts.has(&"Interactor"):
		var interactor := Interactor.new()
		interactor.name = "Interactor"
		walker.add_child(interactor)
	return walker
