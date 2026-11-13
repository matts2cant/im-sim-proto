extends GdUnitTestSuite
## Unit (audit Q10): OwnBody.rids() is what a caster's rays leave out: its body and every hitbox
## under it, on any entity (a character with hitboxes, a static body without), nothing for a freed
## entity; a ray cast from inside a character's own hitboxes meets what is beyond them.

const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const HITBOXES := preload("res://actors/common/body/hitboxes.tscn")

var _root: Node3D


func before_test() -> void:
	_root = auto_free(Node3D.new()) as Node3D
	add_child(_root)


func test_a_character_leaves_out_its_body_and_its_hitboxes() -> void:
	var body := Characters.character(_root, "Caster", Vector3(640, 0, 0), [] as Array[StringName])
	var boxes := HITBOXES.instantiate() as Hitboxes
	body.add_child(boxes)
	var rids := OwnBody.rids(body)
	assert_int(rids.size()).is_equal(1 + boxes.boxes().size())
	assert_bool(rids.has(body.get_rid())).is_true()
	for box in boxes.boxes():
		assert_bool(rids.has(box.get_rid())).is_true()


func test_a_body_without_hitboxes_leaves_out_itself() -> void:
	var body := StaticBody3D.new()
	_root.add_child(body)
	var rids := OwnBody.rids(body)
	assert_int(rids.size()).is_equal(1)
	assert_bool(rids[0] == body.get_rid()).is_true()


func test_nothing_for_a_freed_or_missing_entity() -> void:
	var body := StaticBody3D.new()
	body.free()
	assert_array(OwnBody.rids(body)).is_empty()
	assert_array(OwnBody.rids(null)).is_empty()


func test_a_ray_through_its_own_hitboxes_meets_what_is_beyond() -> void:
	var body := Characters.character(_root, "Caster", Vector3(640, 0, 0), [] as Array[StringName])
	body.add_child(HITBOXES.instantiate())
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.2)
	shape.shape = box
	wall.add_child(shape)
	_root.add_child(wall)
	wall.global_position = Vector3(640, 1.5, -4)
	for i in 2:
		await get_tree().physics_frame
	# From 2 m behind, through the head hitbox, on the weapon layers: the head without the exclusion.
	var from := Vector3(640, 1.64, 2)
	var space := _root.get_world_3d().direct_space_state
	var plain := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, 0, -10), PhysicsLayers.WEAPON_MASK)
	var first := space.intersect_ray(plain).get("collider") as Node
	assert_bool(Hitboxes.part_of(first) == BodyDamageModel.HEAD).is_true()
	var query := PhysicsRayQueryParameters3D.create(
		from, from + Vector3(0, 0, -10), PhysicsLayers.WEAPON_MASK, OwnBody.rids(body)
	)
	assert_object(space.intersect_ray(query).get("collider")).is_same(wall)
