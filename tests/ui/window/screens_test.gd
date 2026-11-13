extends GdUnitTestSuite
## Unit (ADR 0133): Screens, what world objects ask to open a screen. A screen is found among the
## user's children by id (UserScreen.screen_id()) or instanced from the user's Screens component's
## `scenes` on first use; open(), has(), is_open() (on a subject) and close() go through it; a user
## without that screen has none and nothing fails.


class StubScreen:
	extends UserScreen
	var subject: Object
	var opened_by: Node
	var options: Dictionary = {}

	func screen_id() -> StringName:
		return &"stub"

	func open_screen(p_subject: Object, p_user: Node, p_options: Dictionary) -> bool:
		subject = p_subject
		opened_by = p_user
		options = p_options
		visible = true
		return true

	func close_screen() -> void:
		visible = false

	func shows(p_subject: Object) -> bool:
		return visible and p_subject == subject


var _user: Node3D
var _screens: Screens


func before_test() -> void:
	_user = auto_free(Node3D.new()) as Node3D
	add_child(_user)
	_screens = Screens.new()
	_user.add_child(_screens)


func test_opens_a_child_screen_by_id_on_a_subject() -> void:
	var stub := StubScreen.new()
	stub.visible = false
	_user.add_child(stub)
	var subject := RefCounted.new()

	assert_bool(Screens.has(_user, &"stub")).is_true()
	assert_bool(Screens.open(_user, &"stub", subject, {&"mode": 2})).is_true()

	assert_object(stub.opened_by).is_same(_user)
	assert_int(int(stub.options[&"mode"])).is_equal(2)
	assert_bool(Screens.is_open(_user, &"stub")).is_true()
	assert_bool(Screens.is_open(_user, &"stub", subject)).is_true()
	assert_bool(Screens.is_open(_user, &"stub", RefCounted.new())).is_false()
	Screens.close(_user, &"stub", RefCounted.new())
	assert_bool(stub.visible).is_true()
	Screens.close(_user, &"stub")
	assert_bool(stub.visible).is_false()


func test_a_user_without_the_screen_or_the_component_has_none() -> void:
	assert_bool(Screens.has(_user, &"stub")).is_false()
	assert_bool(Screens.open(_user, &"stub", null)).is_false()
	assert_bool(Screens.is_open(_user, &"stub")).is_false()
	Screens.close(_user, &"stub")
	var bare: Node3D = auto_free(Node3D.new())
	assert_bool(Screens.open(bare, &"stub", null)).is_false()
	assert_bool(Screens.has(null, &"stub")).is_false()
	# A screen child is found without the component too (only made-on-demand screens need it).
	var stub := StubScreen.new()
	bare.add_child(stub)
	assert_bool(Screens.open(bare, &"stub", null)).is_true()


func test_a_registered_scene_is_instanced_on_first_use() -> void:
	_screens.scenes = {TuningDesk.SCREEN: load("res://ui/tuning_panel/tuning_panel.tscn") as PackedScene}
	assert_bool(Screens.has(_user, TuningDesk.SCREEN)).is_true()
	assert_object(Screens.find(_user, TuningDesk.SCREEN)).is_null()

	var panel := Screens.screen_of(_user, TuningDesk.SCREEN)

	assert_object(panel).is_instanceof(TuningPanel)
	assert_object(panel.get_parent()).is_same(_user)
	assert_object(Screens.screen_of(_user, TuningDesk.SCREEN)).is_same(panel)
