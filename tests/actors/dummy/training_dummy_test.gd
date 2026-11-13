extends GdUnitTestSuite
## Integration: the player's pistol and baton against a training dummy (hit location, headshots,
## floating numbers, knockout from behind and from the front, reset; a standing dummy holds still).

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Weapons := preload("res://tests/items/weapons/weapon_test_helpers.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")

var _driver: PlayerDriver
var _weapons: Weapons
var _dummy: TrainingDummy


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_pistol_headshot_deals_50_and_shows_it() -> void:
	await _load()
	await _weapons.equip(1)
	await _weapons.aim_at(Vector3.ZERO, Weapons.part_position(_dummy, &"head"))

	await _weapons.fire()

	var hits := Weapons.damaged(&"head")
	assert_array(hits).has_size(1)
	assert_float(hits[0].data["amount"]).is_equal(50.0)
	assert_str(hits[0].data["type"]).is_equal("damage.ballistic")
	assert_str(hits[0].target).is_equal("TrainingDummy")
	assert_array(Array((_dummy.get_node("DamageNumbers") as DamageNumbers).texts())).contains(["head 50"])
	# Dummy head 40: a headshot kills it and it tips over.
	assert_bool(_dummy.body.is_dead()).is_true()
	assert_array(EventLog.find(&"actor.died")).has_size(1)


func test_pistol_torso_shot_deals_25() -> void:
	await _load()
	await _weapons.equip(1)
	await _weapons.aim_at(Vector3.ZERO, Weapons.part_position(_dummy, &"torso"))

	await _weapons.fire()

	var hits := Weapons.damaged(&"torso")
	assert_array(hits).has_size(1)
	assert_float(hits[0].data["amount"]).is_equal(25.0)
	assert_float(_dummy.body.health(&"torso")).is_equal(55.0)
	assert_float(_dummy.body.health(&"head")).is_equal(40.0)
	assert_array(Array((_dummy.get_node("DamageNumbers") as DamageNumbers).texts())).contains(["torso 25"])
	assert_bool(_dummy.body.is_dead()).is_false()


func test_leg_shot_hits_the_leg() -> void:
	await _load()
	await _weapons.equip(1)
	# The dummy faces the player (rotated 180 degrees): its left leg is on the player's right.
	var leg := Weapons.part_position(_dummy, &"leg_l")
	assert_float(leg.x).is_greater(0.0)
	await _weapons.aim_at(Vector3.ZERO, leg)

	await _weapons.fire()

	assert_array(Weapons.damaged(&"leg_l")).has_size(1)
	assert_float(_dummy.body.health(&"leg_l")).is_equal(25.0)


func test_baton_from_behind_on_unaware_dummy_knocks_out_in_one_hit() -> void:
	await _load()
	_dummy.rotation.y = 0.0
	await _weapons.equip(2)
	# The dummy faces -Z; the player stands behind it (on +Z). Aimed at the lower torso: the swept
	# 0.2 m sphere aimed at the torso centre from the eye grazes the back of the 0.53 m head box
	# (ADR 0105) on its way down.
	var lower_torso := Weapons.part_position(_dummy, &"torso") + Vector3.DOWN * 0.15
	await _weapons.aim_at(Vector3(0, 0, -1.7), lower_torso)

	await _weapons.fire()

	var stunned := EventLog.find(&"actor.stunned")
	assert_array(stunned).has_size(1)
	assert_bool(stunned[0].data["behind"]).is_true()
	assert_bool(stunned[0].data["aware"]).is_false()
	assert_float(stunned[0].data["amount"]).is_equal(200.0)
	assert_bool(_dummy.body.is_unconscious()).is_true()
	assert_array(EventLog.find(&"actor.knocked_out")).has_size(1)
	assert_bool((_dummy.get_node("Tags") as Tags).has(&"state.unconscious")).is_true()
	# The blunt part of the hit lands on the torso hitbox.
	var blunt := Objects.logged(&"actor.damaged", "type", &"damage.blunt")
	assert_array(blunt).has_size(1)
	assert_str(blunt[0].data["part"]).is_equal("torso")
	await _driver.frames(40)
	assert_bool((_dummy.get_node("DownedPose") as DownedPose).is_down).is_true()
	assert_float(_dummy.hitboxes.rotation.x).is_equal_approx(PI / 2.0, 0.01)
	# The model plays its down clip (ADR 0103).
	var animator := _dummy.get_node("Animator") as CharacterAnimator
	assert_float(animator.weight_of(animator.config.unconscious_clip)).is_equal(1.0)


