extends GdUnitTestSuite
## Integration: Knockback on a minimal CharacterBody3D whose controller knows nothing about it:
## `force.blast` (RADIUS) shoves it away from the origin, `force.impact` (RAY) along the ray; the
## shove is carried, damped and capped. Stimuli are emitted by the test (no emitter needed).

const Wait := preload("res://tests/helpers/wait.gd")
const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const ROOM := "res://tests/objects/fixtures/carry_room.tscn"
const CONFIG: KnockbackConfig = preload("res://actors/player/player_knockback.tres")
## The explosive barrel's impulse (N s at the centre) and radius (objects/explosive_barrel).
const BARREL_IMPULSE: float = 120.0
const BARREL_RADIUS: float = 4.0
const BARREL_CENTRE_HEIGHT: float = 0.45

var _root: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	add_child(_root)
	Characters.floor_box(_root)


func test_blast_at_two_metres_shoves_away_and_damps_out() -> void:
	var walker := await _standing_walker(Vector3.ZERO)
	var origin := Vector3(-2, BARREL_CENTRE_HEIGHT, 0)

	StimulusSystem.emit(Stimulus.make_radius(&"force.blast", BARREL_IMPULSE, origin, BARREL_RADIUS))
	var peak := await _peak_height(walker, 120)

	var moved := walker.global_position
	assert_float(moved.x).is_greater(0.5)
	assert_float(moved.x).is_less(3.0)
	assert_float(absf(moved.z)).is_less(0.01)
	assert_float(peak).is_less(0.5)
	var knockback := Knockback.of(walker)
	assert_bool(knockback.carried.is_zero_approx()).is_true()
	var pushes := EventLog.find(&"actor.knocked_back")
	assert_array(pushes).has_size(1)
	# Perceived at the receiver (1.2 m up): linear falloff from the centre.
	var distance := origin.distance_to(Vector3(0, 1.2, 0))
	var perceived := BARREL_IMPULSE * (1.0 - distance / BARREL_RADIUS)
	assert_float(pushes[0].data["impulse"]).is_equal_approx(perceived, 0.01)


func test_player_is_shoved_by_a_barrel_blast_at_two_metres_and_stops() -> void:
	var driver := PlayerDriver.new(scene_runner(ROOM))
	await driver.settle()
	await driver.place(Vector3(-2, 0, 2))
	StimulusSystem.clear()
	var player := driver.player
	var start := player.global_position

	var origin := Vector3(-4, BARREL_CENTRE_HEIGHT, 2)
	StimulusSystem.emit(Stimulus.make_radius(&"force.blast", BARREL_IMPULSE, origin, BARREL_RADIUS))
	var peak := await _peak_height(player, 90)

	var moved := player.global_position - start
	assert_float(moved.x).is_greater(0.5)
	assert_float(absf(moved.z)).is_less(0.05)
	assert_float(peak).is_less(0.5)
	assert_float(player.horizontal_speed()).is_less(0.01)
	assert_bool(Knockback.of(player).carried.is_zero_approx()).is_true()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_point_blank_blast_is_capped_and_never_lifts_half_a_metre() -> void:
	var walker := await _standing_walker(Vector3.ZERO)
	var origin := Vector3(-0.5, BARREL_CENTRE_HEIGHT, 0)

	StimulusSystem.emit(Stimulus.make_radius(&"force.blast", BARREL_IMPULSE * 3.0, origin, BARREL_RADIUS))
	var peak := await _peak_height(walker, 120)

	assert_float(peak).is_less(0.5)
	var pushes := EventLog.find(&"actor.knocked_back")
	assert_float(pushes[0].data["speed"]).is_less_equal(Vector2(CONFIG.max_speed, CONFIG.max_up_speed).length() + 0.001)


func test_ray_impact_pushes_along_the_ray() -> void:
	var walker := await _standing_walker(Vector3.ZERO)
	var impulse := 40.0

	var ray := Stimulus.make_ray(&"force.impact", impulse, Vector3(0, 1.0, 3), Vector3(0, 0, -1), 10.0)
	StimulusSystem.emit(ray)
	await Wait.frames(get_tree(), 60)

	assert_float(walker.global_position.z).is_less(-0.3)
	assert_float(absf(walker.global_position.x)).is_less(0.01)
	var pushes := EventLog.find(&"actor.knocked_back")
	assert_array(pushes).has_size(1)
	assert_float(pushes[0].data["impulse"]).is_equal_approx(impulse, 0.0001)
	assert_float(pushes[0].data["speed"]).is_equal_approx(impulse * CONFIG.impulse_scale / CONFIG.mass, 0.0001)


func test_wall_stops_the_shove() -> void:
	var walker := await _standing_walker(Vector3.ZERO)
	var wall := StaticBody3D.new()
	wall.collision_layer = PhysicsLayers.WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2, 3, 4)
	shape.shape = box
	wall.add_child(shape)
	_root.add_child(wall)
	# Wall face 0.5 m from the capsule's surface (gap, surface to surface).
	wall.global_position = Vector3(Characters.RADIUS + 0.5 + 0.1, 1.5, 0)
	await Wait.frames(get_tree(), 2)

	StimulusSystem.emit(Stimulus.make_radius(&"force.blast", BARREL_IMPULSE, Vector3(-2, 0.45, 0), 4.0))
	await Wait.frames(get_tree(), 120)

	assert_float(walker.global_position.x).is_less_equal(0.5 + 0.01)
	assert_float(walker.global_position.x).is_greater(0.4)


func test_entity_without_knockback_is_not_moved() -> void:
	var walker := await _standing_walker(Vector3.ZERO, [])

	StimulusSystem.emit(Stimulus.make_radius(&"force.blast", BARREL_IMPULSE, Vector3(-1, 0.45, 0), 4.0))
	await Wait.frames(get_tree(), 30)

	assert_float(walker.global_position.distance_to(Vector3.ZERO)).is_less(0.01)
	assert_array(EventLog.find(&"actor.knocked_back")).is_empty()


func _standing_walker(
	feet: Vector3, components: Array[StringName] = [Characters.KNOCKBACK_COMPONENT]
) -> CharacterBody3D:
	var walker := Characters.character(_root, "Walker", feet + Vector3.UP * 0.02, components)
	await Wait.frames(get_tree(), 10)
	EventLog.clear()
	return walker


# Waits `ticks` physics frames and returns the most the feet rose above where they started.
func _peak_height(walker: CharacterBody3D, ticks: int) -> float:
	var start := walker.global_position.y
	var peak := start
	for i in ticks:
		await get_tree().physics_frame
		peak = maxf(peak, walker.global_position.y)
	return peak - start
