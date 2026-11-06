extends GdUnitTestSuite
## Graybox materials: the copied grid shader, world-aligned 1 m grid, one distinct colour each.

const SHADER := "res://assets/materials/graybox/grid_triplanar.gdshader"
const ALL: Array[String] = ["concrete", "carpet", "wood", "metal", "grass", "wall", "ceiling", "hazard", "interactive"]


func test_every_material_uses_the_copied_grid_shader() -> void:
	for material_name: String in ALL:
		var material := GrayboxMaterials.named(material_name) as ShaderMaterial

		assert_object(material).override_failure_message(material_name).is_not_null()
		assert_str(material.shader.resource_path).is_equal(SHADER)
		assert_bool(material.get_shader_parameter(&"world_aligned")).is_true()
		assert_float(material.get_shader_parameter(&"grid_scale")).is_equal(1.0)
		assert_float(material.get_shader_parameter(&"sub_grid_divisions")).is_equal(2.0)


func test_colours_are_distinct() -> void:
	var colours: Array[Color] = []
	for material_name: String in ALL:
		var colour: Color = (GrayboxMaterials.named(material_name) as ShaderMaterial).get_shader_parameter(&"color_a")

		assert_array(colours).override_failure_message(material_name).not_contains([colour])
		colours.append(colour)


func test_metal_is_shiny_and_ceiling_has_no_checker() -> void:
	var metal := GrayboxMaterials.named("metal") as ShaderMaterial
	var ceiling := GrayboxMaterials.named("ceiling") as ShaderMaterial

	assert_float(metal.get_shader_parameter(&"metallic")).is_equal_approx(0.5, 0.001)
	assert_float(metal.get_shader_parameter(&"roughness")).is_equal_approx(0.4, 0.001)
	assert_bool(ceiling.get_shader_parameter(&"use_checker")).is_false()


func test_surfaces_match_the_footstep_table() -> void:
	var table := load("res://actors/player/surface_table.tres") as SurfaceTable

	for surface: String in GrayboxMaterials.SURFACES:
		assert_bool(table.multipliers.has(StringName(surface))).override_failure_message(surface).is_true()
	assert_object(GrayboxMaterials.for_surface("unknown")).is_same(GrayboxMaterials.for_surface("concrete"))
