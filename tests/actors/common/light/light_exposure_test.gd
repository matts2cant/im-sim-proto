extends GdUnitTestSuite
## Integration: LightExposure (ADR 0065) on minimal entities in a small fixture (a floor and one
## lamp, built in code): lit under a light, ambient without one, shadowed by a wall and partly by a
## crate, hidden lights and spots pointing away light nothing, crouching samples lower points, the
## level refreshes about 10 times a second, and any entity (a test character, a bare stimulus
## entity, the player) reads the same value on the same spot.

const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const CONFIG: LightExposureConfig = preload("res://actors/common/light/light_exposure.tres")
const PLAYER_SCENE: PackedScene = preload("res://actors/player/player.tscn")
const SMALL_CRATE: PackedScene = preload("res://objects/small_crate/small_crate.tscn")
## A ceiling lamp's light 3.6 m above the floor, as in the perception lab.
const LAMP_HEIGHT := 3.6

var _root: Node3D


func before_test() -> void:
	_root = auto_free(Node3D.new())
	add_child(_root)
	Characters.floor_box(_root)


func _light(position: Vector3, energy: float = 1.0, light_range: float = 5.0) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_energy = energy
	light.omni_range = light_range
	light.shadow_enabled = true
	light.position = position
	_root.add_child(light)
	return light


func _character(feet: Vector3, character_name: String = "Walker") -> CharacterBody3D:
	var body := Characters.character(_root, character_name, feet, [])
	var exposure := LightExposure.new()
	exposure.name = "LightExposure"
	body.add_child(exposure)
	return body


func _settle(count: int = 3) -> void:
	for i in count:
		await get_tree().physics_frame


func _level(entity: Node) -> float:
	return LightExposure.of(entity).update_now()


func test_joins_its_group_and_is_found_on_the_entity() -> void:
	var body := _character(Vector3.ZERO)

	var exposure := LightExposure.of(body)

	assert_object(exposure).is_not_null()
	assert_bool(exposure.is_in_group(LightExposure.GROUP)).is_true()
	assert_object(LightExposure.of(_root)).is_null()


func test_lit_under_a_lamp_and_ambient_without_one() -> void:
	var lit := _character(Vector3.ZERO, "Lit")
	var dark := _character(Vector3(12, 0, 0), "Dark")
	_light(Vector3(0, LAMP_HEIGHT, 0))
	await _settle()

	assert_float(_level(lit)).is_greater_equal(0.6)
	assert_float(_level(dark)).is_equal_approx(CONFIG.ambient, 0.0001)
	assert_int(LightExposure.of(dark).lights_in_reach).is_equal(0)


func test_a_wall_between_light_and_entity_shadows_it() -> void:
	var body := _character(Vector3.ZERO)
	_light(Vector3(3, 1.5, 0))
	await _settle()
	var open := _level(body)
	var wall := StaticBody3D.new()
	wall.collision_layer = PhysicsLayers.WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2, 4, 4)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(1.5, 2, 0)
	_root.add_child(wall)
	await _settle()

	assert_float(open).is_greater(0.5)
	assert_float(_level(body)).is_equal_approx(CONFIG.ambient, 0.0001)


func test_a_crate_hides_the_feet_from_a_low_light() -> void:
	# Light at feet height 3 m away; a 0.6 m crate 0.5-1.1 m from the entity blocks the 0.2 m point,
	# while the ray to the 1.0 m point passes 0.1 m above it.
	var body := _character(Vector3.ZERO)
	_light(Vector3(3, 0.2, 0))
	await _settle()
	var open := _level(body)
	var crate: Node3D = SMALL_CRATE.instantiate()
	crate.position = Vector3(0.8, 0.3, 0)
	_root.add_child(crate)
	await _settle(5)

	var hidden := _level(body)

	assert_float(hidden).is_less(open - 0.05)
	assert_float(hidden).is_greater(CONFIG.ambient + 0.1)


