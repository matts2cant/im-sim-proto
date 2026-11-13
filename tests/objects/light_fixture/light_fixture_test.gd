extends GdUnitTestSuite
## Integration (ADR 0066): the ceiling and wall lamps are composed from shared components
## (Breakable, Powered, a Light3D) and nothing else. A `damage.ballistic` ray breaks a lamp: glass
## noise, debris, the entity (and with it its light) is gone, and an entity standing under it drops
## to ambient light. Powered off hides the light and bulb; the lamp's own body never shadows its
## light.

const Wait := preload("res://tests/helpers/wait.gd")
const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const CONFIG: LightExposureConfig = preload("res://actors/common/light/light_exposure.tres")
const CEILING_LAMP := "res://objects/light_fixture/ceiling_lamp.tscn"
const WALL_LAMP := "res://objects/light_fixture/wall_lamp.tscn"
const PISTOL_DAMAGE := 25.0

var _root: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	add_child(_root)
	Characters.floor_box(_root)


func after_test() -> void:
	StimulusSystem.clear()


func _watcher(feet: Vector3) -> LightExposure:
	var body := Characters.character(_root, "Watcher", feet, [])
	var exposure := LightExposure.new()
	body.add_child(exposure)
	return exposure


func _shoot(from: Vector3, at: Vector3) -> void:
	var ray := Stimulus.make_ray(
		&"damage.ballistic", PISTOL_DAMAGE, from, at - from, 50.0, null, PhysicsLayers.WEAPON_MASK
	)
	StimulusSystem.emit(ray)
	await Wait.frames(get_tree(), 4)


func test_lamps_are_composed_from_shared_components() -> void:
	for path: String in [CEILING_LAMP, WALL_LAMP]:
		var lamp: Node3D = auto_free((load(path) as PackedScene).instantiate())

		assert_object(Breakable.of(lamp)).override_failure_message(path).is_not_null()
		assert_object(Powered.of(lamp)).override_failure_message(path).is_not_null()
		assert_int(lamp.find_children("*", "Light3D", true, false).size()).is_equal(1)
		assert_bool(lamp is StaticBody3D).is_true()
		assert_int((lamp as StaticBody3D).collision_layer).is_equal(PhysicsLayers.WORLD)
		assert_array((lamp.get_node("Tags") as Tags).initial_tags).contains([&"object.lamp"])
		assert_object(lamp.get_script()).is_null()


func test_a_shot_breaks_the_ceiling_lamp_and_its_light_goes_out() -> void:
	var lamp := Objects.spawn(_root, CEILING_LAMP, Vector3(0, 4, 0), "Lamp")
	var exposure := _watcher(Vector3(0.5, 0, 0))
	await Wait.frames(get_tree(), 3)
	var lit := exposure.update_now()

	await _shoot(Vector3(3, 1.5, 0), Vector3(0, 3.8, 0))

	assert_float(lit).is_greater(0.6)
	assert_bool(is_instance_valid(lamp)).is_false()
	assert_array(Objects.logged(&"object.broken", "object", "Lamp")).has_size(1)
	assert_float(exposure.update_now()).is_equal_approx(CONFIG.ambient, 0.0001)
	var noises := EventLog.find(&"stimulus.emitted").filter(
		func(entry: EventLogEntry) -> bool: return entry.data["type"] == &"noise" and entry.source == "Lamp"
	)
	assert_array(noises).has_size(1)


func test_a_shot_breaks_the_wall_lamp() -> void:
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.2)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(0, 2, -0.1)
	_root.add_child(wall)
	var lamp := Objects.spawn(_root, WALL_LAMP, Vector3(0, 2.4, 0), "WallLamp")
	var exposure := _watcher(Vector3(0, 0, 1.2))
	await Wait.frames(get_tree(), 3)
	var lit := exposure.update_now()

	await _shoot(Vector3(0, 1.6, 4), Vector3(0, 2.4, 0.15))

	assert_float(lit).is_greater(0.3)
	assert_bool(is_instance_valid(lamp)).is_false()
	assert_float(exposure.update_now()).is_equal_approx(CONFIG.ambient, 0.0001)


func test_powered_off_hides_light_and_bulb() -> void:
	var lamp := Objects.spawn(_root, CEILING_LAMP, Vector3(0, 4, 0), "Lamp")
	var exposure := _watcher(Vector3(0.5, 0, 0))
	await Wait.frames(get_tree(), 3)
	var powered := Powered.of(lamp)

	powered.on = false

	assert_bool((lamp.get_node("Light") as Node3D).visible).is_false()
	assert_bool((lamp.get_node("Bulb") as Node3D).visible).is_false()
	assert_float(exposure.update_now()).is_equal_approx(CONFIG.ambient, 0.0001)

	powered.on = true
	assert_bool((lamp.get_node("Light") as Node3D).visible).is_true()
	assert_float(exposure.update_now()).is_greater(0.6)


func test_the_lamp_body_does_not_shadow_its_own_light() -> void:
	# Straight below: every shadow ray passes through the lamp's collision box near the light.
	Objects.spawn(_root, CEILING_LAMP, Vector3(0, 4, 0), "Lamp")
	var exposure := _watcher(Vector3.ZERO)
	await Wait.frames(get_tree(), 3)

	assert_float(exposure.update_now()).is_greater(0.6)
