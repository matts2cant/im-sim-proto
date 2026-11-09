extends GdUnitTestSuite
## Scenario: the warehouse's mission props work through the systems (design/levels/mission-warehouse.md,
## ADR 0087). Picking up the prototype in the vault completes optional objective A; the shipment
## on the dock is sabotaged by blowing up its fuel drum or by setting one of its crates on fire
## (optional B); the gas cylinders outside the weak wall chain-explode and break the wall's panel
## open (loudly); the catwalk rifle guard, knocked out, drops its assault rifle. The level runs with
## its population and the Mission (fixture `warehouse_player.tscn`); props are found by their tags
## and components.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const WarehouseHelpers := preload("res://tests/levels/mission/warehouse_helpers.gd")
const PEOPLE := "Population/People"
const SHIPMENT_TAG := &"mission.shipment"
## The weak wall's doorway centre (layout marker WeakWall) at chest height.
const WEAK_WALL := Vector3(-10.0, 1.1, 15.25)

var _driver: PlayerDriver
var _level: Node
var _mission: Mission


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	StimulusSystem.clear()


func test_picking_up_the_prototype_completes_optional_a() -> void:
	await _setup()
	var prototype := _people().get_node("Items/Prototype") as Node3D
	var pickup := ItemPickup.of(prototype)
	assert_str(String(pickup.item.id)).is_equal("prototype")
	assert_bool(_mission.tracker.is_done(&"prototype")).is_false()
	# Standing in the vault beside the pedestal.
	await _driver.place(Vector3(18.0, 4.5, 3.5), -PI / 2.0)

	assert_bool(_driver.player.inventory.pick_up(pickup)).is_true()
	await _frames(3)

	assert_bool(_mission.tracker.is_done(&"prototype")).is_true()
	assert_int(_completed(&"prototype")).is_equal(1)
	assert_bool(_mission.tracker.is_done(&"shipment")).is_false()


func test_blowing_up_the_fuel_drum_sabotages_the_shipment() -> void:
	await _setup()
	var drum := _shipment_part(&"object.explosive")
	assert_object(drum).is_not_null()
	assert_bool(_mission.tracker.is_done(&"shipment")).is_false()

	StimulusSystem.emit(Stimulus.make_contact(&"damage.ballistic", 100.0, drum))
	await _frames(6)

	assert_array(EventLog.find(&"object.exploded")).is_not_empty()
	assert_bool(_mission.tracker.is_done(&"shipment")).is_true()
	assert_int(_completed(&"shipment")).is_equal(1)


func test_a_burning_shipment_crate_also_sabotages_it() -> void:
	await _setup()
	var crate: Node3D = null
	for part in _tagged(SHIPMENT_TAG):
		if part.has_node("Flammable") and not part.has_node("Explosive"):
			crate = part
			break
	assert_object(crate).is_not_null()

	# A fire reaching the crate (a burning neighbour, a thrown bottle of fuel...): it ignites.
	for i in 3:
		StimulusSystem.emit(Stimulus.make_contact(&"fire", 20.0, crate))
		await _frames(2)
	await _frames(3)

	assert_bool(ActorState.has(crate, Flammable.BURNING_TAG)).is_true()
	assert_bool(_mission.tracker.is_done(&"shipment")).is_true()


func test_the_gas_cylinders_breach_the_weak_wall_loudly() -> void:
	await _setup()
	var panel := _people().get_node("WeakWall/BreachPanel") as Node3D
	var cylinders: Array[Node3D] = []
	for node in _people().get_node("WeakWall").get_children():
		if node.has_node("Explosive"):
			cylinders.append(node as Node3D)
	assert_int(cylinders.size()).is_greater_equal(2)
	var world := (panel as Node3D).get_world_3d()
	assert_bool(_ray_clear(world)).override_failure_message("the panel closes the weak wall").is_false()

	# One shot at one cylinder: the rest chain and the panel breaks.
	StimulusSystem.emit(Stimulus.make_contact(&"damage.ballistic", 100.0, cylinders[0]))
	await _frames(10)

	assert_int(EventLog.find(&"object.exploded").size()).is_equal(cylinders.size())
	assert_bool(is_instance_valid(panel)).is_false()
	var broken := EventLog.find(&"object.broken").filter(
		func(entry: EventLogEntry) -> bool: return entry.source == "BreachPanel"
	)
	assert_int(broken.size()).is_equal(1)
	assert_bool(_ray_clear(world)).override_failure_message("the weak wall is still closed").is_true()
	# Loud: an explosion's noise carries 60 m.
	var loudest := 0.0
	for entry in EventLog.find(&"stimulus.emitted"):
		if entry.data.get("type") == "noise":
			loudest = maxf(loudest, float(entry.data.get("intensity", 0.0)))
	assert_float(loudest).is_greater_equal(60.0)


func test_the_catwalk_rifle_guard_drops_its_assault_rifle() -> void:
	await _setup()
	var guard := _people().get_node("Guards/G4CatwalkRifle") as Node3D
	assert_str(String((guard.get_node("Aim/WeaponHolder") as WeaponHolder).weapons[0].item_id)).is_equal(
		"assault_rifle"
	)

	(guard.get_node("BodyParts") as BodyParts).take_damage(&"damage.stun", 200.0)
	await _frames(3)

	var dropped: Array[Node3D] = []
	for node in _level.find_children("*", "RigidBody3D", true, false):
		var pickup := ItemPickup.of(node)
		if pickup != null and pickup.item.id == &"assault_rifle":
			dropped.append(node as Node3D)
	assert_int(dropped.size()).is_equal(1)
	assert_float(dropped[0].global_position.distance_to(guard.global_position)).is_less(1.5)


func _setup() -> void:
	_driver = PlayerDriver.new(scene_runner(WarehouseHelpers.fixture(self, false)))
	_driver.player.reload_on_reset = false
	_level = _driver.runner.scene()
	_mission = _level.get_node("Mission") as Mission
	await _frames(3)
	if _mission.briefing.is_open():
		_mission.briefing.close()
	await _frames(3)
	EventLog.clear()


func _people() -> Node:
	return _level.get_node(PEOPLE)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _tagged(tag: StringName) -> Array[Node3D]:
	var found: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group(Tags.GROUP):
		if (node as Tags).has(tag) and node.get_parent() is Node3D:
			found.append(node.get_parent() as Node3D)
	return found


# The part of the shipment with the tag `kind` (e.g. object.explosive), or null.
func _shipment_part(kind: StringName) -> Node3D:
	for part in _tagged(SHIPMENT_TAG):
		if ActorState.has(part, kind):
			return part
	return null


func _completed(objective: StringName) -> int:
	return (
		EventLog
		. find(&"mission.objective_completed")
		. filter(func(entry: EventLogEntry) -> bool: return str(entry.data.get("objective", "")) == String(objective))
		. size()
	)


# A ray through the weak wall's doorway (south to north, world layer) meets nothing.
func _ray_clear(world: World3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(
		WEAK_WALL + Vector3(0, 0, 1.0), WEAK_WALL - Vector3(0, 0, 1.0), PhysicsLayers.WORLD
	)
	return world.direct_space_state.intersect_ray(query).is_empty()
