extends GdUnitTestSuite
## Fence kit part: evenly spaced bars and rails, collision that stops a capsule but lets rays through
## the gaps (see-through: sight, shots and light), navigation source group, warnings for gaps a
## crouched player could pass.

const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const SCENE: PackedScene = preload("res://levels/kit/fence.tscn")
## Far from other suites' fixtures.
const ORIGIN := Vector3(300, 0, -300)


func _fence() -> Fence:
	return auto_free(SCENE.instantiate()) as Fence


func test_bars_are_evenly_spaced_from_end_to_end() -> void:
	var part := _fence()
	part.length = 2.0
	part.bar_spacing = 0.22

	var bars := part.bar_positions()
	assert_int(bars.size()).is_equal(11)
	assert_float(bars[0]).is_equal(0.0)
	assert_float(bars[-1]).is_equal_approx(2.0, 0.0001)
	assert_float(bars[1] - bars[0]).is_less_equal(0.22)


func test_capsule_is_stopped_but_rays_pass_between_bars() -> void:
	var part := _fence()
	part.length = 4.0
	part.height = 3.0
	add_child(part)
	part.global_position = ORIGIN
	await KitGeometry.settle(get_tree(), 2)
	var space := part.get_world_3d().direct_space_state

	# A ray between two bars (centres 0.2 m apart) at eye height crosses the fence.
	var gap_x := (part.bar_positions()[5] + part.bar_positions()[6]) * 0.5
	var through := ORIGIN + Vector3(gap_x, 1.6, 0)
	(
		assert_bool(
			KitGeometry.ray(part.get_world_3d(), through + Vector3(0, 0, -1), through + Vector3(0, 0, 1)).is_empty()
		)
		. is_true()
	)
	# A ray along a bar is stopped.
	var bar := ORIGIN + Vector3(part.bar_positions()[5], 1.6, 0)
	(
		assert_bool(KitGeometry.ray(part.get_world_3d(), bar + Vector3(0, 0, -1), bar + Vector3(0, 0, 1)).is_empty())
		. is_false()
	)
	# A crouched player's capsule anywhere along the fence overlaps it.
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 0.95
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, through + Vector3(0, -1.1, 0))
	assert_bool(space.intersect_shape(query, 1).is_empty()).is_false()
	assert_bool(part.is_in_group(LevelNavigation.SOURCE_GROUP)).is_true()
	assert_int(part.collision_layer).is_equal(PhysicsLayers.WORLD)


func test_wide_gaps_warn_unless_rails_close_them() -> void:
	var part := _fence()
	part.height = 1.0
	part.bar_spacing = 1.0
	part.rails = PackedFloat32Array([0.5, 0.975])
	assert_array(part._get_configuration_warnings()).is_empty()

	part.rails = PackedFloat32Array([0.975])
	assert_int(part._get_configuration_warnings().size()).is_equal(1)
	part.bar_spacing = 0.22
	assert_array(part._get_configuration_warnings()).is_empty()
