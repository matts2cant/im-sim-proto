extends GdUnitTestSuite
## Integration: RAY collision masks and exclusions, and the `collider` the receivers' effects get
## for RAY and CONTACT (ADR 0047: hitboxes on layer 5 and part-aware delivery).

const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")


class CaptureEffect:
	extends Effect
	var contexts: Array[EffectContext] = []

	func apply(ctx: EffectContext) -> void:
		contexts.append(ctx)


var _world: Node3D
var _capture: CaptureEffect


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_world = auto_free(Node3D.new())
	add_child(_world)
	_capture = CaptureEffect.new()


func test_ray_gives_the_hitbox_collider_and_hit_point() -> void:
	var guard := _guard(Vector3(0, 0, -4))
	await Fixtures.frames(get_tree(), 2)

	StimulusSystem.emit(_ray(PhysicsLayers.WEAPON_MASK))
	await Fixtures.frames(get_tree(), 2)

	assert_array(_capture.contexts).has_size(1)
	var ctx := _capture.contexts[0]
	assert_object(ctx.entity).is_same(guard)
	assert_object(ctx.collider()).is_same(guard.get_node("Hitbox"))
	assert_str(Hitboxes.part_of(ctx.collider())).is_equal("head")
	var point: Vector3 = ctx.data["position"]
	assert_float(point.z).is_equal_approx(-3.75, 0.01)
	# The log names the collider instead of holding the node.
	assert_str(EventLog.find(&"stimulus.received")[0].data["collider"]).is_equal("Hitbox")


func test_weapon_mask_skips_the_actor_body() -> void:
	var guard := _guard(Vector3(0, 0, -4))
	# The actor body stands in front of the hitbox.
	(guard.get_node("Body") as Node3D).position = Vector3(0, 0, 1)
	await Fixtures.frames(get_tree(), 2)

	StimulusSystem.emit(_ray(PhysicsLayers.WEAPON_MASK))
	await Fixtures.frames(get_tree(), 2)
	assert_object(_capture.contexts[0].collider()).is_same(guard.get_node("Hitbox"))

	StimulusSystem.emit(_ray(0xFFFFFFFF))
	await Fixtures.frames(get_tree(), 2)
	assert_object(_capture.contexts[1].collider()).is_same(guard)


func test_ray_exclude_list_is_ignored() -> void:
	var guard := _guard(Vector3(0, 0, -4))
	await Fixtures.frames(get_tree(), 2)
	var ray := _ray(PhysicsLayers.WEAPON_MASK)
	ray.exclude = [(guard.get_node("Hitbox") as CollisionObject3D).get_rid()]

	StimulusSystem.emit(ray)
	await Fixtures.frames(get_tree(), 2)

	assert_array(_capture.contexts).is_empty()


func test_contact_gives_the_touched_node() -> void:
	var guard := _guard(Vector3(0, 0, -4))
	await Fixtures.frames(get_tree(), 2)

	StimulusSystem.emit(Stimulus.make_contact(&"damage.stun", 20.0, guard.get_node("Hitbox")))
	StimulusSystem.emit(Stimulus.make_contact(&"damage.blunt", 5.0, guard))
	await Fixtures.frames(get_tree(), 2)

	assert_array(_capture.contexts).has_size(2)
	assert_str(Hitboxes.part_of(_capture.contexts[0].collider())).is_equal("head")
	assert_str(Hitboxes.part_of(_capture.contexts[1].collider())).is_equal("")


func _ray(mask: int) -> Stimulus:
	return Stimulus.make_ray(&"damage.ballistic", 25.0, Vector3.ZERO, Vector3.FORWARD, 10.0, null, mask)


## An actor: StaticBody3D on layer 3 with a 1 m box, a 0.5 m head hitbox on layer 5 and a receiver.
func _guard(position: Vector3) -> StaticBody3D:
	var guard := StaticBody3D.new()
	guard.name = "Guard"
	guard.collision_layer = PhysicsLayers.ACTORS
	guard.position = position
	var body := CollisionShape3D.new()
	body.name = "Body"
	body.shape = BoxShape3D.new()
	guard.add_child(body)
	var hitbox := AnimatableBody3D.new()
	hitbox.name = "Hitbox"
	hitbox.sync_to_physics = false
	hitbox.collision_layer = PhysicsLayers.HITBOXES
	hitbox.collision_mask = 0
	hitbox.set_meta(Hitboxes.META, &"head")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * 0.5
	shape.shape = box
	hitbox.add_child(shape)
	guard.add_child(hitbox)
	var receiver := StimulusReceiver.new()
	receiver.receptrons = [Fixtures.receptron(&"damage", [_capture] as Array[Effect])] as Array[Receptron]
	guard.add_child(receiver)
	_world.add_child(guard)
	return guard
