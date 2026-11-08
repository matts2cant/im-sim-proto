extends GdUnitTestSuite
## Integration: the debug panel's alarm buttons (AwarenessToggles, ADR 0077) send `command.trigger`
## and `command.reset` to every alarm controller in the level (group `alarm_controller`), with no
## network reach needed, and show the state.

const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const TOGGLES_SCENE: PackedScene = preload("res://ui/debug_panel/tabs/awareness_toggles.tscn")
const CONTROLLER_SCENE: PackedScene = preload("res://objects/alarm/alarm_controller.tscn")

var _toggles: AwarenessToggles
var _root: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	add_child(_root)
	_toggles = auto_free(TOGGLES_SCENE.instantiate()) as AwarenessToggles
	add_child(_toggles)


func after_test() -> void:
	StimulusSystem.clear()


func test_without_controllers_the_buttons_do_nothing() -> void:
	assert_int(_toggles.raise_level_alarm()).is_equal(0)
	assert_str(AwarenessToggles.state_text_for(AlarmController.all(get_tree()))).is_equal(
		"no alarm controller in level"
	)


func test_raise_and_clear_reach_every_controller() -> void:
	var controllers: Array[AlarmController] = []
	for index in 2:
		var entity := CONTROLLER_SCENE.instantiate() as Node3D
		entity.position = Vector3(index * 3, 1, 0)
		_root.add_child(entity)
		controllers.append(entity.get_node("AlarmControllerBehaviour") as AlarmController)
	await Fixtures.frames(get_tree(), 1)
	assert_str(AwarenessToggles.state_text_for(controllers)).is_equal("off")

	assert_int(_toggles.raise_level_alarm()).is_equal(2)
	await Fixtures.frames(get_tree(), 3)
	for controller in controllers:
		assert_bool(controller.is_ringing()).is_true()
	assert_str(AwarenessToggles.state_text_for(controllers)).is_equal("ALARM 90s")

	assert_int(_toggles.clear_level_alarm()).is_equal(2)
	await Fixtures.frames(get_tree(), 3)
	for controller in controllers:
		assert_bool(controller.is_ringing()).is_false()
	assert_array(EventLog.find(&"alarm.ended")).has_size(2)
