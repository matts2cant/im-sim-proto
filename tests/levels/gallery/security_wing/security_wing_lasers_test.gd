extends GdUnitTestSuite
## Gallery room 5 (security wing): the laser hall (ADR 0096). `Shell/LaserHall` (interior x -7.5 ..
## -4.5, z 9.5 .. 17.5, 3 m high) shares closet D1's back wall and opens from it (1.2 x 2.2 m at x
## -6.25). Four laser tripwires on its west wall face (x -7.49) beam 2.98 m east to receivers on its
## east wall face: LaserLow 0.4 m at z 11.5, LaserHigh 1.3 m at z 14.5, and the pair LaserPairLow /
## LaserPairHigh (0.4 m + 1.3 m) at z 16.4, all cabled to the wing's switch. The real player walks
## in from the hall through D1 (opened), jumps the low beam (take-off 1.3 m before it, mid-window of
## 0.64-1.92 m), crouches under the high one, stops between the high beam and the pair, then walks
## into the pair: the incident rings the wing's alarm. Room-local coordinates (origin on the hub
## wall's outer face, +Z south); fixture `fixtures/wing_player.tscn` puts the wing and a player at
## (600, 0, -300).

const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const ROOM_SCENE: PackedScene = preload("res://levels/gallery/security_wing/security_wing.tscn")
const FIXTURE := "res://tests/levels/gallery/security_wing/fixtures/wing_player.tscn"
## Name, height above the floor, z of the beam.
const LASERS: Array[Array] = [
	["LaserLow", 0.4, 11.5], ["LaserHigh", 1.3, 14.5], ["LaserPairLow", 0.4, 16.4], ["LaserPairHigh", 1.3, 16.4]
]
const CAPSULE_RADIUS := 0.35
## Walking line through D1 and into the hall (the doorways span x -7.0 .. -5.8 and -6.85 .. -5.65).
const LANE_X := -6.3
## Walking jump: 2.56 m from take-off to landing (4 m/s x 0.64 s).
const JUMP_LENGTH := 2.56
const TAKE_OFF := 1.3


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	StimulusSystem.clear()


func test_the_laser_hall_shares_closet_d1s_back_wall() -> void:
	var room := _room()
	var hall := room.get_node("Shell/LaserHall") as Room
	var closet := room.get_node("Shell/ClosetD1") as Room
	var inside := _interior(hall)
	assert_float(hall.wall_thickness).is_equal(0.5)
	assert_float(inside.position.y).is_equal_approx(_interior(closet).end.y + 0.5, 0.0001)
	assert_float(inside.size.x).is_equal_approx(3.0, 0.0001)
	assert_float(hall.size.y).is_greater_equal(2.5)
	# The same 1.2 x 2.2 m opening in both walls.
	var into_hall := closet.openings[1]
	var from_closet := hall.openings[0]
	assert_int(into_hall.wall).is_equal(RoomOpening.Wall.SOUTH)
	assert_int(from_closet.wall).is_equal(RoomOpening.Wall.NORTH)
	assert_float(closet.position.x + into_hall.offset).is_equal_approx(hall.position.x + from_closet.offset, 0.0001)
	assert_vector(Vector2(into_hall.width, into_hall.height)).is_equal(Vector2(from_closet.width, from_closet.height))
	# The walking lane clears both doorways with the capsule.
	var door_x := (room.get_node("Doors/D1Keypad") as Node3D).position.x
	for edge: float in [door_x - 0.6, closet.position.x + into_hall.offset - 0.6]:
		assert_float(LANE_X - CAPSULE_RADIUS - edge).is_greater(0.1)
	for edge: float in [door_x + 0.6, closet.position.x + into_hall.offset + 0.6]:
		assert_float(edge - (LANE_X + CAPSULE_RADIUS)).is_greater(0.1)
	await KitGeometry.settle(get_tree(), 5)
	var space := room.get_world_3d().direct_space_state
	for height: float in [0.1, 0.9, 1.85]:
		var from := room.to_global(Vector3(LANE_X, height, 7.6))
		var to := room.to_global(Vector3(LANE_X, height, 11.0))
		assert_bool(PhysicsLayers.segment_clear(space, from, to)).override_failure_message(str(height)).is_true()


