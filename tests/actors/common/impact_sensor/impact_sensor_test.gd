extends GdUnitTestSuite
## Integration: ImpactSensor turns props flying into a body they pass through (not in the props'
## mask) into `damage.blunt` with ImpactNoise's numbers, and stays off on bodies props collide with
## (no double count): a minimal walker on each layer, the player and the training dummy.

const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const SETTINGS: ImpactSettings = preload("res://objects/components/impact_settings.tres")
const DUMMY := "res://actors/dummy/training_dummy.tscn"
const ROOM := "res://tests/objects/fixtures/carry_room.tscn"
const THROW_SPEED: float = 10.0
## Small crate (10 kg) at 10 m/s: 0.5 x 10 x 100 / 40 = 12.5; linear damping slows it to about
## 9.8 m/s by the hit (12.0).
const EXPECTED_DAMAGE: float = 12.0
const DAMAGE_TOLERANCE: float = 0.5

var _root: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	add_child(_root)


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_layer_rule_decides_whether_the_sensor_runs() -> void:
	assert_bool(ImpactSensor.props_pass_through(PhysicsLayers.PLAYER)).is_true()
	assert_bool(ImpactSensor.props_pass_through(PhysicsLayers.TRIGGERS)).is_true()
	assert_bool(ImpactSensor.props_pass_through(PhysicsLayers.ACTORS)).is_false()
	assert_bool(ImpactSensor.props_pass_through(PhysicsLayers.WORLD)).is_false()


func test_approach_speed_is_towards_the_capsule_axis() -> void:
	Characters.floor_box(_root)
	var walker := Characters.character(_root, "Walker", Vector3.ZERO, [Characters.IMPACT_SENSOR])
	await Fixtures.frames(get_tree(), 1)
	var capsule := walker.get_node("Collision") as CollisionShape3D

	var side := ImpactSensor.approach_speed(Vector3(-1, 1.0, 0), Vector3(10, -2, 0), capsule)
	var above := ImpactSensor.approach_speed(Vector3(0, 3, 0), Vector3(0, -6, 0), capsule)
	var away := ImpactSensor.approach_speed(Vector3(-1, 1.0, 0), Vector3(-5, 0, 0), capsule)

	assert_float(side).is_equal_approx(10.0, 0.0001)
	assert_float(above).is_equal_approx(6.0, 0.0001)
	assert_float(away).is_equal_approx(-5.0, 0.0001)


func test_crate_thrown_through_a_pass_through_body_damages_it() -> void:
	Characters.floor_box(_root)
	var walker := Characters.character(_root, "Walker", Vector3.ZERO, [Characters.IMPACT_SENSOR], PhysicsLayers.PLAYER)
	await Fixtures.frames(get_tree(), 5)
	assert_bool((walker.get_node("ImpactSensor") as ImpactSensor).active).is_true()

	_throw_crate(_root, Vector3(-2.5, 1.2, 0), Vector3(THROW_SPEED, 0, 0))
	await Fixtures.frames(get_tree(), 40)

	var hits := _blunt_to("Walker")
	assert_array(hits).has_size(1)
	assert_float(hits[0].data["intensity"]).is_equal_approx(EXPECTED_DAMAGE, DAMAGE_TOLERANCE)
	var struck := EventLog.find(&"actor.struck")
	assert_array(struck).has_size(1)
	var speed: float = struck[0].data["speed"]
	assert_float(hits[0].data["intensity"]).is_equal_approx(ImpactRules.damage(speed, 10.0, SETTINGS), 0.0001)
	var torso := Characters.body_parts(walker).health(&"torso")
	assert_float(torso).is_equal_approx(Characters.BODY_PROFILE.torso_health - hits[0].data["intensity"], 0.001)


