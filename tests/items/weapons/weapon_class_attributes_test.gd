extends GdUnitTestSuite
## Integration (ADR 0101): the class attributes the Rifles and Sniper skills write reach any holder
## through its user's Attributes, not through a skill check: a minimal character built in code (no
## Player, no Skills) with plain modifiers gets a narrower shotgun pellet cone (`rifle_spread_mult`)
## and a steadier sniper rifle (`sniper_sway_mult`, stacking with an injury's `aim_sway_mult`); a
## class modifier leaves the other classes alone.

const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const SHOTGUN: WeaponData = preload("res://items/weapons/shotgun/shotgun.tres")
const SNIPER: WeaponData = preload("res://items/weapons/sniper_rifle/sniper_rifle.tres")
const STEP := 1.0 / 60.0

var _holder: WeaponHolder
var _user: CharacterBody3D
var _eye: Node3D
var _directions: Array[Vector3] = []


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_directions.clear()
	var root := auto_free(Node3D.new()) as Node3D
	add_child(root)
	_user = Characters.character(root, "Shooter", Vector3(340, 0, 0), [])
	_eye = Node3D.new()
	_eye.name = "Eye"
	_eye.position.y = 1.6
	_user.add_child(_eye)
	_holder = WeaponHolder.new()
	# A cone of 0, no bloom and no sway: every shot's centre is the eye's -Z, so pellet angles are the
	# pellet cone alone.
	var still := AimConfig.new()
	still.base_min_deg = 0.0
	still.sway_deg = 0.0
	still.shot_bloom_deg = 0.0
	_holder.aim_config = still
	_holder.rng_seed = 5
	_holder.weapons = [SHOTGUN, SNIPER] as Array[WeaponData]
	_eye.add_child(_holder)
	_holder.setup(_user, _eye)
	StimulusSystem.stimulus_processed.connect(_on_processed)
	await _physics(1)


func after_test() -> void:
	StimulusSystem.stimulus_processed.disconnect(_on_processed)
	StimulusSystem.clear()


func test_rifle_spread_mult_narrows_the_pellet_cone_of_any_holder() -> void:
	_holder.equip(0)
	var untrained := await _widest_pellet_deg()
	_modify(&"rifle_spread_mult", 0.4)
	var master := await _widest_pellet_deg()

	# Untrained: 8 pellets spread over the 2.5 degree cone; x0.4: all inside 1.0 degree.
	assert_float(untrained).is_between(1.2, 2.5 + 0.01)
	assert_float(master).is_less_equal(1.0 + 0.01)


func test_a_class_modifier_leaves_other_classes_alone() -> void:
	_holder.equip(0)
	_modify(&"pistol_spread_mult", 0.1)
	_modify(&"sniper_spread_mult", 0.1)

	assert_float(await _widest_pellet_deg()).is_greater(1.2)


func test_sniper_sway_mult_steadies_any_holder_and_stacks_with_injuries() -> void:
	_holder.equip(1)
	for tick in 20:
		_holder.physics_step(STEP, AimModel.Stance.STILL)
	var base := _holder.aim.sway(1.0)
	assert_float(_holder.sway().length()).is_greater(0.01)
	assert_vector(_holder.sway()).is_equal_approx(base, Vector2.ONE * 0.0001)

	_modify(&"sniper_sway_mult", 0.25)
	# An injured arm doubles the sway (BodyParts writes `aim_sway_mult` the same way).
	Attributes.of(_user).attribute_set.set_base(&"aim_sway_mult", 1.0)
	_modify(&"aim_sway_mult", 2.0)
	_holder.physics_step(STEP, AimModel.Stance.STILL)

	assert_vector(_holder.sway()).is_equal_approx(_holder.aim.sway(0.5), Vector2.ONE * 0.0001)


# Fires one shotgun shot and returns the widest pellet's angle (degrees) off the eye's -Z.
func _widest_pellet_deg() -> float:
	_directions.clear()
	_holder.state().cooldown = 0.0
	_holder.state().magazine = SHOTGUN.magazine_size
	assert_int(_holder.trigger()).is_equal(WeaponState.Result.FIRED)
	await _physics(2)
	assert_int(_directions.size()).is_equal(SHOTGUN.pellets)
	var widest := 0.0
	for direction in _directions:
		widest = maxf(widest, AimModel.angle_off(_eye.global_transform.basis, direction))
	return widest


func _modify(attribute: StringName, magnitude: float) -> void:
	var modifier := Modifier.create(attribute, Modifier.Op.MULTIPLY, magnitude, &"test")
	Attributes.of(_user).attribute_set.add_modifier(modifier)


func _on_processed(stimulus: Stimulus, _paths: Array[PackedVector3Array]) -> void:
	if stimulus.type == &"damage.ballistic":
		_directions.append(stimulus.direction)


func _physics(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
