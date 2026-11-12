extends GdUnitTestSuite
## Integration (ADR 0128): echo tails by place. A minimal fixture far from the origin: one indoor
## acoustic zone (Acoustics.make_zone(), a 6 x 3 x 6 m box) and the open space beside it.
## - The reverb is chosen from the position: inside the zone its reverb bus (ReverbIndoor), 10 m
##   outside it (centre to centre) the outdoor one; a shot voice plays on Effects inside (the zone
##   sends the tail) and on ReverbOutdoor outside, and lets zones reach it (area_mask).
## - A kit Room makes a zone over its interior (none with indoor_acoustics off).
## - The two reverb buses exist and send to Effects (the effects volume applies).

const ORIGIN := Vector3(-260, 0, -260)

var _root: Node3D


func before_test() -> void:
	_root = auto_free(Node3D.new()) as Node3D
	add_child(_root)
	_root.position = ORIGIN


func test_the_reverb_bus_is_chosen_from_the_position() -> void:
	_root.add_child(Acoustics.make_zone(Vector3(6, 3, 6), Vector3(0, 1.5, 0)))
	await _physics(2)
	var world := _root.get_world_3d()
	var inside := ORIGIN + Vector3(1.0, 1.6, -1.5)
	var outside := ORIGIN + Vector3(10.0, 1.6, 0.0)
	assert_str(Acoustics.reverb_bus_at(world, inside)).is_equal(String(Acoustics.INDOOR_BUS))
	assert_str(Acoustics.reverb_bus_at(world, outside)).is_equal(String(Acoustics.OUTDOOR_BUS))
	var audio := ShotAudio.new(3)
	_root.add_child(audio)
	audio.global_position = inside
	assert_str(audio.current_bus()).is_equal(String(GameSettings.EFFECTS_BUS))
	audio.global_position = outside
	assert_str(audio.current_bus()).is_equal(String(Acoustics.OUTDOOR_BUS))
	assert_int(audio.voices()[0].area_mask & PhysicsLayers.ACOUSTICS).is_not_equal(0)


func test_a_room_is_an_indoor_zone_unless_turned_off() -> void:
	var room := Room.new()
	room.size = Vector3(5, 3, 4)
	_root.add_child(room)
	var zone := room.get_node(Acoustics.ZONE_NAME) as Area3D
	assert_object(zone).is_not_null()
	assert_bool(zone.reverb_bus_enabled).is_true()
	assert_int(zone.collision_layer).is_equal(PhysicsLayers.ACOUSTICS)
	var box := (zone.get_child(0) as CollisionShape3D).shape as BoxShape3D
	assert_vector(box.size).is_equal_approx(Vector3(5, 3, 4), Vector3.ONE * 0.001)
	await _physics(2)
	var world := _root.get_world_3d()
	assert_str(Acoustics.reverb_bus_at(world, ORIGIN + Vector3(1, 1.6, 1))).is_equal(String(Acoustics.INDOOR_BUS))
	room.indoor_acoustics = false
	assert_object(room.get_node_or_null(Acoustics.ZONE_NAME)).is_null()


func test_the_reverb_buses_send_to_effects() -> void:
	for bus: StringName in [Acoustics.INDOOR_BUS, Acoustics.OUTDOOR_BUS]:
		var index := AudioServer.get_bus_index(bus)
		assert_int(index).override_failure_message(String(bus)).is_greater(0)
		assert_str(AudioServer.get_bus_send(index)).is_equal(String(GameSettings.EFFECTS_BUS))
		assert_object(AudioServer.get_bus_effect(index, 0) as AudioEffectReverb).is_not_null()


func _physics(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame
