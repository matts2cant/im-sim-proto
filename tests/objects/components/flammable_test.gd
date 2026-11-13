extends GdUnitTestSuite
## Integration: Flammable ignition, fire pulses (fresh chains carrying cause_id), burn-out, saving.

const Wait := preload("res://tests/helpers/wait.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const FLOOR := "res://tests/objects/fixtures/object_floor.tscn"

var _floor: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_floor = auto_free(load(FLOOR).instantiate())
	add_child(_floor)
	await Wait.frames(get_tree(), 5)


func test_ignites_at_threshold_and_pulses_every_half_second() -> void:
	var crate := Objects.spawn(_floor, Objects.SMALL_CRATE, Vector3(0, 0.3, 0))
	await Wait.frames(get_tree(), 2)
	var spark := Stimulus.make_contact(&"fire", 100.0, crate)

	StimulusSystem.emit(spark)
	await Wait.frames(get_tree(), 40)

	var flammable := Flammable.of(crate)
	assert_bool(flammable.is_burning()).is_true()
	assert_bool((crate.get_node("Tags") as Tags).has(&"state.burning")).is_true()
	assert_array(Objects.logged(&"object.ignited", "by", spark.id)).has_size(1)
	var pulses := EventLog.find(&"stimulus.emitted").filter(
		func(entry: EventLogEntry) -> bool: return entry.source == "SmallCrate" and entry.data["type"] == &"fire"
	)
	assert_array(pulses).has_size(2)
	assert_int(pulses[1].tick - pulses[0].tick).is_equal(30)
	for pulse: EventLogEntry in pulses:
		assert_int(pulse.data["depth"]).is_equal(0)
		assert_int(pulse.data["cause_id"]).is_equal(spark.id)
		assert_float(pulse.data["intensity"]).is_equal(2.0)
	var light := crate.find_children("Light", "OmniLight3D", true, false)
	assert_array(light).has_size(1)
	assert_float((light[0] as OmniLight3D).omni_range).is_equal_approx(4.5, 0.0001)


func test_heat_below_threshold_cools_away() -> void:
	var crate := Objects.spawn(_floor, Objects.SMALL_CRATE, Vector3(0, 0.3, 0))
	await Wait.frames(get_tree(), 2)

	StimulusSystem.emit(Stimulus.make_contact(&"fire", 3.0, crate))
	await Wait.frames(get_tree(), 2)
	var flammable := Flammable.of(crate)
	assert_float(flammable.heat()).is_between(2.95, 3.0)

	await Wait.frames(get_tree(), 60)
	assert_float(flammable.heat()).is_between(2.45, 2.5)
	assert_bool(flammable.is_burning()).is_false()


func test_burns_out_charred_then_breaks() -> void:
	var box := Objects.spawn(_floor, Objects.CARDBOARD_BOX, Vector3(0, 0.25, 0))
	await Wait.frames(get_tree(), 2)
	var flammable := Flammable.of(box)
	var tags_at_burn_out: Array[StringName] = []
	flammable.burnt_out.connect(
		func() -> void: tags_at_burn_out.append_array((box.get_node("Tags") as Tags).container.tags())
	)

	flammable.ignite(null)
	flammable.fuel_left = 0.2
	await Wait.frames(get_tree(), 20)

	assert_array(tags_at_burn_out).contains([&"state.charred"]).not_contains([&"state.burning"])
	var kinds := EventLog.entries().map(func(entry: EventLogEntry) -> StringName: return entry.kind)
	assert_int(kinds.find(&"object.burnt_out")).is_less(kinds.find(&"object.broken"))
	assert_array(Objects.logged(&"object.broken", "reason", &"burnt_out")).has_size(1)
	assert_bool(is_instance_valid(box)).is_false()


func test_save_and_load_restore_fire_state() -> void:
	var crate := Objects.spawn(_floor, Objects.SMALL_CRATE, Vector3(0, 0.3, 0))
	await Wait.frames(get_tree(), 2)
	var flammable := Flammable.of(crate)
	flammable.ignite(null)
	flammable.fuel_left = 12.5
	var saved := flammable.save_state()
	var body_saved := (crate as PhysicsObject).save_state()

	var fresh := Objects.spawn(_floor, Objects.SMALL_CRATE, Vector3(3, 0.3, 0), "Fresh")
	await Wait.frames(get_tree(), 2)
	var restored := Flammable.of(fresh)
	restored.load_state(saved)

	assert_bool(restored.is_burning()).is_true()
	assert_float(restored.fuel_left).is_equal_approx(12.5, 0.0001)
	assert_array(fresh.find_children("FireFx", "", true, false)).has_size(1)
	assert_str(body_saved["scene_file_path"]).is_equal(Objects.SMALL_CRATE)
	assert_bool(body_saved.has("transform") and body_saved.has("linear_velocity")).is_true()
	assert_bool(fresh.is_in_group(&"saveable") and restored.is_in_group(&"saveable")).is_true()


func test_brazier_burns_forever() -> void:
	var brazier := Objects.spawn(_floor, Objects.BRAZIER, Vector3(0, 0, 0))
	await Wait.frames(get_tree(), 5)

	var flammable := Flammable.of(brazier)
	assert_bool(flammable.is_burning()).is_true()
	assert_bool(flammable.config.permanent).is_true()
	assert_array(Objects.logged(&"object.burnt_out")).is_empty()
	var pulses := EventLog.find(&"stimulus.emitted").filter(
		func(entry: EventLogEntry) -> bool: return entry.source == "Brazier"
	)
	assert_vector(pulses[0].data["origin"]).is_equal_approx(Vector3(0, 0.45, 0), Vector3.ONE * 0.001)
