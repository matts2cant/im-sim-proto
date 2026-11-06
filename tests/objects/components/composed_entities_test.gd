extends GdUnitTestSuite
## Integration: the object components work on any entity that has them, not only on the props that
## ship with them. Each entity here is built in code from components and tuning made in the test
## (StimulusFixtures + ObjectTestHelpers builders): no crate, barrel or bottle scene.

const Objects := preload("res://tests/objects/object_test_helpers.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const FLOOR := "res://tests/objects/fixtures/object_floor.tscn"
const HEAT_FROM_FIRE: Receptron = preload("res://objects/components/receptrons/heat_from_fire.tres")
const TAKE_DAMAGE: Receptron = preload("res://objects/components/receptrons/take_damage.tres")
const PUSHED: Receptron = preload("res://objects/components/receptrons/pushed_by_force.tres")

var _floor: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_floor = auto_free(load(FLOOR).instantiate())
	add_child(_floor)
	await Objects.frames(get_tree(), 5)


func test_minimal_flammable_ignites_pulses_and_burns_out() -> void:
	var torch := Fixtures.entity(_floor, "Torch", Vector3(0, 1, 0), [HEAT_FROM_FIRE])
	var flammable := Objects.add_flammable(torch, Objects.fire_config(3.0, 1.0))
	var spark := Stimulus.make_contact(&"fire", 5.0, torch)

	StimulusSystem.emit(spark)
	await Objects.frames(get_tree(), 3)

	assert_bool(flammable.is_burning()).is_true()
	assert_bool(Fixtures.tags_of(torch).has(&"state.burning")).is_true()
	assert_array(Objects.logged(&"object.ignited", "by", spark.id)).has_size(1)
	var pulses := EventLog.find(&"stimulus.emitted").filter(
		func(entry: EventLogEntry) -> bool: return entry.source == "Torch" and entry.data["type"] == &"fire"
	)
	assert_int(pulses[0].data["cause_id"]).is_equal(spark.id)

	# 1 s of fuel.
	await Objects.frames(get_tree(), 70)
	assert_bool(flammable.is_burning()).is_false()
	assert_bool(Fixtures.tags_of(torch).has(&"state.charred")).is_true()
	assert_array(Objects.logged(&"object.burnt_out", "object", "Torch")).has_size(1)
	# No Breakable: it stays, charred.
	assert_bool(is_instance_valid(torch)).is_true()


func test_minimal_fire_spreads_to_a_minimal_neighbour() -> void:
	var torch := Fixtures.entity(_floor, "Torch", Vector3(0, 1, 0), [HEAT_FROM_FIRE])
	Objects.add_flammable(torch, Objects.fire_config(3.0, 5.0))
	# 0.5 m away: each 2.0 / 1.5 m pulse gives 2.0 x (1 - 0.5 / 1.5) = 1.33 heat; ignites at 3.
	var straw := Fixtures.entity(_floor, "Straw", Vector3(0.5, 1, 0), [HEAT_FROM_FIRE])
	var straw_fire := Objects.add_flammable(straw, Objects.fire_config(3.0, 5.0))

	StimulusSystem.emit(Stimulus.make_contact(&"fire", 5.0, torch))
	await Objects.frames(get_tree(), 100)

	assert_bool(straw_fire.is_burning()).is_true()


func test_explosive_without_breakable_goes_off_from_heat() -> void:
	var canister := Fixtures.entity(_floor, "Canister", Vector3(0, 1, 0), [HEAT_FROM_FIRE])
	Objects.add_explosive(canister, Objects.explosive_config(3.0))
	var spark := Stimulus.make_contact(&"fire", 5.0, canister)

	StimulusSystem.emit(spark)
	await Objects.frames(get_tree(), 3)

	assert_array(Objects.logged(&"object.exploded", "object", "Canister")).has_size(1)
	var types := (
		EventLog
		. find(&"stimulus.emitted")
		. filter(func(entry: EventLogEntry) -> bool: return entry.source == "Canister")
		. map(func(entry: EventLogEntry) -> StringName: return entry.data["type"])
	)
	assert_array(types).contains_exactly_in_any_order([&"force.blast", &"damage.explosive", &"fire", &"noise"])
	assert_bool(is_instance_valid(canister)).is_false()


func test_breakable_explosive_crate_blows_up_and_pushes_a_minimal_body() -> void:
	# A wooden "crate" that explodes instead of breaking: Breakable (health 20) + Explosive.
	var crate := Fixtures.rigid_entity(_floor, "Bomb", Vector3(0, 0.2, 0), [TAKE_DAMAGE])
	Objects.add_breakable(crate, 20.0, false)
	Objects.add_explosive(crate, Objects.explosive_config(50.0, 30.0))
	var probe := Fixtures.rigid_entity(_floor, "Probe", Vector3(1.5, 1.2, 0), [PUSHED], [], 0.4, 2.0, 0.0)
	await Objects.frames(get_tree(), 10)
	var hit := Stimulus.make_contact(&"damage.blunt", 25.0, crate)

	StimulusSystem.emit(hit)
	await Objects.frames(get_tree(), 4)

	var exploded := Objects.logged(&"object.exploded", "object", "Bomb")
	assert_array(exploded).has_size(1)
	assert_int(exploded[0].data["by"]).is_equal(hit.id)
	assert_array(Objects.logged(&"object.broken", "object", "Bomb")).is_empty()
	# Pushed away from the blast (up and east).
	assert_float(probe.linear_velocity.x).is_greater(1.0)
	assert_float(probe.linear_velocity.y).is_greater(0.0)


func test_impact_noise_on_a_body_that_is_not_a_crate() -> void:
	# A 2 kg metal block dropped from 1.5 m (bottom 1.3 m above the floor).
	var block := Fixtures.rigid_entity(_floor, "Block", Vector3(0, 1.5, 0), [], [], 0.4, 2.0)
	var noise := ImpactNoise.new()
	noise.material = load("res://objects/materials/metal.tres") as MaterialProfile
	noise.settings = load("res://objects/components/impact_settings.tres") as ImpactSettings
	block.add_child(noise)

	await Objects.frames(get_tree(), 60)

	var impacts := Objects.logged(&"object.impact", "object", "Block")
	assert_array(impacts).is_not_empty()
	assert_str(impacts[0].data["other"]).is_equal("Floor")
	var heard := EventLog.find(&"stimulus.emitted").filter(
		func(entry: EventLogEntry) -> bool: return entry.source == "Block" and entry.data["type"] == &"noise"
	)
	assert_float(heard[0].data["intensity"]).is_equal_approx(impacts[0].data["loudness"], 0.0001)


func test_burning_carried_object_burns_a_carrier_that_is_not_the_player() -> void:
	# The carrier (any Node3D with a damage receptron) is 5 m away: out of the 1.5 m pulse radius,
	# so only the carried object's CONTACT reaches it.
	var hurt := Fixtures.receptron(&"damage.fire", [Fixtures.add_tag(&"state.scorched")], "scorch")
	var carrier := Fixtures.entity(_floor, "Porter", Vector3(5, 1, 0), [hurt])
	var torch := Fixtures.rigid_entity(_floor, "Torch", Vector3(0, 1, 0), [HEAT_FROM_FIRE], [], 0.3, 1.0, 0.0)
	Objects.add_flammable(torch, Objects.fire_config(3.0, 5.0))
	var carryable := Carryable.new()
	torch.add_child(carryable)
	carryable.set_carrier(carrier)

	StimulusSystem.emit(Stimulus.make_contact(&"fire", 5.0, torch))
	await Objects.frames(get_tree(), 5)

	var burns := EventLog.find(&"stimulus.received").filter(
		func(entry: EventLogEntry) -> bool: return entry.target == "Porter" and entry.data["type"] == &"damage.fire"
	)
	assert_array(burns).is_not_empty()
	assert_str(burns[0].data["collider"]).is_equal("Porter")
	assert_bool(Fixtures.tags_of(carrier).has(&"state.scorched")).is_true()
