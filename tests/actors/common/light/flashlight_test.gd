extends GdUnitTestSuite
## Integration: the Flashlight component (ADR 0095) on minimal entities built in code (a Node3D
## with Tags, no awareness; a StaticBody3D target with a LightExposure), far from the origin and
## without any other light: when it is lit (tags, on_while_patrolling, awareness states), that
## LightExposure sees its beam (cone, range, walls) like any lamp, and it saves.

const ORIGIN := Vector3(300, 0, -300)
const FLASHLIGHT: PackedScene = preload("res://actors/common/light/flashlight.tscn")
const GUARD: PackedScene = preload("res://actors/guard/guard.tscn")
const CHARACTERS := preload("res://tests/actors/common/character_fixtures.gd")

var _root: Node3D


func before_test() -> void:
	EventLog.clear()
	_root = auto_free(Node3D.new())
	add_child(_root)
	_root.global_position = ORIGIN
	CHARACTERS.floor_box(_root)


# A carrier (Node3D + Tags) at the origin with a flashlight 1.5 m up, pointing along -Z.
func _carrier(patrolling: bool) -> Flashlight:
	var carrier := Node3D.new()
	carrier.name = "Carrier"
	var tags := Tags.new()
	tags.name = "Tags"
	carrier.add_child(tags)
	var light := FLASHLIGHT.instantiate() as Flashlight
	light.on_while_patrolling = patrolling
	light.position = Vector3(0, 1.5, 0)
	carrier.add_child(light)
	_root.add_child(carrier)
	return light


func test_on_while_patrolling_is_lit_until_the_carrier_is_downed() -> void:
	var light := _carrier(true)
	await _frames(2)
	assert_bool(light.lit).is_true()
	assert_bool(light.beam.is_visible_in_tree()).is_true()
	assert_float(light.beam.spot_range).is_equal(12.0)
	assert_float(light.beam.spot_angle).is_equal(20.0)

	ActorState.set_tag(light.carrier, ActorState.UNCONSCIOUS, true)
	await _frames(2)
	assert_bool(light.lit).is_false()
	assert_bool(light.beam.is_visible_in_tree()).is_false()
	assert_bool(light.halo.is_visible_in_tree()).is_false()

	ActorState.set_tag(light.carrier, ActorState.UNCONSCIOUS, false)
	ActorState.set_tag(light.carrier, ActorState.DEAD, true)
	await _frames(2)
	assert_bool(light.lit).is_false()
	var switches := EventLog.find(&"light.flashlight").map(func(e: EventLogEntry) -> bool: return e.data["lit"])
	assert_array(switches).is_equal([true, false])


func test_without_awareness_or_the_flag_it_stays_off() -> void:
	var light := _carrier(false)
	await _frames(2)
	assert_bool(light.lit).is_false()


func test_a_guard_lights_it_when_searching_or_alerted() -> void:
	var guard := GUARD.instantiate() as NavWalker
	_root.add_child(guard)
	(guard.get_node("Behaviour") as AwarenessBehaviour).route = null
	var light := Flashlight.of(guard)
	var awareness := GradedAwareness.of_node(guard)
	await _frames(2)
	assert_object(light).is_not_null()
	assert_object(light.carrier).is_same(guard)
	assert_bool(light.lit).is_false()

	awareness.search_at(guard.global_position + Vector3(0, 0, -3), "test")
	await _frames(2)
	assert_str(awareness.state_name()).is_equal("searching")
	assert_bool(light.lit).is_true()

	awareness.alert_at(guard.global_position + Vector3(0, 0, -3))
	await _frames(2)
	assert_str(awareness.state_name()).is_equal("alerted")
	assert_bool(light.lit).is_true()

	ActorState.set_tag(guard, ActorState.UNCONSCIOUS, true)
	await _frames(2)
	assert_bool(light.lit).is_false()


func test_light_exposure_sees_the_beam_in_its_cone_and_range_only() -> void:
	var light := _carrier(true)
	var ahead := _target(Vector3(0, 0, -6))
	var aside := _target(Vector3(6, 0, -6))
	var far := _target(Vector3(0, 0, -13.5))
	await _frames(12)
	# 6 m ahead on the axis: well lit; 45 degrees off the axis or past the 12 m range: dark.
	assert_float(LightExposure.of(ahead).level).is_greater(0.3)
	assert_float(LightExposure.of(aside).level).is_less(0.05)
	assert_float(LightExposure.of(far).level).is_less(0.05)

	light.on_while_patrolling = false
	await _frames(12)
	assert_float(LightExposure.of(ahead).level).is_less(0.05)


func test_a_wall_shadows_the_beam() -> void:
	_carrier(true)
	var behind := _target(Vector3(0, 0, -6))
	var wall := StaticBody3D.new()
	wall.collision_layer = PhysicsLayers.WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 3, 0.3)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(0, 1.5, -3)
	_root.add_child(wall)
	await _frames(12)
	assert_float(LightExposure.of(behind).level).is_less(0.05)


func test_save_and_load() -> void:
	var light := _carrier(true)
	await _frames(2)
	var data := light.save_state()
	assert_dict(data).is_equal({"on_while_patrolling": true, "lit": true})

	var other := _carrier(false)
	await _frames(2)
	other.load_state(data)
	assert_bool(other.on_while_patrolling).is_true()
	assert_bool(other.beam.visible).is_true()
	await _frames(2)
	assert_bool(other.lit).is_true()


# A static 1.8 m capsule with a LightExposure, feet at `feet` (fixture space).
func _target(feet: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = PhysicsLayers.ACTORS
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	body.add_child(shape)
	var exposure := LightExposure.new()
	exposure.name = "LightExposure"
	body.add_child(exposure)
	body.position = feet
	_root.add_child(body)
	return body


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