func test_hidden_and_zero_energy_lights_light_nothing() -> void:
	var body := _character(Vector3.ZERO)
	var light := _light(Vector3(0, LAMP_HEIGHT, 0))
	await _settle()
	light.visible = false

	assert_float(_level(body)).is_equal_approx(CONFIG.ambient, 0.0001)

	light.visible = true
	light.light_energy = 0.0
	assert_float(_level(body)).is_equal_approx(CONFIG.ambient, 0.0001)


func test_spot_light_lights_only_inside_its_cone() -> void:
	var body := _character(Vector3.ZERO)
	var spot := SpotLight3D.new()
	spot.spot_range = 6.0
	spot.spot_angle = 30.0
	spot.light_energy = 1.0
	spot.position = Vector3(0, LAMP_HEIGHT, 0)
	# -Z of the light points down.
	spot.rotation_degrees = Vector3(-90, 0, 0)
	_root.add_child(spot)
	await _settle()
	var down := _level(body)
	spot.rotation_degrees = Vector3(90, 0, 0)

	assert_float(down).is_greater(0.5)
	assert_float(_level(body)).is_equal_approx(CONFIG.ambient, 0.0001)


func test_crouching_samples_lower_points() -> void:
	var body := _character(Vector3.ZERO)
	_light(Vector3(0, LAMP_HEIGHT, 0), 0.35, 4.0)
	await _settle()
	var standing := _level(body)
	Characters.tags_of(body).add(ActorState.CROUCHING)

	var crouched := _level(body)

	assert_float(crouched).is_less(standing - 0.05)
	assert_float(crouched).is_greater(CONFIG.ambient)


func test_level_refreshes_about_ten_times_a_second() -> void:
	var body := _character(Vector3.ZERO)
	var exposure := LightExposure.of(body)
	var light := _light(Vector3(0, LAMP_HEIGHT, 0))
	light.visible = false
	await _settle(8)
	assert_float(exposure.level).is_equal_approx(CONFIG.ambient, 0.0001)
	light.visible = true
	# The next update is at most 6 ticks (0.1 s) away.
	var waited := 0
	while exposure.level < 0.5 and waited < 12:
		await get_tree().physics_frame
		waited += 1
	assert_int(waited).is_between(1, 7)

	# Just updated: a change now shows only at the next update, 6 ticks later.
	light.visible = false
	await _settle(3)
	assert_float(exposure.level).is_greater(0.5)
	await _settle(5)
	assert_float(exposure.level).is_equal_approx(CONFIG.ambient, 0.0001)


func test_entity_own_colliders_never_shadow_it() -> void:
	# A 2 m box on the objects layer (a shadow-casting layer) around the sample points.
	var box := Fixtures.rigid_entity(_root, "BigBox", Vector3(0, 1.0, 0), [], [], 2.0, 10.0, 0.0)
	box.freeze = true
	var exposure := LightExposure.new()
	box.add_child(exposure)
	_light(Vector3(0, LAMP_HEIGHT, 0))
	await _settle()

	assert_float(exposure.update_now()).is_greater(0.5)


func test_any_entity_reads_the_same_level_as_the_player() -> void:
	var spot_feet := Vector3(1.0, 0, -0.5)
	_light(Vector3(0, LAMP_HEIGHT, 0), 0.8, 5.0)
	_light(Vector3(3, 2.5, 2), 0.4, 4.0)
	var player: Player = PLAYER_SCENE.instantiate()
	player.position = spot_feet
	_root.add_child(player)
	await _settle(5)
	var player_feet := player.global_position
	var player_level := _level(player)
	player.free()
	var character := _character(player_feet, "Guardlike")
	var bare := Fixtures.entity(_root, "Bare", player_feet, [])
	var bare_exposure := LightExposure.new()
	bare.add_child(bare_exposure)
	await _settle()

	assert_float(player_level).is_between(0.2, 0.95)
	assert_float(_level(character)).is_equal_approx(player_level, 0.001)
	assert_float(bare_exposure.update_now()).is_equal_approx(player_level, 0.001)
