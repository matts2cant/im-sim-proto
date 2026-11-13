extends GdUnitTestSuite
## Surface.of() (ADR 0138): the one reading of what a collider is made of: `wall_surface` metadata on
## non-floor faces, else `surface` metadata (static geometry), else the `material.*` tag of the nearest
## entity above the collider with Tags, else &"". Bare nodes built in code, plus the shipped metal
## crate for the data it carries.

const METAL_CRATE: PackedScene = preload("res://objects/metal_crate/metal_crate.tscn")


func test_surface_metadata_wins() -> void:
	var body := _tagged_body(&"material.metal")
	body.set_meta(Surface.META, &"carpet")
	assert_str(String(Surface.of(body))).is_equal("carpet")


func test_wall_metadata_is_read_on_walls_only() -> void:
	var body := auto_free(StaticBody3D.new()) as StaticBody3D
	body.set_meta(Surface.META, &"wood")
	body.set_meta(Surface.WALL_META, &"concrete")
	assert_str(String(Surface.of(body))).is_equal("wood")
	assert_str(String(Surface.of(body, Vector3.UP))).is_equal("wood")
	assert_str(String(Surface.of(body, Vector3.BACK))).is_equal("concrete")
	assert_str(String(Surface.of(body, Vector3.DOWN))).is_equal("concrete")


func test_material_tag_of_the_entity_above_the_collider() -> void:
	assert_str(String(Surface.of(_tagged_body(&"material.glass"), Vector3.BACK))).is_equal("glass")


func test_material_tag_takes_its_first_level_and_ignores_other_tags() -> void:
	var tags := TagContainer.new()
	tags.add(&"object.crate")
	tags.add(&"material.metal.steel")
	assert_str(String(Surface.of_tags(tags))).is_equal("metal")
	var plain := TagContainer.new()
	plain.add(&"object.crate")
	assert_str(String(Surface.of_tags(plain))).is_empty()


func test_nothing_reads_empty() -> void:
	assert_str(String(Surface.of(auto_free(StaticBody3D.new())))).is_empty()
	assert_str(String(Surface.of(null))).is_empty()


func test_the_shipped_metal_crate_is_metal() -> void:
	var crate := auto_free(METAL_CRATE.instantiate()) as Node3D
	# Out of the tree, Tags has not read its initial tags yet: add the scene's.
	var tags := crate.get_node("Tags") as Tags
	for tag in tags.initial_tags:
		tags.add(tag)
	assert_str(String(Surface.of(crate))).is_equal("metal")


# A collider (no metadata) under an entity with Tags holding `tag`.
func _tagged_body(tag: StringName) -> StaticBody3D:
	var entity := auto_free(Node3D.new()) as Node3D
	var tags := Tags.new()
	tags.name = "Tags"
	tags.add(tag)
	entity.add_child(tags)
	var body := StaticBody3D.new()
	entity.add_child(body)
	return body
