extends GdUnitTestSuite
## Integration (ADR 0066): a breaker panel switches every Powered on its circuit and nothing else,
## through the circuit's group (lamps opt in by their `circuit`; the breaker names none). Using it
## clunks (noise 6, PATH) and logs `power.switched`; using it again restores power; a breaker
## placed open cuts its circuit at start; breaker and lamp states save and load. Powered works on
## any entity, not only the shipping lamps.

const Wait := preload("res://tests/helpers/wait.gd")
const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const BREAKER := "res://objects/breaker_panel/breaker_panel.tscn"
const CEILING_LAMP := "res://objects/light_fixture/ceiling_lamp.tscn"
const WALL_LAMP := "res://objects/light_fixture/wall_lamp.tscn"

var _root: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	add_child(_root)
	Characters.floor_box(_root)


func after_test() -> void:
	StimulusSystem.clear()


func _lamp(path: String, position: Vector3, circuit: StringName, lamp_name: String) -> Node3D:
	var lamp := (load(path) as PackedScene).instantiate() as Node3D
	lamp.name = lamp_name
	Powered.of(lamp).circuit = circuit
	_root.add_child(lamp)
	lamp.global_position = position
	return lamp


func _breaker(circuit: StringName, closed: bool = true) -> CircuitBreaker:
	var panel := (load(BREAKER) as PackedScene).instantiate() as Node3D
	var breaker := Usable.of(panel) as CircuitBreaker
	breaker.circuit = circuit
	breaker.closed = closed
	_root.add_child(panel)
	panel.global_position = Vector3(0, 1.2, 5)
	return breaker


func _light_visible(lamp: Node) -> bool:
	return (lamp.find_children("*", "Light3D", true, false)[0] as Light3D).is_visible_in_tree()


func test_breaker_switches_its_circuit_only() -> void:
	var a1 := _lamp(CEILING_LAMP, Vector3(0, 4, 0), &"lab", "A1")
	var a2 := _lamp(WALL_LAMP, Vector3(3, 2, 0), &"lab", "A2")
	var b := _lamp(CEILING_LAMP, Vector3(6, 4, 0), &"hall", "B")
	var breaker := _breaker(&"lab")
	await Wait.frames(get_tree(), 2)
	assert_str(breaker.verb).is_equal("switch off")

	assert_bool(breaker.use(null)).is_true()

	assert_bool(breaker.closed).is_false()
	assert_bool(_light_visible(a1)).is_false()
	assert_bool(_light_visible(a2)).is_false()
	assert_bool(_light_visible(b)).is_true()
	assert_str(breaker.verb).is_equal("switch on")
	var switched := Objects.logged(CircuitBreaker.LOG_KIND, "circuit", &"lab")
	assert_array(switched).has_size(1)
	assert_bool(switched[0].data["on"]).is_false()
	assert_int(switched[0].data["powered"]).is_equal(2)

	breaker.use(null)

	assert_bool(_light_visible(a1)).is_true()
	assert_bool(_light_visible(a2)).is_true()
	assert_array(Objects.logged(CircuitBreaker.LOG_KIND)).has_size(2)


func test_breaker_clunks_through_the_noise_path() -> void:
	var breaker := _breaker(&"lab")
	await Wait.frames(get_tree(), 2)

	breaker.use(null)
	await Wait.frames(get_tree(), 2)

	var noises := EventLog.find(&"stimulus.emitted").filter(
		func(entry: EventLogEntry) -> bool: return entry.data["type"] == &"noise"
	)
	assert_array(noises).has_size(1)
	assert_float(noises[0].data["intensity"]).is_equal_approx(6.0, 0.0001)
	assert_str(noises[0].source).is_equal("BreakerPanel")


func test_breaker_placed_open_cuts_its_circuit_at_start() -> void:
	var lamp := _lamp(CEILING_LAMP, Vector3(0, 4, 0), &"lab", "Lamp")
	_breaker(&"lab", false)
	await Wait.frames(get_tree(), 2)

	assert_bool(_light_visible(lamp)).is_false()
	assert_array(EventLog.find(&"stimulus.emitted")).is_empty()


func test_breaker_and_lamp_states_save_and_load() -> void:
	var lamp := _lamp(CEILING_LAMP, Vector3(0, 4, 0), &"lab", "Lamp")
	var breaker := _breaker(&"lab")
	await Wait.frames(get_tree(), 2)
	breaker.use(null)
	var breaker_state := breaker.save_state()
	var lamp_state := Powered.of(lamp).save_state()
	lamp.free()
	breaker.get_parent().free()
	var fresh_lamp := _lamp(CEILING_LAMP, Vector3(0, 4, 0), &"lab", "Lamp")
	var fresh_breaker := _breaker(&"lab")
	await Wait.frames(get_tree(), 2)
	assert_bool(_light_visible(fresh_lamp)).is_true()

	fresh_breaker.load_state(breaker_state)
	Powered.of(fresh_lamp).load_state(lamp_state)

	assert_bool(fresh_breaker.closed).is_false()
	assert_str(fresh_breaker.verb).is_equal("switch on")
	assert_bool(_light_visible(fresh_lamp)).is_false()
	assert_dict(breaker_state).is_equal({"closed": false})
	# `outage`: seconds of an EMP's outage left (ADR 0131), none here.
	assert_dict(lamp_state).is_equal({"on": false, "outage": 0.0})


func test_powered_works_on_any_entity_and_defaults_to_its_lights() -> void:
	var entity := Fixtures.entity(_root, "Gadget", Vector3(2, 1, 2), [])
	var light := OmniLight3D.new()
	entity.add_child(light)
	var spot := SpotLight3D.new()
	entity.add_child(spot)
	var powered := Powered.new()
	powered.circuit = &"gadgets"
	entity.add_child(powered)

	var count := Powered.set_circuit(get_tree(), &"gadgets", false)

	assert_int(count).is_equal(1)
	assert_bool(light.visible).is_false()
	assert_bool(spot.visible).is_false()
	assert_bool(powered.is_in_group(Powered.group_for(&"gadgets"))).is_true()
	assert_int(Powered.set_circuit(get_tree(), &"other", true)).is_equal(0)
	assert_bool(light.visible).is_false()
