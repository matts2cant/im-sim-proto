extends GdUnitTestSuite
## ShotFx, the world's pooled shot effects (ADR 0126): a hit plays its material's puff and leaves a
## hole only on a static surface without marks of its own (never on bodies or moving props); glass
## cracks; holes are capped (the oldest reused) and fade after their life; tracers (TracerMotion)
## cross 30 m in about 0.1 s, trail a short streak, fade and free their pool slot. Built on bare
## bodies in code and a ShotFx of its own (not the viewport's).

const CONFIG: ShotFxConfig = preload("res://items/weapons/fx/shot_fx.tres")
const ORIGIN := Vector3(-280, 0, 360)

var _fx: ShotFx
var _wall: StaticBody3D


func before_test() -> void:
	var root := auto_free(Node3D.new()) as Node3D
	add_child(root)
	_fx = ShotFx.new()
	_fx.name = "TestShotFx"
	root.add_child(_fx)
	_wall = StaticBody3D.new()
	_wall.set_meta(&"surface", &"concrete")
	root.add_child(_wall)
	_wall.global_position = ORIGIN


func test_a_hit_on_a_static_surface_puffs_and_leaves_a_hole() -> void:
	var group := _fx.impact(_wall, ORIGIN, Vector3.BACK)

	assert_str(String(group)).is_equal("concrete")
	assert_int(_fx.puffs_played.get(&"concrete", 0)).is_equal(1)
	assert_int(_fx.holes.count()).is_equal(1)
	assert_vector(_fx.holes.points()[0]).is_equal_approx(ORIGIN, Vector3.ONE * 0.001)


func test_metal_sparks_and_glass_cracks() -> void:
	var metal := StaticBody3D.new()
	metal.set_meta(&"surface", &"metal")
	_wall.add_child(metal)

	assert_str(String(_fx.impact(metal, ORIGIN, Vector3.BACK))).is_equal("metal")
	_fx.impact(_wall, ORIGIN, Vector3.BACK, &"glass")

	assert_int(_fx.puffs_played.get(&"metal", 0)).is_equal(1)
	assert_int(_fx.holes.count()).is_equal(1)
	assert_int(_fx.cracks.count()).is_equal(1)


func test_no_hole_on_bodies_moving_props_or_surfaces_keeping_their_own_marks() -> void:
	var hitbox := StaticBody3D.new()
	hitbox.set_meta(Hitboxes.META, &"torso")
	_wall.add_child(hitbox)
	var prop := RigidBody3D.new()
	prop.freeze = true
	_wall.add_child(prop)
	var marked := StaticBody3D.new()
	var marks := ImpactMarks.new()
	marked.add_child(marks)
	_wall.add_child(marked)

	assert_str(String(_fx.impact(hitbox, ORIGIN, Vector3.BACK))).is_equal("body")
	_fx.impact(prop, ORIGIN, Vector3.BACK)
	_fx.impact(marked, ORIGIN, Vector3.BACK)

	assert_int(_fx.hole_count()).is_equal(0)
	assert_int(_fx.puffs_played.get(&"body", 0)).is_equal(1)
	assert_int(_fx.puffs_played.get(&"concrete", 0)).is_equal(2)


func test_holes_are_capped_the_oldest_reused() -> void:
	var cap := CONFIG.max_holes
	for i in cap + 10:
		_fx.impact(_wall, ORIGIN + Vector3(0.01 * i, 0, 0), Vector3.BACK)

	assert_int(cap).is_equal(200)
	assert_int(_fx.holes.count()).is_equal(cap)
	assert_float(_fx.holes.points()[0].x - ORIGIN.x).is_equal_approx(0.1, 0.0001)


func test_holes_fade_after_their_life() -> void:
	_fx.impact(_wall, ORIGIN, Vector3.BACK)
	_fx.step(CONFIG.hole_life - 0.5)

	assert_int(_fx.holes.visible_count()).is_equal(1)
	assert_float(_fx.holes.opacity(0)).is_equal(1.0)

	_fx.step(0.5 + CONFIG.hole_fade * 0.5)
	assert_float(_fx.holes.opacity(0)).is_equal_approx(0.5, 0.01)

	_fx.step(CONFIG.hole_fade)
	assert_int(_fx.holes.visible_count()).is_equal(0)


func test_tracer_crosses_30_m_in_about_0_1_s() -> void:
	var motion := TracerMotion.new(
		Vector3.ZERO, Vector3(0, 0, -30), CONFIG.tracer_speed, CONFIG.tracer_length, CONFIG.tracer_fade
	)

	assert_float(motion.travel_time()).is_equal_approx(0.1, 0.005)
	var halfway := motion.segment(0.05)
	assert_float(halfway[1].z).is_equal_approx(-15.0, 0.01)
	assert_float(halfway[0].z).is_equal_approx(-15.0 + CONFIG.tracer_length, 0.01)
	# Never behind the muzzle, never past the hit.
	assert_float(motion.segment(0.002)[0].z).is_equal(0.0)
	assert_float(motion.segment(1.0)[1].z).is_equal_approx(-30.0, 0.001)
	assert_float(motion.alpha(0.09)).is_equal(1.0)
	assert_float(motion.alpha(0.1 + CONFIG.tracer_fade * 0.5)).is_equal_approx(0.5, 0.05)
	assert_bool(motion.is_done(0.1 + CONFIG.tracer_fade + 0.01)).is_true()


func test_tracers_travel_fade_and_free_their_slot() -> void:
	_fx.tracer(ORIGIN, ORIGIN + Vector3(0, 0, -30))

	assert_int(_fx.active_tracers()).is_equal(1)
	_fx.step(0.05)
	var segment := _fx.tracer_segment(0)
	assert_float(segment[1].z - ORIGIN.z).is_equal_approx(-15.0, 0.01)

	_fx.step(0.1 + CONFIG.tracer_fade)
	assert_int(_fx.active_tracers()).is_equal(0)


func test_more_tracers_than_the_pool_reuse_the_oldest() -> void:
	for i in ShotFx.TRACER_POOL + 4:
		_fx.tracer(ORIGIN, ORIGIN + Vector3(0, 0, -30))

	assert_int(_fx.active_tracers()).is_equal(ShotFx.TRACER_POOL)
	assert_int(_fx.tracers_started).is_equal(ShotFx.TRACER_POOL + 4)


func test_a_missed_shot_tracer_stops_at_its_max_distance() -> void:
	_fx.tracer(ORIGIN, ORIGIN + Vector3(0, 0, -500))

	assert_float(_fx.last_tracer().distance()).is_equal_approx(CONFIG.tracer_max_distance, 0.01)


func test_frozen_effects_hold_still_and_clear_empties_the_pool() -> void:
	_fx.impact(_wall, ORIGIN, Vector3.BACK)
	_fx.tracer(ORIGIN, ORIGIN + Vector3(0, 0, -30))
	_fx.frozen = true
	_fx.step(1.0)

	assert_int(_fx.active_tracers()).is_equal(1)

	_fx.frozen = false
	_fx.clear()
	assert_int(_fx.hole_count()).is_equal(0)
	assert_int(_fx.active_tracers()).is_equal(0)
