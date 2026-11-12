extends GdUnitTestSuite
## Integration (ADR 0127): HitReaction on a minimal character built from components
## (character_fixtures.gd: Tags, Attributes, BodyParts, a receiver with `body_damage`, plus the
## `hit_reaction` receptron, humanoid Hitboxes, an eye 1.6 m up with a WeaponHolder holding the
## pistol and a HitReaction with a test config). The hits are `damage.ballistic` RAY stimuli the test
## emits from 5 m in front of the character (centre to centre, horizontal) at a hitbox: the same
## delivery as a gunshot. The test steps the holder every physics tick, as its owner would.

const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const HITBOXES := preload("res://actors/common/body/hitboxes.tscn")
const HIT_REACTION: Receptron = preload("res://actors/common/hit_reaction/receptrons/hit_reaction.tres")
const PISTOL: WeaponData = preload("res://items/weapons/pistol/pistol.tres")
const STEP := 1.0 / 60.0
const FEET := Vector3(40, 0, 40)

var _root: Node3D
var _body: CharacterBody3D
var _holder: WeaponHolder
var _reaction: HitReaction
var _config: HitReactionConfig


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	add_child(_root)
	var ground := Characters.floor_box(_root)
	ground.position += FEET
	_body = Characters.character(_root, "Target", FEET, [], PhysicsLayers.ACTORS, [HIT_REACTION])
	_body.add_child(HITBOXES.instantiate())
	var eye := Node3D.new()
	eye.name = "Eye"
	eye.position.y = 1.6
	_body.add_child(eye)
	_holder = WeaponHolder.new()
	_holder.name = "WeaponHolder"
	_holder.aim_config = PISTOL.aim_config
	_holder.recoil_enabled = true
	_holder.weapons = [PISTOL] as Array[WeaponData]
	eye.add_child(_holder)
	_holder.setup(_body, eye)
	_holder.equip(0)
	_config = HitReactionConfig.new()
	_config.punch_up_deg = 1.0
	_config.punch_side_deg = 0.5
	_config.punch_recover_time = 0.1
	_config.spread_add_deg = 1.5
	_config.spread_time = 0.3
	_config.flinch_time = 0.3
	_config.stagger_time = 0.5
	_config.stagger_speed_mult = 0.4
	_config.stagger_lean_deg = 12.0
	_reaction = HitReaction.new()
	_reaction.name = "HitReaction"
	_reaction.config = _config
	_reaction.holder_path = ^"../Eye/WeaponHolder"
	_body.add_child(_reaction)
	await _ticks(6)
	_holder.settle()


func after_test() -> void:
	StimulusSystem.clear()


func test_a_hit_punches_the_aim_and_widens_the_cone_for_a_moment() -> void:
	var floor_spread := _holder.aim.spread
	await _shoot(BodyDamageModel.TORSO)
	assert_array(EventLog.find(&"actor.hit_reacted")).has_size(1)
	# Straight from the front: up only (a few ticks of its 0.1 s return already run).
	assert_float(_holder.recoil.punch.y).is_greater(_config.punch_up_deg * 0.4)
	assert_float(absf(_holder.recoil.punch.x)).is_less(0.05)
	assert_float(_holder.aim.spread).is_equal_approx(floor_spread + _config.spread_add_deg, 0.01)
	assert_bool(_reaction.is_flinching()).is_true()
	assert_bool(_reaction.is_staggered()).is_false()
	# After 0.2 s the punch is mostly back and the cone still wide; after 0.5 s the punch, the flinch
	# and the extra floor are gone.
	await _ticks(12)
	assert_float(_holder.recoil.punch.y).is_less(_config.punch_up_deg * 0.2)
	assert_float(_holder.aim.spread).is_greater(floor_spread + _config.spread_add_deg * 0.9)
	assert_bool(_reaction.is_flinching()).is_true()
	await _ticks(18)
	assert_vector(_holder.recoil.punch).is_equal(Vector2.ZERO)
	assert_bool(_reaction.is_flinching()).is_false()
	assert_float(Attributes.read(_body, HitReaction.SPREAD_ATTRIBUTE, 0.0)).is_equal_approx(0.0, 0.0001)
	# The cone settles back at the pistol's settle time (0.8 s): within 0.2 degrees after 2 s more.
	await _ticks(120)
	assert_float(_holder.aim.spread).is_less(floor_spread + 0.2)