func test_props_that_collide_are_left_to_impact_noise() -> void:
	Characters.floor_box(_root)
	var walker := Characters.character(_root, "Walker", Vector3.ZERO, [Characters.IMPACT_SENSOR], PhysicsLayers.ACTORS)
	await Fixtures.frames(get_tree(), 5)
	assert_bool((walker.get_node("ImpactSensor") as ImpactSensor).active).is_false()

	_throw_crate(_root, Vector3(-2.5, 1.2, 0), Vector3(THROW_SPEED, 0, 0))
	await Fixtures.frames(get_tree(), 40)

	# One hit, from the crate's ImpactNoise contact; the sensor adds none. (Its amount is not checked:
	# a kinematic body that scans props recovers out of the crate in move_and_slide, and ImpactNoise
	# reads that as the body moving away, about 1.2 instead of 12; see ADR 0056.)
	var hits := _blunt_to("Walker")
	assert_array(hits).has_size(1)
	assert_str(hits[0].source).is_equal("SmallCrate")
	assert_array(EventLog.find(&"actor.struck")).is_empty()


func test_slow_prop_does_no_damage() -> void:
	Characters.floor_box(_root)
	Characters.character(_root, "Walker", Vector3.ZERO, [Characters.IMPACT_SENSOR], PhysicsLayers.PLAYER)
	await Fixtures.frames(get_tree(), 5)

	_throw_crate(_root, Vector3(-1.2, 1.2, 0), Vector3(SETTINGS.min_speed * 0.6, 0, 0))
	await Fixtures.frames(get_tree(), 40)

	assert_array(_blunt_to("Walker")).is_empty()


func test_crate_thrown_at_the_player_damages_the_player() -> void:
	var driver := PlayerDriver.new(scene_runner(ROOM))
	await driver.settle()
	await driver.place(Vector3(-4, 0, 2))
	StimulusSystem.clear()

	_throw_crate(driver.runner.scene(), Vector3(-4, 1.2, -0.5), Vector3(0, 0, THROW_SPEED))
	await driver.frames(40)

	var hits := _blunt_to("Player")
	assert_array(hits).has_size(1)
	assert_float(hits[0].data["intensity"]).is_equal_approx(EXPECTED_DAMAGE, DAMAGE_TOLERANCE)
	var torso := driver.player.body.health(&"torso")
	assert_float(torso).is_equal_approx(100.0 - hits[0].data["intensity"], 0.001)


func test_crate_thrown_at_the_dummy_hits_once() -> void:
	var driver := PlayerDriver.new(scene_runner(ROOM))
	await driver.settle()
	var dummy := Objects.spawn(driver.runner.scene(), DUMMY, Vector3(4, 0, 2)) as TrainingDummy
	await driver.frames(3)
	assert_bool((dummy.get_node("ImpactSensor") as ImpactSensor).active).is_false()
	EventLog.clear()

	_throw_crate(driver.runner.scene(), Vector3(4, 1.2, -0.5), Vector3(0, 0, THROW_SPEED))
	await driver.frames(40)

	var hits := _blunt_to("TrainingDummy")
	assert_array(hits).has_size(1)
	assert_float(hits[0].data["intensity"]).is_equal_approx(EXPECTED_DAMAGE, DAMAGE_TOLERANCE)
	assert_float(dummy.body.health(&"torso")).is_equal_approx(80.0 - hits[0].data["intensity"], 0.001)


# Placed before it enters the tree: added at the origin and moved, it would overlap a body at the
# origin in the physics queries of its first tick.
func _throw_crate(parent: Node, at: Vector3, velocity: Vector3) -> RigidBody3D:
	var crate := (load(Objects.SMALL_CRATE) as PackedScene).instantiate() as RigidBody3D
	crate.position = at
	crate.linear_velocity = velocity
	parent.add_child(crate)
	return crate


# `damage.blunt` stimuli emitted at `target_name` (CONTACT target).
func _blunt_to(target_name: String) -> Array[EventLogEntry]:
	return EventLog.find(&"stimulus.emitted").filter(
		func(entry: EventLogEntry) -> bool: return entry.data["type"] == &"damage.blunt" and entry.target == target_name
	)
