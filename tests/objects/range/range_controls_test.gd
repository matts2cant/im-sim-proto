extends GdUnitTestSuite
## The range's controls (ADR 0125): BodyResetButton stands downed bodies (dead or knocked out) back
## up when they carry its tag and leaves the rest alone; CallButton calls its method on its targets;
## SkillTierSwitch moves the user's tier of the skill training the weapon in its hand (through
## Skills, so the weapon's class attributes change). Minimal users and bodies built in code.

const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const DUMMY: PackedScene = preload("res://actors/dummy/training_dummy.tscn")
const SKILL_TABLE: SkillTable = preload("res://actors/common/abilities/skill_table.tres")
const PISTOL: WeaponData = preload("res://items/weapons/pistol/pistol.tres")
const AIM: AimConfig = preload("res://items/weapons/aim_untrained.tres")
const ORIGIN := Vector3(-340, 0, 300)

var _root: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	_root.position = ORIGIN
	add_child(_root)


func test_reset_button_stands_dead_and_knocked_out_dummies_up() -> void:
	var dead := _dummy("Dead", 0.0)
	var out := _dummy("Out", 2.0)
	var standing := _dummy("Standing", 4.0)
	var other := Characters.character(_root, "Other", ORIGIN + Vector3(6, 0, 0))
	var button := _reset_button()
	await _frames(2)
	dead.body.take_damage(&"damage.ballistic", 500.0, &"head")
	out.body.take_damage(&"damage.stun", 500.0)
	var other_body := other.get_node("BodyParts") as BodyParts
	other_body.take_damage(&"damage.ballistic", 500.0, &"head")
	assert_bool(dead.body.is_dead()).is_true()
	assert_bool(out.body.is_unconscious()).is_true()

	button.use(null)
	await _frames(2)

	for dummy: TrainingDummy in [dead, out, standing]:
		assert_bool(dummy.body.is_dead() or dummy.body.is_unconscious()).override_failure_message(dummy.name).is_false()
		assert_bool(dummy.is_down).override_failure_message(dummy.name).is_false()
	# Not a dummy (no `actor.dummy` tag): left as it is.
	assert_bool(other_body.is_dead()).is_true()
	var logged := EventLog.find(&"range.bodies_reset")
	assert_array(logged).has_size(1)
	assert_int(logged[0].data["count"]).is_equal(2)


func test_call_button_calls_its_method_on_its_targets() -> void:
	var marks := ImpactMarks.new()
	marks.name = "Marks"
	_root.add_child(marks)
	marks.add_mark(ORIGIN, Vector3.BACK)
	var button := CallButton.new()
	button.targets = [NodePath("../Marks")]
	button.method = &"clear"
	_root.add_child(button)

	button.use(null)

	assert_int(marks.count()).is_equal(0)


func test_tier_switch_cycles_the_held_weapons_skill() -> void:
	var user := _user()
	var label := Label3D.new()
	label.name = "Label"
	_root.add_child(label)
	var switch := SkillTierSwitch.new()
	_root.add_child(switch)
	var skills := Skills.of(user)
	assert_str(String(WeaponSkill.skill_of(user))).is_equal("pistols")
	assert_float(Attributes.read(user, &"pistol_spread_mult", 1.0)).is_equal_approx(1.0, 0.0001)

	for i in 3:
		switch.use(user)

	assert_int(skills.tier(&"pistols")).is_equal(SkillTable.MASTER)
	assert_float(Attributes.read(user, &"pistol_spread_mult", 1.0)).is_equal_approx(0.4, 0.0001)
	assert_str(label.text).contains("Pistols: Master")
	# Master wraps round to Untrained.
	switch.use(user)
	assert_int(skills.tier(&"pistols")).is_equal(SkillTable.UNTRAINED)


func test_tier_switch_without_a_weapon_changes_nothing() -> void:
	var user := _user()
	WeaponSkill.holder_of(user).holster()
	var switch := SkillTierSwitch.new()
	_root.add_child(switch)

	switch.use(user)

	assert_int(Skills.of(user).tier(&"pistols")).is_equal(SkillTable.UNTRAINED)


func _dummy(dummy_name: String, x: float) -> TrainingDummy:
	var dummy := DUMMY.instantiate() as TrainingDummy
	dummy.name = dummy_name
	dummy.position = Vector3(x, 0, 0)
	_root.add_child(dummy)
	return dummy


func _reset_button() -> BodyResetButton:
	var button := BodyResetButton.new()
	button.scope_path = NodePath("..")
	_root.add_child(button)
	return button


## A user holding the pistol, with Attributes and Skills (every skill Untrained).
func _user() -> Node3D:
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
	holder.weapons = [PISTOL]
	user.add_child(holder)
	_root.add_child(user)
	holder.equip(0)
	return user


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