func test_a_hit_from_the_left_punches_the_aim_to_the_right() -> void:
	await _shoot(BodyDamageModel.TORSO, Vector3(-5, 0, 0))
	assert_float(_holder.recoil.punch.x).is_greater(_config.punch_side_deg * 0.5)


func test_a_leg_hit_staggers_slows_and_leans_away_from_the_shot() -> void:
	await _shoot(BodyDamageModel.TORSO)
	assert_bool(_reaction.is_staggered()).is_false()
	await _shoot(BodyDamageModel.LEG_L)
	assert_bool(_reaction.is_staggered()).is_true()
	assert_float(Attributes.read(_body, HitReaction.SPEED_ATTRIBUTE, 1.0)).is_equal_approx(0.4, 0.0001)
	await _ticks(6)
	# The shot travels +Z (from the front, the character facing -Z): the top of the body tips back.
	var top := _reaction.lean() * Vector3.UP
	assert_float(top.z).is_greater(sin(deg_to_rad(_config.stagger_lean_deg)) * 0.5)
	await _ticks(30)
	assert_bool(_reaction.is_staggered()).is_false()
	assert_float(Attributes.read(_body, HitReaction.SPEED_ATTRIBUTE, 1.0)).is_equal_approx(1.0, 0.0001)
	assert_bool(_reaction.lean().is_equal_approx(Basis.IDENTITY)).is_true()


func test_an_arm_hit_staggers_too() -> void:
	await _shoot(BodyDamageModel.ARM_R)
	assert_bool(_reaction.is_staggered()).is_true()


func test_no_reaction_to_a_burn_or_when_dead() -> void:
	var burn := Stimulus.make_contact(&"damage.fire", 5.0, _body)
	StimulusSystem.emit(burn)
	await _ticks(2)
	assert_array(EventLog.find(&"actor.hit_reacted")).is_empty()
	assert_vector(_holder.recoil.punch).is_equal(Vector2.ZERO)
	ActorState.set_tag(_body, ActorState.DEAD, true)
	await _shoot(BodyDamageModel.LEG_L)
	assert_array(EventLog.find(&"actor.hit_reacted")).is_empty()
	assert_bool(_reaction.is_staggered()).is_false()


func test_a_save_during_a_stagger_ends_it_after_a_load() -> void:
	await _shoot(BodyDamageModel.LEG_L)
	var attributes := Attributes.of(_body)
	var saved_attributes := attributes.save_state()
	var saved := _reaction.save_state()
	await _ticks(40)
	assert_float(Attributes.read(_body, HitReaction.SPEED_ATTRIBUTE, 1.0)).is_equal_approx(1.0, 0.0001)
	# The Attributes bring the slow-down back with the save; the reaction's timer removes it again.
	attributes.load_state(saved_attributes)
	_reaction.load_state(saved)
	assert_bool(_reaction.is_staggered()).is_true()
	assert_float(Attributes.read(_body, HitReaction.SPEED_ATTRIBUTE, 1.0)).is_equal_approx(0.4, 0.0001)
	await _ticks(40)
	assert_float(Attributes.read(_body, HitReaction.SPEED_ATTRIBUTE, 1.0)).is_equal_approx(1.0, 0.0001)
	_reaction.load_state({})
	assert_bool(_reaction.is_flinching()).is_false()


# A 10-damage ballistic ray at the hitbox `part` from `offset` (default 5 m in front, -Z facing
# character), delivered in the second physics frame; the third steps the holder with it.
func _shoot(part: StringName, offset: Vector3 = Vector3(0, 0, -5)) -> void:
	var box := Hitboxes.of(_body).box(part)
	var target := box.global_position
	var origin := target + offset
	var ray := Stimulus.make_ray(&"damage.ballistic", 10.0, origin, (target - origin).normalized(), 10.0)
	ray.collision_mask = PhysicsLayers.WEAPON_MASK
	StimulusSystem.emit(ray)
	await _ticks(3)


# `count` physics ticks, the holder stepped each tick as its owner would.
func _ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
		_holder.physics_step(STEP, AimModel.Stance.STILL)
