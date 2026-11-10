extends GdUnitTestSuite
## Unit (ADR 0105): the blocky character models are lit by the scene's lights. The Kenney GLBs mark
## their material unlit (KHR_materials_unlit); the import maps it to a shaded external material.
## Every mesh of a guard's and a training dummy's model draws with a per-pixel shaded material, no
## emission and no override (a headless run cannot render, so the material is checked: an unshaded
## or emissive material is what made them glow in the dark).

const SCENES: Array[String] = ["res://actors/guard/guard_pistol.tscn", "res://actors/dummy/training_dummy.tscn"]


func test_model_materials_respond_to_light() -> void:
	for scene_path in SCENES:
		var entity := auto_free((load(scene_path) as PackedScene).instantiate()) as Node3D
		var model := entity.get_node("Model") as Node3D
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		assert_int(meshes.size()).override_failure_message(scene_path).is_equal(6)
		for node in meshes:
			var mesh := node as MeshInstance3D
			var where := "%s %s" % [scene_path, mesh.name]
			assert_object(mesh.material_override).override_failure_message(where).is_null()
			for surface in mesh.mesh.get_surface_count():
				var material := mesh.get_active_material(surface) as BaseMaterial3D
				assert_object(material).override_failure_message(where).is_not_null()
				assert_int(material.shading_mode).override_failure_message(where).is_equal(
					BaseMaterial3D.SHADING_MODE_PER_PIXEL
				)
				assert_bool(material.emission_enabled).override_failure_message(where).is_false()
				assert_object(material.albedo_texture).override_failure_message(where).is_not_null()
				assert_float(material.metallic).is_equal(0.0)
