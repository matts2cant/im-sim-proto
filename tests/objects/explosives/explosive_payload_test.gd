extends GdUnitTestSuite
## The payload contract with the grenade entities (ADR 0131, M14b): a payload scene under an entity
## with an Explosive gives it its blast config, whichever comes first among the children or when it
## is added later; it is released on Explosive.exploded while the entity still exists, whatever set
## it off, and what lasts spawns in the level. Also the framework pieces the effects need: a uniform
## RADIUS stimulus has no falloff, a blast stimulus of radius 0 is not sent (the jammer is silent), and
## an EMP outage ends by itself without overriding a circuit switched off meanwhile.

const Grenades := preload("res://tests/objects/explosives/explosive_fixtures.gd")
const Net := preload("res://tests/objects/network/network_fixtures.gd")
const FRAG_CONFIG: ExplosiveConfig = preload("res://objects/explosives/payloads/frag_explosive.tres")
const GAS_CONFIG: ExplosiveConfig = preload("res://objects/explosives/payloads/gas_explosive.tres")
const ORIGIN := Vector3(-380, 0, 660)

var _root: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new()) as Node3D
	_root.position = ORIGIN
	add_child(_root)


func after_test() -> void:
	Grenades.clear_effects(get_tree())
	StimulusSystem.clear()


func test_the_payload_gives_the_explosive_its_config_in_any_order() -> void:
	var after := Grenades.grenade(_root, "After", Vector3.ZERO, Grenades.FRAG)
	var before := Grenades.grenade(_root, "Before", Vector3(20, 0, 0), Grenades.GAS, true)
	assert_object(Explosive.of(after).config).is_same(FRAG_CONFIG)
	assert_object(Explosive.of(before).config).is_same(GAS_CONFIG)
	# A payload added to a ready entity: use_config(), the heat kept.
	var late := Grenades.grenade(_root, "Late", Vector3(40, 0, 0), Grenades.FRAG)
	ExplosivePayload.of(late).free()
	var explosive := Explosive.of(late)
	explosive.add_heat(1.5, null)
	late.add_child(Grenades.GAS.instantiate())
	assert_object(explosive.config).is_same(GAS_CONFIG)
	assert_float(explosive.heat()).is_equal(1.5)


func test_released_while_the_entity_exists_and_lasting_effects_spawn_in_the_level() -> void:
	var grenade := Grenades.grenade(_root, "Gas", Vector3(0, 0.1, 0), Grenades.GAS)
	var payload := ExplosivePayload.of(grenade)
	var seen := {}
	payload.released.connect(
		func(origin: Vector3, cause: Stimulus) -> void:
			seen["valid"] = is_instance_valid(grenade) and not grenade.is_queued_for_deletion()
			seen["origin"] = origin
			seen["cause"] = cause
	)
	var shot := Stimulus.make_contact(&"damage.ballistic", 50.0, grenade)
	StimulusSystem.emit(shot)
	await Grenades.seconds(get_tree(), 0.05)
	assert_bool(seen.get("valid", false)).is_true()
	assert_vector(seen["origin"] as Vector3).is_equal_approx(ORIGIN + Vector3(0, 0.1, 0), Vector3.ONE * 0.001)
	assert_int((seen["cause"] as Stimulus).id).is_equal(shot.id)
	assert_bool(is_instance_valid(grenade)).is_false()
	var cloud := Grenades.first(get_tree(), GasCloud.GROUP)
	assert_object(cloud).is_not_null()
	assert_object(cloud.get_parent()).is_not_same(_root)
	assert_array(EventLog.find(&"payload.released")).has_size(1)


func test_the_jammer_is_silent_and_harmless() -> void:
	var grenade := Grenades.grenade(_root, "Jammer", Vector3(0, 0.1, 0), Grenades.JAMMING)
	Explosive.of(grenade).explode()
	await Grenades.seconds(get_tree(), 0.05)
	var sent := EventLog.find(&"stimulus.emitted").filter(
		func(e: EventLogEntry) -> bool: return e.data["source"] == "Jammer"
	)
	assert_array(sent).is_empty()
	assert_object(Grenades.first(get_tree(), JammingField.GROUP)).is_not_null()


func test_a_uniform_radius_stimulus_has_no_falloff() -> void:
	var stimulus := Stimulus.make_radius(&"test", 10.0, Vector3.ZERO, 2.5)
	assert_float(stimulus.perceived_at(2.0)).is_equal_approx(2.0, 0.0001)
	stimulus.uniform = true
	assert_float(stimulus.perceived_at(0.5)).is_equal(10.0)
	assert_float(stimulus.perceived_at(2.4)).is_equal(10.0)
	assert_float(stimulus.perceived_at(2.6)).is_less(0.0)


func test_an_outage_ends_by_itself_but_keeps_a_circuit_switched_off() -> void:
	var lamp := Net.body_device(_root, "Lamp", Vector3(0, 1, 5), [], true)
	await Grenades.seconds(get_tree(), 0.05)
	var powered := Powered.of(lamp)
	var changes: Array[bool] = []
	powered.power_changed.connect(func(on: bool) -> void: changes.append(on))
	powered.take_emp(0.5)
	assert_bool(powered.is_on()).is_false()
	assert_bool(powered.on).is_true()
	await Grenades.seconds(get_tree(), 0.6)
	assert_bool(powered.is_on()).is_true()
	assert_array(changes).is_equal([false, true])
	# Switched off by its circuit during an outage: it stays off afterwards.
	powered.take_emp(0.5)
	powered.on = false
	await Grenades.seconds(get_tree(), 0.6)
	assert_bool(powered.is_on()).is_false()
	assert_array(changes).is_equal([false, true, false])
