extends GdUnitTestSuite
## Integration (ADR 0078): the breakable door (`objects/door/breakable_door.tscn`, health 50,
## reinforced material: explosive x1, ballistic / blunt / stun / fire x0). Explosions break it;
## pistol rounds (25 ballistic) and baton hits (20 stun + 5 blunt) do not. Broken, its panel is gone
## for good: passable, silent, `state.broken` (remote commands blocked), and it stays broken through
## save and load.

const Wait := preload("res://tests/helpers/wait.gd")
const Helpers := preload("res://tests/objects/door/door_helpers.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const BREAKABLE_DOOR: PackedScene = preload("res://objects/door/breakable_door.tscn")

var _root: Node3D
var _entity: StaticBody3D
var _door: Door


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	add_child(_root)
	_entity = BREAKABLE_DOOR.instantiate() as StaticBody3D
	_root.add_child(_entity)
	_door = Door.of(_entity)
	Helpers.lock(_entity)
	await Wait.frames(get_tree(), 2)


func test_pistol_rounds_and_baton_hits_do_not_break_it() -> void:
	for i in 6:
		await _hit(&"damage.ballistic", 25.0)
	for i in 6:
		await _hit(&"damage.stun", 20.0)
		await _hit(&"damage.blunt", 5.0)

	assert_bool(_door.broken).is_false()
	assert_float(Attributes.of(_entity).value(&"health")).is_equal(50.0)
	assert_bool((_entity.get_node("Panel") as CollisionShape3D).disabled).is_false()


func test_an_explosion_breaks_it_open_for_good() -> void:
	# A blast 1 m from the door's centre: 100 x (1 - 1/4) = 75 explosive damage.
	var blast := Stimulus.make_radius(&"damage.explosive", 100.0, Vector3(0, 1.1, 1.0), 4.0, _root)
	StimulusSystem.emit(blast)
	await Wait.frames(get_tree(), 3)

	assert_bool(_door.broken).is_true()
	assert_bool(is_instance_valid(_entity) and _entity.is_inside_tree()).is_true()
	assert_bool(ActorState.has(_entity, &"state.broken")).is_true()
	assert_bool((_entity.get_node("Panel") as CollisionShape3D).disabled).is_true()
	assert_bool((_entity.get_node("SoundAttenuator") as SoundAttenuator).enabled).is_false()
	var link := _entity.get_node("NavigationLink3D") as NavigationLink3D
	assert_int(link.navigation_layers).is_equal(AccessLayers.WALK)
	assert_bool(_door.is_passable()).is_true()
	assert_array(EventLog.find(&"object.broken")).has_size(1)

	# Remote commands no longer reach it; E offers nothing.
	StimulusSystem.emit(Stimulus.make_contact(&"command.close", 1.0, _entity, _root))
	await Wait.frames(get_tree(), 2)
	assert_array(EventLog.find(&"door.command")).is_empty()
	assert_bool(_door.available(null)).is_false()


func test_a_far_explosion_does_not_break_it() -> void:
	# 3 m from the centre: 100 x (1 - 3/4) = 25 < 50.
	var blast := Stimulus.make_radius(&"damage.explosive", 100.0, Vector3(0, 1.1, 3.0), 4.0, _root)
	StimulusSystem.emit(blast)
	await Wait.frames(get_tree(), 3)

	assert_bool(_door.broken).is_false()
	assert_float(Attributes.of(_entity).value(&"health")).is_between(24.0, 26.0)


func test_stays_broken_after_load() -> void:
	var saved := _door.save_state()
	_door.load_state({"open": false, "broken": true})

	assert_bool(_door.broken).is_true()
	assert_bool((_entity.get_node("Panel") as CollisionShape3D).disabled).is_true()
	assert_bool(Breakable.of(_entity).is_broken).is_true()
	assert_bool(saved["broken"]).is_false()


func _hit(type: StringName, amount: float) -> void:
	StimulusSystem.emit(Stimulus.make_contact(type, amount, _entity, _root))
	await Wait.frames(get_tree(), 2)
