extends GdUnitTestSuite
## TuningPanel (ADR 0125) for a minimal user holding a test weapon whose tuning names the panel
## never sees: a slider per `@export_range` value of the weapon and of the resource it references,
## moving one changes the live resource at once, the skill tier buttons set the tier of the skill
## training the weapon (its class attributes change), Esc and the ✕ close it, walking away closes
## it, no weapon in hand says so. The window is the shared WindowFrame.

const TestWeapon := preload("res://tests/ui/tuning_panel/fixtures/tuning_test_weapon.gd")
const TestPart := preload("res://tests/ui/tuning_panel/fixtures/tuning_test_part.gd")
const SKILL_TABLE: SkillTable = preload("res://actors/common/abilities/skill_table.tres")
const AIM: AimConfig = preload("res://items/weapons/aim_untrained.tres")
const ORIGIN := Vector3(-360, 0, 300)

var _root: Node3D
var _user: Node3D
var _weapon: TestWeapon
var _panel: TuningPanel


func before_test() -> void:
	EventLog.clear()
	_root = auto_free(Node3D.new())
	_root.position = ORIGIN
	add_child(_root)
	_weapon = TestWeapon.new()
	_weapon.id = &"test_gun"
	_weapon.display_name = "Test gun"
	_weapon.attribute_class = &"pistol"
	_weapon.part = TestPart.new()
	_user = _make_user(_weapon)
	_panel = TuningPanel.new()
	_root.add_child(_panel)


func after_test() -> void:
	if _panel != null and _panel.is_open():
		_panel.close()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_lists_every_range_value_of_the_weapon_and_its_resources() -> void:
	_panel.open_for(_user)

	assert_bool(_panel.is_open()).is_true()
	assert_object(_panel.panel).is_instanceof(WindowFrame)
	assert_str(_panel.weapon_label.text).is_equal("Test gun")
	var keys := _panel.slider_keys()
	assert_array(keys).contains(["/kick", "/burst", "part/climb"])
	assert_array(keys).not_contains(["/plain", "part/note"])
	# Each slider shows the live value and the property's range.
	var kick := _panel.slider("", "kick")
	assert_float(kick.value).is_equal_approx(1.0, 0.0001)
	assert_float(kick.max_value).is_equal(5.0)
	assert_float(_panel.slider("part", "climb").value).is_equal_approx(6.0, 0.0001)


func test_moving_a_slider_changes_the_live_resource() -> void:
	_panel.open_for(_user)

	_panel.slider("", "kick").value = 2.3
	_panel.slider("part", "climb").value = 12.5

	assert_float(_weapon.kick).is_equal_approx(2.3, 0.0001)
	assert_float(_weapon.part.climb).is_equal_approx(12.5, 0.0001)


func test_tier_buttons_set_the_skill_of_the_weapon() -> void:
	_panel.open_for(_user)

	_panel.tier_buttons[SkillTable.MASTER].pressed.emit()

	assert_int(Skills.of(_user).tier(&"pistols")).is_equal(SkillTable.MASTER)
	assert_float(Attributes.read(_user, &"pistol_spread_mult", 1.0)).is_equal_approx(0.4, 0.0001)
	assert_bool(_panel.tier_buttons[SkillTable.MASTER].button_pressed).is_true()
	assert_bool(_panel.tier_buttons[SkillTable.UNTRAINED].button_pressed).is_false()
	assert_str(_panel.tier_label.text).is_equal("Pistols: Master")


func test_esc_and_the_close_button_close_it() -> void:
	_panel.open_for(_user)
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true

	get_viewport().push_input(esc)

	assert_bool(_panel.is_open()).is_false()
	_panel.open_for(_user)
	_panel.panel.close_requested.emit()
	assert_bool(_panel.is_open()).is_false()


func test_walking_away_from_the_desk_closes_it() -> void:
	var desk := Node3D.new()
	_root.add_child(desk)
	_panel.open_for(_user, desk, 3.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_bool(_panel.is_open()).is_true()

	_user.position = Vector3(5, 0, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_bool(_panel.is_open()).is_false()


func test_without_a_weapon_it_says_so() -> void:
	WeaponSkill.holder_of(_user).holster()

	_panel.open_for(_user)

	assert_str(_panel.weapon_label.text).is_equal(TuningPanel.NO_WEAPON)
	assert_array(_panel.slider_keys()).is_empty()
	assert_bool(_panel.save_button.disabled).is_true()


func _make_user(weapon: WeaponData) -> Node3D:
	var user := Node3D.new()
	user.name = "User"
	var attributes := Attributes.new()
	attributes.name = "Attributes"
	user.add_child(attributes)
	var skills := Skills.new()
	skills.name = "Skills"
	skills.table = SKILL_TABLE
	user.add_child(skills)
	var holder := WeaponHolder.new()
	holder.name = "WeaponHolder"
	holder.aim_config = AIM
	holder.weapons = [weapon]
	user.add_child(holder)
	_root.add_child(user)
	holder.equip(0)
	return user
