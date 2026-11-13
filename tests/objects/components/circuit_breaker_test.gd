extends GdUnitTestSuite
## CircuitBreaker (ADR 0066) on minimal entities built in code: using it switches every Powered on
## its circuit (found through the circuit's group, whatever the entity is) and nothing on another
## circuit, moves its lever, makes a noise from its entity and logs `power.switched`; a breaker placed
## open cuts its circuit when the level starts; load_state() restores it silently.

const CIRCUIT: StringName = &"breaker_test_circuit"
const OTHER: StringName = &"breaker_test_other"
const ORIGIN := Vector3(-260, 0, -240)

var _root: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	# Far from the origin: its lamps must not light other suites' fixtures while freed late.
	_root.position = ORIGIN
	add_child(_root)


func after_test() -> void:
	StimulusSystem.clear()


# A Node3D entity with a Powered on `circuit` and an OmniLight3D it switches.
func _lamp(entity_name: String, circuit: StringName) -> Powered:
	var entity := Node3D.new()
	entity.name = entity_name
	entity.add_child(OmniLight3D.new())
	var powered := Powered.new()
	powered.circuit = circuit
	entity.add_child(powered)
	_root.add_child(entity)
	return powered


# A Node3D entity at the root (ORIGIN) with a CircuitBreaker on CIRCUIT and a lever.
func _breaker(closed: bool = true) -> CircuitBreaker:
	var entity := Node3D.new()
	entity.name = "Panel"
	var lever := Node3D.new()
	lever.name = "Lever"
	entity.add_child(lever)
	var breaker := CircuitBreaker.new()
	breaker.circuit = CIRCUIT
	breaker.closed = closed
	breaker.lever_path = ^"../Lever"
	entity.add_child(breaker)
	_root.add_child(entity)
	return breaker


func _light(powered: Powered) -> Node3D:
	return powered.target_nodes()[0]


func test_use_switches_its_circuit_only() -> void:
	var first := _lamp("LampA", CIRCUIT)
	var second := _lamp("LampB", CIRCUIT)
	var elsewhere := _lamp("LampC", OTHER)
	var breaker := _breaker()
	var user: Node3D = auto_free(Node3D.new())

	assert_bool(breaker.use(user)).is_true()

	assert_bool(breaker.closed).is_false()
	assert_bool(first.is_on() or second.is_on()).is_false()
	assert_bool(_light(first).visible).is_false()
	assert_bool(elsewhere.is_on()).is_true()
	assert_float((breaker.get_node(breaker.lever_path) as Node3D).rotation_degrees.x).is_equal_approx(
		CircuitBreaker.LEVER_OPEN_DEG, 0.01
	)
	assert_str(breaker.verb).is_equal("switch on")

	breaker.use(user)
	assert_bool(first.is_on() and second.is_on()).is_true()
	assert_bool(_light(second).visible).is_true()


func test_a_throw_is_heard_and_logged() -> void:
	_lamp("LampA", CIRCUIT)
	_lamp("LampB", CIRCUIT)
	var breaker := _breaker()
	breaker.set_closed(false)
	var entries := EventLog.find(EventKinds.POWER_SWITCHED)
	assert_int(entries.size()).is_equal(1)
	assert_bool(entries[0].data["on"]).is_false()
	assert_int(entries[0].data["powered"]).is_equal(2)
	# Emitted stimuli are processed on the next physics tick.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var noises := EventLog.find(StimulusSystem.EMITTED_KIND).filter(
		func(entry: EventLogEntry) -> bool:
			return entry.data["type"] == &"noise" and entry.source_entity() == breaker.entity
	)
	assert_int(noises.size()).is_equal(1)
	assert_vector(noises[0].data["origin"]).is_equal(ORIGIN)


func test_a_breaker_placed_open_cuts_its_circuit_at_start() -> void:
	var lamp := _lamp("LampA", CIRCUIT)
	_breaker(false)
	assert_bool(lamp.is_on()).is_true()
	await get_tree().process_frame
	assert_bool(lamp.is_on()).is_false()


func test_load_state_restores_the_circuit_without_noise() -> void:
	var lamp := _lamp("LampA", CIRCUIT)
	var breaker := _breaker()
	EventLog.clear()
	breaker.load_state({"closed": false})
	assert_bool(breaker.closed).is_false()
	assert_bool(lamp.is_on()).is_false()
	assert_dict(breaker.save_state()).is_equal({"closed": false})
	assert_int(EventLog.find(EventKinds.POWER_SWITCHED).size()).is_equal(0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var from_breaker := EventLog.find(StimulusSystem.EMITTED_KIND).filter(
		func(entry: EventLogEntry) -> bool: return entry.source_entity() == breaker.entity
	)
	assert_array(from_breaker).is_empty()
