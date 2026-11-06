extends GdUnitTestSuite
## The perception lab's guard in the hub (player removed): it holds the GuardPost (no route), on
## the navmesh, facing the lanes (+Z). With the lab's real lamps and breaker, a stand-in target
## (a static capsule tagged `actor.player` with a real LightExposure) in the lit lane 9.2 m away and
## 22 degrees off its facing (focus cone 30 degrees / 20 m) is seen with the lights on and not seen
## once the breaker cuts them; 1.2 m in front of the guard (inside the 2 m close override) it is
## seen in the dark. Room-local coordinates: origin on the hub wall's outer face, -Z into the lab.

const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const HUB_SCENE: PackedScene = preload("res://levels/hub/hub.tscn")
const POST := Vector3(2.5, 0, -16)
## In the lit lane (x 5.1 .. 9.9, z -4 .. -12) between the two lit lamps' footprints.
const LIT_SPOT := Vector3(6, 0, -7.5)
## Distance from the guard's post at which the close spot sits, towards LIT_SPOT.
const CLOSE_DISTANCE := 1.2

var _hub: Node3D
var _room: Node3D
var _guard: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_hub = auto_free(HUB_SCENE.instantiate())
	_hub.get_node("Player").free()
	add_child(_hub)
	_room = _hub.get_node("PerceptionLab") as Node3D
	_guard = _room.get_node("Guard") as Node3D


func after_test() -> void:
	StimulusSystem.clear()


func test_guard_holds_the_post_on_the_navmesh_facing_the_lanes() -> void:
	await KitGeometry.settle(get_tree(), 5)
	var map := (_hub.get_node("Navigation") as LevelNavigation).get_navigation_map()
	assert_bool(await KitGeometry.wait_for_navigation(get_tree(), map, _guard.global_position)).is_true()

	var feet := _room.to_local(_guard.global_position)
	assert_float(Vector2(feet.x, feet.z).distance_to(Vector2(POST.x, POST.z))).is_less(0.1)
	assert_vector(PerceptionSensor.of(_guard).facing()).is_equal_approx(Vector3.BACK, Vector3.ONE * 0.01)
	assert_object((_guard.get_node("Behaviour") as AwarenessBehaviour).route).is_null()
	assert_bool(ActorState.has(_guard, &"actor.guard")).is_true()
	assert_bool(ActorState.can_act(_guard)).is_true()


func test_sees_the_lit_lane_until_the_breaker_cuts_the_lights_but_not_up_close() -> void:
	var sensor := PerceptionSensor.of(_guard)
	var target := _target(_room.to_global(LIT_SPOT))
	# Hidden (Cloak's tag) until its light level has settled, so the guard does not react yet.
	ActorState.set_tag(target, ActorState.CLOAKED, true)
	await KitGeometry.settle(get_tree(), 12)
	var distance := VisionRules.flat_distance(sensor.eye_position(), target.global_position)
	var angle := VisionRules.angle_off(sensor.facing(), sensor.eye_position(), target.global_position)
	assert_float(distance).is_between(8.0, 10.0)
	assert_float(angle).is_less(25.0)
	assert_float(LightExposure.of(target).update_now()).is_greater(0.6)
	ActorState.set_tag(target, ActorState.CLOAKED, false)

	var lit := sensor.look()
	assert_object(lit).is_not_null()
	assert_object(lit.target).is_same(target)
	assert_float(lit.gain).is_greater(0.0)

	(Usable.of(_room.get_node("Breaker")) as CircuitBreaker).set_closed(false)
	assert_float(LightExposure.of(target).update_now()).is_less(0.1)
	assert_object(sensor.look()).is_null()

	var towards := (target.global_position - _guard.global_position).normalized()
	target.global_position = _guard.global_position + towards * CLOSE_DISTANCE
	assert_float(LightExposure.of(target).update_now()).is_less(0.1)
	var close := sensor.look()
	assert_object(close).is_not_null()
	assert_object(close.target).is_same(target)
	assert_float(close.gain).is_greater(0.0)


# A static 1.8 m capsule tagged `actor.player` with a real LightExposure.
func _target(feet: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Target"
	body.collision_layer = PhysicsLayers.ACTORS
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	body.add_child(shape)
	var tags := Tags.new()
	tags.name = "Tags"
	tags.initial_tags = [&"actor.player"]
	body.add_child(tags)
	var light := LightExposure.new()
	light.name = "LightExposure"
	body.add_child(light)
	_hub.add_child(body)
	body.global_position = feet
	return body
