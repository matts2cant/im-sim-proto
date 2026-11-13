extends GdUnitTestSuite
## Integration (ADR 0142): the Interactor's hold action on a minimal character (the walker of
## character_fixtures.gd with Eyes looking 55 degrees down, a Carrier, an Interactor, an Inventory,
## a 20 kg carry limit) driven as a controller would (press() on the key's press, refresh() and
## step_hold() every tick). The target is a small crate (10 kg, centre 1.2 m ahead) made lootable
## (an Inventory and a Lootable): usable and carryable. With a loot screen (a stand-in), a tap
## (released after 0.2 s) opens it on the crate and a hold (0.8 s; the hold time is 0.5 s) carries
## the crate without opening it; without a loot screen, the press carries at once as before.

const Wait := preload("res://tests/helpers/wait.gd")
const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const LootStandIn := preload("res://tests/items/inventory/fixtures/loot_screen_stand_in.gd")
const INVENTORY_CONFIG: InventoryConfig = preload("res://items/inventory/inventory_config.tres")
const ORIGIN := Vector3(-460, 0, -260)
const EYE_HEIGHT := 1.6
const PITCH_DEG := -55.0
const AHEAD := 1.2
const TICK := 1.0 / 60.0

var _root: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new()) as Node3D
	add_child(_root)
	Characters.floor_box(_root, 0.0).position = ORIGIN + Vector3(0, -0.5, 0)


func after_test() -> void:
	StimulusSystem.clear()


func test_a_tap_opens_the_loot_screen_and_a_hold_carries() -> void:
	var walker := _walker("Porter")
	var screen := LootStandIn.add_to(walker) as LootStandIn
	var crate := await _lootable_crate()
	var interactor := Interactor.of(walker)
	var carrier := Carrier.of(walker)

	interactor.refresh()
	assert_int(interactor.kind).is_equal(Interactor.Kind.USE)
	assert_int(interactor.hold_kind).is_equal(Interactor.Kind.CARRY)
	assert_object(interactor.target).is_same(crate)

	assert_bool(interactor.press()).is_false()
	_hold(interactor, 0.2)
	assert_bool(interactor.is_holding()).is_true()
	assert_int(screen.opened).is_equal(0)
	_release(interactor)

	assert_int(screen.opened).is_equal(1)
	assert_object(screen.subject).is_same(crate)
	assert_bool(carrier.is_carrying()).is_false()
	screen.close_screen()

	interactor.press()
	_hold(interactor, 0.8)

	assert_object(carrier.held).is_same(crate)
	assert_int(screen.opened).is_equal(1)
	assert_bool(interactor.is_holding()).is_false()
	# Letting go after the carry does nothing more (no tap).
	_release(interactor)
	assert_int(screen.opened).is_equal(1)
	assert_object(carrier.held).is_same(crate)


func test_without_a_loot_screen_the_press_carries_at_once() -> void:
	var walker := _walker("Porter")
	var crate := await _lootable_crate()
	var interactor := Interactor.of(walker)

	interactor.refresh()
	assert_int(interactor.kind).is_equal(Interactor.Kind.CARRY)
	assert_int(interactor.hold_kind).is_equal(Interactor.Kind.NONE)

	assert_bool(interactor.press()).is_true()
	assert_object(Carrier.of(walker).held).is_same(crate)


func test_looking_away_cancels_the_hold() -> void:
	var walker := _walker("Porter")
	var screen := LootStandIn.add_to(walker) as LootStandIn
	await _lootable_crate()
	var interactor := Interactor.of(walker)
	interactor.press()
	_hold(interactor, 0.2)

	(walker.get_node("Head") as Node3D).rotation.x = deg_to_rad(20.0)
	_hold(interactor, 0.8)
	_release(interactor)

	assert_bool(Carrier.of(walker).is_carrying()).is_false()
	assert_int(screen.opened).is_equal(0)


# `seconds` of ticks with the key held (the controller refreshes first every tick).
func _hold(interactor: Interactor, seconds: float) -> void:
	for i in roundi(seconds / TICK):
		interactor.refresh()
		interactor.step_hold(true, TICK)


# One tick with the key released.
func _release(interactor: Interactor) -> void:
	interactor.refresh()
	interactor.step_hold(false, TICK)


# A small crate 1.2 m ahead with an Inventory and a Lootable (it settles first).
func _lootable_crate() -> RigidBody3D:
	var crate := Objects.spawn(_root, Objects.SMALL_CRATE, ORIGIN + Vector3(0, 0.3, -AHEAD)) as RigidBody3D
	var inventory := Inventory.new()
	inventory.name = "Inventory"
	inventory.config = INVENTORY_CONFIG
	crate.add_child(inventory)
	var lootable := Lootable.new()
	lootable.name = "Lootable"
	crate.add_child(lootable)
	await Wait.frames(get_tree(), 10)
	return crate


# The minimal walker at ORIGIN facing -Z with Eyes (a head 1.6 m up, pitched down), an Inventory, a
# Carrier and an Interactor; a carry limit of 20 kg.
func _walker(walker_name: String) -> CharacterBody3D:
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
	var inventory := Inventory.new()
	inventory.name = "Inventory"
	inventory.config = INVENTORY_CONFIG
	walker.add_child(inventory)
	var carrier := Carrier.new()
	carrier.name = "Carrier"
	walker.add_child(carrier)
	var interactor := Interactor.new()
	interactor.name = "Interactor"
	walker.add_child(interactor)
	return walker
