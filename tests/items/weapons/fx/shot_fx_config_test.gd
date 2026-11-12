extends GdUnitTestSuite
## ShotFxConfig (ADR 0126): the material group of what a bullet hit comes from data on the surface,
## never its name: a body (hitbox or BodyParts), the collider's `wall_surface` / `surface` metadata
## (kit parts), the `material.*` tags of the entity above it (props), else concrete; and each group
## has its own look (`shot_fx.tres`). Built on bare nodes in code, plus a kit Room and two shipped
## props for the data they carry.

const CONFIG: ShotFxConfig = preload("res://items/weapons/fx/shot_fx.tres")
const METAL_CRATE: PackedScene = preload("res://objects/metal_crate/metal_crate.tscn")
const SMALL_CRATE: PackedScene = preload("res://objects/small_crate/small_crate.tscn")
const ORIGIN := Vector3(-260, 0, 340)


func test_surface_metadata_picks_the_group() -> void:
	var expected := {&"metal": &"metal", &"wood": &"wood", &"concrete": &"concrete", &"carpet": &"concrete"}
	for surface: StringName in expected:
		var body := _static_body()
		body.set_meta(&"surface", surface)
		assert_str(String(CONFIG.group_for(body, Vector3.BACK))).is_equal(String(expected[surface]))


func test_wall_surface_metadata_is_read_on_walls_not_floors() -> void:
	var body := _static_body()
	body.set_meta(&"surface", &"wood")
	body.set_meta(&"wall_surface", &"concrete")

	assert_str(String(CONFIG.group_for(body, Vector3.BACK))).is_equal("concrete")
	assert_str(String(CONFIG.group_for(body, Vector3.DOWN))).is_equal("concrete")
	assert_str(String(CONFIG.group_for(body, Vector3.UP))).is_equal("wood")


func test_a_kit_room_has_concrete_walls_over_a_wood_floor() -> void:
	var room := auto_free(Room.new()) as Room
	room.floor_surface = "wood"

	assert_str(String(CONFIG.group_for(room, Vector3.LEFT))).is_equal("concrete")
	assert_str(String(CONFIG.group_for(room, Vector3.UP))).is_equal("wood")


func test_material_tags_of_the_entity_above_the_collider_pick_the_group() -> void:
	var expected := {
		&"material.metal": &"metal",
		&"material.electronics": &"metal",
		&"material.wood": &"wood",
		&"material.cardboard": &"wood",
		&"material.glass": &"glass",
	}
	for tag: StringName in expected:
		var entity := auto_free(Node3D.new()) as Node3D
		var tags := Tags.new()
		tags.name = "Tags"
		tags.container.add(tag)
		entity.add_child(tags)
		var collider := StaticBody3D.new()
		entity.add_child(collider)
		assert_str(String(CONFIG.group_for(collider, Vector3.BACK))).is_equal(String(expected[tag]))


func test_bodies_are_hitboxes_or_body_parts() -> void:
	var hitbox := _static_body()
	hitbox.set_meta(Hitboxes.META, &"torso")
	var character := _static_body()
	# Never in the tree: its _ready (which needs an entity) does not run.
	var parts := BodyParts.new()
	parts.name = "BodyParts"
	character.add_child(parts)

	assert_str(String(CONFIG.group_for(hitbox, Vector3.BACK))).is_equal("body")
	assert_str(String(CONFIG.group_for(character, Vector3.BACK))).is_equal("body")


func test_anything_else_is_concrete() -> void:
	assert_str(String(CONFIG.group_for(_static_body(), Vector3.BACK))).is_equal("concrete")
	assert_str(String(CONFIG.group_for(null))).is_equal("concrete")


func test_shipped_props_carry_their_material() -> void:
	var metal := METAL_CRATE.instantiate() as Node3D
	var wood := SMALL_CRATE.instantiate() as Node3D
	var root := auto_free(Node3D.new()) as Node3D
	add_child(root)
	root.global_position = ORIGIN
	root.add_child(metal)
	root.add_child(wood)

	assert_str(String(CONFIG.group_for(metal, Vector3.BACK))).is_equal("metal")
	assert_str(String(CONFIG.group_for(wood, Vector3.BACK))).is_equal("wood")


func test_each_group_has_its_look() -> void:
	var metal := CONFIG.puff(&"metal")
	var concrete := CONFIG.puff(&"concrete")
	var wood := CONFIG.puff(&"wood")
	var glass := CONFIG.puff(&"glass")
	var body := CONFIG.puff(ShotFxConfig.BODY)
	var stun := CONFIG.puff(ShotFxConfig.STUN)
	for look: ImpactPuff in [metal, concrete, wood, glass, body, stun]:
		assert_object(look).is_not_null()
	# Sparks: bright, fast, falling, short-lived; dust: slow and drifting; splinters fall.
	assert_bool(metal.glow).is_true()
	assert_float(metal.speed_max).is_greater(concrete.speed_max)
	assert_float(metal.gravity).is_greater(concrete.gravity)
	assert_float(metal.lifetime).is_less(concrete.lifetime)
	assert_float(wood.gravity).is_greater(concrete.gravity)
	# Glass cracks; bodies and stun hits leave no hole; the stun spark is blue-white and glows.
	assert_bool(glass.cracks).is_true()
	assert_bool(body.hole).is_false()
	assert_bool(stun.hole).is_false()
	assert_bool(stun.glow).is_true()
	assert_float(stun.color.b).is_greater(stun.color.r)
	assert_float(body.color.r).is_greater(body.color.g * 4.0)
	assert_object(CONFIG.puff(&"unknown")).is_same(concrete)


func _static_body() -> StaticBody3D:
	return auto_free(StaticBody3D.new()) as StaticBody3D
