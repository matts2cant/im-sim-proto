extends GdUnitTestSuite
## Integration (ADR 0131): a minimal character (walker, eye, WeaponHolder, Thrower, Skills) fires a
## THROWN weapon (the test grenade): with a surface within 1.2 m of the eye it sticks there, further
## it is thrown (fuse lit); a character in front blocks sticking; a thrown one bounces off a
## character; the Demolition tier sets the throw distance (12 / 14 / 16 / 18 m, measured where it
## first lands on flat ground).

const Wait := preload("res://tests/helpers/wait.gd")
const Grenades := preload("res://tests/items/grenades/grenade_helpers.gd")
const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const ORIGIN := Vector3(700, 0, 0)
## Height of the test grenade's centre (a 0.08 m box) when it first touches the floor, with margin.
const LANDED_Y: float = 0.1

var _root: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new()) as Node3D
	add_child(_root)
	Grenades.box(_root, ORIGIN + Vector3(0, -0.5, -20), Vector3(80, 1, 80))


func after_test() -> void:
	StimulusSystem.clear()


func test_sticks_on_a_wall_within_reach() -> void:
	var user := Grenades.thrower(_root, ORIGIN)
	# Wall face 1.0 m ahead of the eye (gap, eye to surface).
	Grenades.box(_root, ORIGIN + Vector3(0, 1.5, -1.2), Vector3(4, 3, 0.4))
	await Wait.frames(get_tree(), 3)

	assert_int(Grenades.holder_of(user).trigger()).is_equal(WeaponState.Result.FIRED)

	var grenade := _spawned()
	var sticky := Sticky.of(grenade)
	assert_bool(sticky.is_stuck).is_true()
	assert_bool(grenade.freeze).is_true()
	assert_bool(Fuse.of(grenade).is_lit).is_false()
	# On the wall's face, its centre the surface offset out, at eye height.
	assert_vector(grenade.global_position).is_equal_approx(
		ORIGIN + Vector3(0, Grenades.EYE_HEIGHT, -1.0 + sticky.surface_offset), Vector3.ONE * 0.01
	)
	assert_vector(grenade.global_basis.y).is_equal_approx(Vector3.BACK, Vector3.ONE * 0.01)
	await Wait.frames(get_tree(), 10)
	assert_vector(grenade.global_position).is_equal_approx(
		ORIGIN + Vector3(0, Grenades.EYE_HEIGHT, -1.0 + sticky.surface_offset), Vector3.ONE * 0.01
	)


func test_throws_when_the_surface_is_beyond_reach() -> void:
	var user := Grenades.thrower(_root, ORIGIN)
	# Wall face 1.6 m ahead of the eye.
	Grenades.box(_root, ORIGIN + Vector3(0, 1.5, -1.8), Vector3(4, 3, 0.4))
	await Wait.frames(get_tree(), 3)

	Grenades.holder_of(user).trigger()

	var grenade := _spawned()
	assert_bool(Sticky.of(grenade).is_stuck).is_false()
	assert_bool(Fuse.of(grenade).is_lit).is_true()
	assert_float(grenade.linear_velocity.length()).is_greater(5.0)
	var thrown := EventLog.find(&"weapon.thrown")
	assert_str(str(thrown[0].data["outcome"])).is_equal("thrown")


func test_a_character_in_front_blocks_sticking() -> void:
	var user := Grenades.thrower(_root, ORIGIN)
	# A character 0.8 m ahead (centre to eye axis), a wall face 1.1 m ahead behind it.
	Characters.character(_root, "Blocker", ORIGIN + Vector3(0, 0, -0.8), [])
	Grenades.box(_root, ORIGIN + Vector3(0, 1.5, -1.3), Vector3(4, 3, 0.4))
	await Wait.frames(get_tree(), 3)

	Grenades.holder_of(user).trigger()

	assert_bool(Sticky.of(_spawned()).is_stuck).is_false()
	assert_str(str(EventLog.find(&"weapon.thrown")[0].data["outcome"])).is_equal("thrown")


func test_a_thrown_grenade_bounces_off_a_character() -> void:
	# Looking 15 degrees down: the arc meets the character's chest 3 m ahead.
	var user := Grenades.thrower(_root, ORIGIN, 0.0, deg_to_rad(-15.0))
	Characters.character(_root, "Target", ORIGIN + Vector3(0, 0, -3.0), [])
	await Wait.frames(get_tree(), 3)

	Grenades.holder_of(user).trigger()
	var grenade := _spawned()
	await Grenades.seconds(get_tree(), 0.8)

	# Never past the character's far side.
	assert_float(grenade.global_position.z).is_greater(ORIGIN.z - 3.0)


func test_throw_distance_per_demolition_tier() -> void:
	var expected: Array[float] = [12.0, 14.0, 16.0, 18.0]
	var grenades: Array[RigidBody3D] = []
	var users: Array[CharacterBody3D] = []
	for tier in 4:
		var user := Grenades.thrower(_root, ORIGIN + Vector3(-12 + tier * 8, 0, 0))
		Skills.of(user).set_tier(&"demolition", tier)
		users.append(user)
	await Wait.frames(get_tree(), 3)
	for user in users:
		Grenades.holder_of(user).trigger()
		grenades.append(Thrower.of(user).last_fuse.entity as RigidBody3D)
	var landed: Array[float] = [-1.0, -1.0, -1.0, -1.0]
	for frame in 150:
		await get_tree().physics_frame
		for i in 4:
			if landed[i] < 0.0 and grenades[i].global_position.y < LANDED_Y:
				landed[i] = users[i].global_position.z - grenades[i].global_position.z

	# Measured 11.8 / 13.8 / 15.7 / 17.7 m: the box touches down a little before its centre would.
	for i in 4:
		assert_float(landed[i]).override_failure_message("tier %d landed at %.2f m" % [i, landed[i]]).is_equal_approx(
			expected[i], 0.5
		)


func _spawned() -> RigidBody3D:
	for child in _root.get_children():
		if child is RigidBody3D and Sticky.of(child) != null:
			return child as RigidBody3D
	return null