func test_baton_from_the_front_takes_three_hits() -> void:
	await _load()
	await _weapons.equip(2)
	await _weapons.aim_at(Vector3(0, 0, -1.7), Weapons.part_position(_dummy, &"torso"))

	for hit in 2:
		await _weapons.fire(40)
		assert_bool(_dummy.body.is_unconscious()).is_false()
	await _weapons.fire(4)

	var stunned := EventLog.find(&"actor.stunned")
	assert_array(stunned).has_size(3)
	assert_bool(stunned[0].data["behind"]).is_false()
	assert_float(_dummy.body.stun).is_equal(60.0)
	assert_bool(_dummy.body.is_unconscious()).is_true()


func test_aware_dummy_from_behind_takes_three_hits() -> void:
	await _load()
	_dummy.rotation.y = 0.0
	(_dummy.get_node("Awareness") as Awareness).aware = true
	await _weapons.equip(2)
	await _weapons.aim_at(Vector3(0, 0, -1.7), Weapons.part_position(_dummy, &"torso"))

	await _weapons.fire(40)

	assert_float(_dummy.body.stun).is_equal(20.0)
	assert_bool(_dummy.body.is_unconscious()).is_false()


func test_reset_restores_health_consciousness_and_pose() -> void:
	await _load()
	_dummy.rotation.y = 0.0
	await _weapons.equip(2)
	await _weapons.aim_at(Vector3(0, 0, -1.7), Weapons.part_position(_dummy, &"torso"))
	await _weapons.fire(40)
	assert_bool((_dummy.get_node("DownedPose") as DownedPose).is_down).is_true()

	# `use` on the lying dummy resets it (the baton is still out; use is not a weapon action).
	await _weapons.aim_at(Vector3(0, 0, -1.7), Weapons.part_position(_dummy, &"torso"))
	await _driver.hold(&"use", 2)
	await _driver.frames(2)

	assert_bool(_dummy.body.is_unconscious()).is_false()
	assert_float(_dummy.body.stun).is_equal(0.0)
	assert_float(_dummy.body.health(&"torso")).is_equal(80.0)
	assert_bool((_dummy.get_node("DownedPose") as DownedPose).is_down).is_false()
	assert_float(_dummy.hitboxes.rotation.x).is_equal_approx(0.0, 0.001)
	# The model stands up again (ADR 0103).
	var animator := _dummy.get_node("Animator") as CharacterAnimator
	assert_str(String(animator.state.down_clip())).is_empty()
	await _driver.frames(40)
	assert_float(animator.weight_of(animator.config.idle_clip)).is_equal(1.0)
	assert_float(animator.weight_of(animator.config.unconscious_clip)).is_equal(0.0)
	assert_bool((_dummy.get_node("Tags") as Tags).has(&"state.unconscious")).is_false()
	assert_array(EventLog.find(&"actor.reset")).has_size(1)


func test_a_standing_dummy_stands_still() -> void:
	await _load()
	# A mannequin (ADR 0105): its animator's idle clip is `static`, so no part moves.
	var animator := _dummy.get_node("Animator") as CharacterAnimator
	var start: Dictionary[StringName, Transform3D] = {}
	for part_name: StringName in [&"torso", &"head", &"arm-left", &"arm-right", &"leg-left", &"leg-right"]:
		start[part_name] = animator.part(part_name).transform
	await _driver.frames(120)
	assert_float(animator.weight_of(&"static")).is_equal(1.0)
	for part_name: StringName in start:
		assert_bool(animator.part(part_name).transform.is_equal_approx(start[part_name])).is_true()


func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(Weapons.DUMMY_RANGE))
	_weapons = Weapons.new(_driver)
	_dummy = _driver.runner.find_child("TrainingDummy") as TrainingDummy
	await _driver.settle()