func test_beams_cross_the_hall_wall_to_wall_at_the_preset_heights() -> void:
	var room := _room()
	await KitGeometry.settle(get_tree(), 5)
	var space := room.get_world_3d().direct_space_state
	var inside := _interior(room.get_node("Shell/LaserHall") as Room)
	for spec: Array in LASERS:
		var laser := room.get_node("Devices/" + String(spec[0])) as Node3D
		var where := String(spec[0])
		var behaviour := LaserTripwire.of(laser)
		assert_float(laser.position.y).override_failure_message(where).is_equal_approx(float(spec[1]), 0.0001)
		assert_float(laser.position.z).override_failure_message(where).is_equal_approx(float(spec[2]), 0.0001)
		assert_vector(laser.basis.z).override_failure_message(where).is_equal_approx(Vector3.RIGHT, Vector3.ONE * 0.001)
		# The emitter sits on the west wall face; the receiver on the east one.
		assert_float(laser.position.x - inside.position.x).override_failure_message(where).is_between(0.0, 0.02)
		assert_float(inside.end.x - (laser.position.x + behaviour.beam_length)).is_between(0.0, 0.02)
		# Nothing of the world crosses the beam: the first world hit along it is the east wall.
		var exclude: Array[RID] = [(laser as CollisionObject3D).get_rid()]
		var query := PhysicsRayQueryParameters3D.create(
			behaviour.beam_start(),
			room.to_global(Vector3(inside.end.x + 0.3, float(spec[1]), float(spec[2]))),
			1,
			exclude
		)
		var hit := space.intersect_ray(query)
		assert_bool(hit.is_empty()).override_failure_message(where).is_false()
		assert_float(room.to_local(hit["position"] as Vector3).x).override_failure_message(where).is_equal_approx(
			inside.end.x, 0.01
		)
	# A walking jump from mid-window lands clear of the high beam, with room to crouch.
	var low_z := float(LASERS[0][2])
	var high_z := float(LASERS[1][2])
	var take_off := low_z - TAKE_OFF
	assert_float(take_off - CAPSULE_RADIUS).is_greater(inside.position.y)
	assert_float(high_z - CAPSULE_RADIUS - (take_off + JUMP_LENGTH + CAPSULE_RADIUS)).is_greater(1.0)
	# Room to stand up between the high beam and the pair.
	assert_float(float(LASERS[2][2]) - high_z - CAPSULE_RADIUS * 2.0).is_greater(1.0)


func test_jump_crouch_then_the_pair_rings_the_alarm() -> void:
	var runner := scene_runner(FIXTURE)
	var driver := PlayerDriver.new(runner)
	var player := driver.player
	var wing := runner.find_child("SecurityWing") as Node3D
	Door.of(wing.get_node("Doors/D1Keypad")).open()
	await driver.frames(40)
	await driver.place(wing.to_global(Vector3(LANE_X, 0, 4.5)), PI)
	# Walk in and jump the low beam.
	runner.simulate_action_press(&"move_forward")
	var jumped := false
	for i in 400:
		var z := wing.to_local(player.global_position).z
		if z > 13.0:
			break
		if not jumped and z >= float(LASERS[0][2]) - TAKE_OFF:
			jumped = true
			runner.simulate_action_press(&"jump")
		await driver.frames(1)
		runner.simulate_action_release(&"jump")
	runner.simulate_action_release(&"move_forward")
	await driver.frames(30)
	assert_bool(jumped).is_true()
	assert_float(wing.to_local(player.global_position).z).is_between(12.5, 13.8)
	assert_array(EventLog.find(&"laser.tripped")).is_empty()
	# Crouch under the high beam, stop short of the pair and stand up.
	runner.simulate_action_press(&"crouch")
	await driver.frames(5)
	runner.simulate_action_press(&"move_forward")
	for i in 400:
		if wing.to_local(player.global_position).z > 15.2:
			break
		await driver.frames(1)
	runner.simulate_action_release(&"move_forward")
	await driver.frames(20)
	runner.simulate_action_release(&"crouch")
	await driver.frames(10)
	assert_bool(player.crouched).is_false()
	assert_float(wing.to_local(player.global_position).z).is_between(15.0, 15.7)
	assert_array(EventLog.find(&"laser.tripped")).is_empty()
	# Into the pair: the incident reaches the wing's controller, which rings its sirens.
	await driver.hold(&"move_forward", 30)
	await driver.frames(10)
	# A standing body breaks both beams of the pair: two incidents (the second restarts the alarm).
	var lasers: Array[String] = []
	for entry in EventLog.find(&"laser.tripped"):
		lasers.append(String(entry.data["laser"]))
		assert_int(int(entry.data["controllers"])).is_equal(1)
	assert_array(lasers).contains_exactly_in_any_order(["LaserPairLow", "LaserPairHigh"])
	assert_array(EventLog.find(&"alarm.raised")).is_not_empty()
	assert_array(EventLog.find(&"siren.started")).is_not_empty()


func _room() -> Node3D:
	var room := auto_free(ROOM_SCENE.instantiate()) as Node3D
	room.position = Vector3(-300, 0, 600)
	add_child(room)
	return room


# Interior bounds of a kit Room in room-local x / z (Rect2 position x = x, y = z).
static func _interior(room: Room) -> Rect2:
	var half := Vector2(room.size.x, room.size.z) * 0.5
	return Rect2(Vector2(room.position.x, room.position.z) - half, half * 2.0)
