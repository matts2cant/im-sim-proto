extends GdUnitTestSuite
## Scenario: forces are stimuli (ADR 0057). A barrel's blast pushes the props around it through
## their `pushed_by_force` receptron (PhysicsObject adds it, item pickups included); a bullet's
## `force.impact` ray pushes a crate at the point hit.

const Objects := preload("res://tests/objects/object_test_helpers.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const FLOOR := "res://tests/objects/fixtures/object_floor.tscn"
const MEDKIT := "res://items/medkit/medkit.tscn"
const BARREL_CENTRE := Vector3(0, 0.45, 0)

var _floor: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_floor = auto_free(load(FLOOR).instantiate())
	add_child(_floor)
	await Objects.frames(get_tree(), 5)


func test_barrel_blast_pushes_a_crate_and_an_item_away() -> void:
	Objects.spawn(_floor, Objects.EXPLOSIVE_BARREL, BARREL_CENTRE)
	# Metal crate (25 kg, survives the blast) 2.5 m east, a medkit 3.5 m west.
	var crate := Objects.spawn(_floor, Objects.METAL_CRATE, Vector3(2.5, 0.4, 0)) as RigidBody3D
	var medkit := Objects.spawn(_floor, MEDKIT, Vector3(-3.5, 0.05, 0)) as RigidBody3D
	await Objects.frames(get_tree(), 20)
	var crate_start := crate.global_position
	EventLog.clear()

	StimulusSystem.emit(Stimulus.make_contact(&"fire", 100.0, _floor.get_node("ExplosiveBarrel")))
	await Objects.frames(get_tree(), 4)

	var blast := EventLog.find(&"stimulus.emitted").filter(
		func(entry: EventLogEntry) -> bool: return entry.data["type"] == &"force.blast"
	)
	assert_array(blast).has_size(1)
	assert_str(blast[0].source).is_equal("ExplosiveBarrel")
	assert_float(blast[0].data["intensity"]).is_equal(120.0)
	for target: String in ["MetalCrate", "Medkit"]:
		var fired := Fixtures.entries(&"receptron.fired").filter(
			func(entry: EventLogEntry) -> bool: return entry.target == target
		)
		assert_array(fired).override_failure_message(target).is_not_empty()
		assert_str(fired[0].data["receptron"]).is_equal("pushed_by_force")
	# 120 x (1 - 2.5 / 4) = 45 N s on 25 kg: about 1.8 m/s away from the barrel, tilted up.
	assert_float(crate.linear_velocity.x).is_greater(0.5)
	assert_float(medkit.linear_velocity.x).is_less(-1.0)
	await Objects.frames(get_tree(), 30)
	assert_float(crate.global_position.x - crate_start.x).is_greater(0.1)


func test_bullet_pushes_a_crate_at_the_hit_point() -> void:
	# Small crate (0.6 m, 10 kg) at z = -2; the ray hits its +z face 0.2 m above the centre.
	var crate := Objects.spawn(_floor, Objects.SMALL_CRATE, Vector3(0, 0.3, -2)) as RigidBody3D
	await Objects.frames(get_tree(), 20)
	EventLog.clear()

	var bullet := Stimulus.make_ray(
		&"force.impact", 20.0, Vector3(0, 0.5, 0), Vector3.FORWARD, 10.0, null, PhysicsLayers.WEAPON_MASK
	)
	StimulusSystem.emit(bullet)
	await Objects.frames(get_tree(), 3)

	var received := Fixtures.entries(&"stimulus.received", bullet.id)
	assert_array(received).has_size(1)
	assert_str(received[0].target).is_equal("SmallCrate")
	assert_vector(received[0].data["position"] as Vector3).is_equal_approx(Vector3(0, 0.5, -1.7), Vector3.ONE * 0.01)
	# 20 N s on 10 kg along -z, above the centre: it slides away and tips back.
	assert_float(crate.linear_velocity.z).is_less(-1.0)
	assert_float(crate.angular_velocity.x).is_less(-0.5)
