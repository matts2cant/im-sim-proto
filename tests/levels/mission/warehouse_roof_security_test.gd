extends GdUnitTestSuite
## Warehouse roof security (design/levels/mission-warehouse.md "Roof security", ADR 0097): two high
## laser beams (1.3 m; each a one-beam laser array, ADR 0100) cross the parapet gaps where the annex
## stair (west) and the fire escape (east) arrive, post to post with no world geometry across them;
## a camera on a mast in the roof's north-east corner watches duct B's forecourt, lit by a flood
## lamp, and its sweep leaves a window to cross it. Everything is on the yard network: a lit
## intruder in the forecourt or an upright body in a beam rings both controllers; a crouched body
## passes under a beam; breaker A switches the beams and the lamp off and cuts the camera from its
## controller; the console disables them. Coordinates are warehouse (world) coordinates; the
## forecourt lies north of duct B's mouth (x 11, z -5.8).

const Helpers := preload("res://tests/levels/mission/warehouse_security_helpers.gd")
const LASERS: Array[String] = ["LaserRoofWest", "LaserRoofEast"]
const CAMERA := "CameraRoof"
const LAMP := "Hall/Lights/FloodRoof"
const ROOF := 9.5
const BEAM_HEIGHT := 1.3
const DARK := 0.1
const LIT := 0.5
## Where the player stands in the forecourt on the way into duct B's mouth (feet), standing.
const FORECOURT: Array[Vector3] = [
	Vector3(10.2, ROOF, -7.6), Vector3(11.0, ROOF, -7.2), Vector3(12.5, ROOF, -7.6), Vector3(11.0, ROOF, -6.4)
]
## Where a careful player waits in the dark for the camera to turn away: west and east of the duct's
## housing, and the arrivals at the two gaps.
const WAITS: Array[Vector3] = [
	Vector3(9.4, ROOF, -3.0), Vector3(14.5, ROOF, -4.5), Vector3(18.5, ROOF, -3.9), Vector3(-18.5, ROOF, 3.0)
]
## One sweep cycle: 2 x (80 degrees at 15 degrees/s + 2 s hold).
const CYCLE := 14.7
## The longest stretch of a cycle in which no forecourt spot is in the camera's focus (seconds).
const MIN_WINDOW := 6.0

var _helpers: Helpers


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_helpers = Helpers.new()


func after_test() -> void:
	_helpers.teardown()
	StimulusSystem.clear()


func test_beams_cross_the_gaps_post_to_post_at_crouch_height() -> void:
	await _helpers.load_level(self)
	var space := _helpers.level.get_world_3d().direct_space_state
	for laser_name: String in LASERS:
		var entity := _helpers.device_entity(laser_name)
		var laser := LaserArray.of(entity)
		# A one-beam array (ADR 0100): its beam starts at the array's origin.
		assert_int(laser.beams.size()).override_failure_message(laser_name).is_equal(1)
		var beam := laser.beams[0]
		assert_vector(beam.global_position).is_equal_approx(entity.global_position, Vector3.ONE * 0.0001)
		var own: Array[RID] = [(entity as CollisionObject3D).get_rid()]
		# The origin is on the emitter's mount face; the receiver's face is the beam's length along +Z.
		var start := beam.global_position
		var axis := beam.global_basis.z.normalized()
		var length := beam.length
		var end := start + axis * length
		# Nothing of the world crosses the beam between its boxes.
		var inside := _ray(space, start + axis * 0.09, end - axis * 0.09, own)
		assert_dict(inside).override_failure_message("%s: %s across the beam" % [laser_name, inside]).is_empty()
		# Each end sits on a post's face: the first world hit beyond the receiver is the far post at
		# the beam's length, and behind the emitter the near post.
		var beyond := _ray(space, start + axis * 0.09, start + axis * (length + 0.3), own)
		assert_bool(beyond.is_empty()).override_failure_message(laser_name + ": no far post").is_false()
		var far := (beyond["position"] as Vector3).distance_to(start)
		assert_float(far).override_failure_message("%s: far post %.3f m" % [laser_name, far]).is_equal_approx(
			length, 0.02
		)
		var behind := _ray(space, start + axis * 0.09, start - axis * 0.3, own)
		assert_bool(behind.is_empty()).override_failure_message(laser_name + ": no near post").is_false()
		var near := (behind["position"] as Vector3).distance_to(start)
		assert_float(near).override_failure_message("%s: near post %.3f m" % [laser_name, near]).is_equal_approx(
			0.0, 0.02
		)
		# 1.3 m over the gap's floor (the roof): under it crouched, never over it in a jump.
		var middle := (start + end) * 0.5
		var floor_hit := _ray(space, middle, middle + Vector3.DOWN * 3.0, own)
		assert_bool(floor_hit.is_empty()).override_failure_message(laser_name + ": no floor").is_false()
		var height := middle.y - (floor_hit["position"] as Vector3).y
		assert_float(height).override_failure_message("%s: %.3f m up" % [laser_name, height]).is_equal_approx(
			BEAM_HEIGHT, 0.02
		)
		assert_float((floor_hit["position"] as Vector3).y).is_equal_approx(ROOF, 0.02)
		assert_bool(laser.is_watching()).override_failure_message(laser_name + " not watching").is_true()


func test_the_forecourt_is_lit_and_the_waits_around_it_dark() -> void:
	await _helpers.load_level(self)
	var wrong: PackedStringArray = []
	var readings: PackedStringArray = []
	for feet in FORECOURT:
		var level := _measure(feet)
		readings.append("lit %s %.2f" % [feet, level])
		if level < LIT:
			wrong.append("forecourt %s: %.2f" % [feet, level])
	for feet in WAITS:
		var level := _measure(feet)
		readings.append("dark %s %.2f" % [feet, level])
		if level >= DARK:
			wrong.append("wait %s: %.2f" % [feet, level])
	print("roof light: ", ", ".join(readings))
	assert_array(wrong).is_empty()


func test_the_camera_sweep_watches_the_forecourt_and_leaves_a_window() -> void:
	await _helpers.load_level(self)
	var camera := SecurityCamera.of(_helpers.device_entity(CAMERA))
	var sensor := camera.sensor
	var config := sensor.config
	# Line of sight from the lens to each forecourt spot (a standing body there).
	var bodies: Array[Node3D] = []
	for feet in FORECOURT:
		var body := _body(feet, 1.8, [])
		bodies.append(body)
		(
			assert_bool(sensor.has_line_of_sight(sensor.eye_position(), body))
			. override_failure_message("no line of sight to %s" % feet)
			. is_true()
		)
	# Over one sweep cycle: how long each spot is in focus, and the longest stretch with none in focus.
	var seen: Array[int] = []
	seen.resize(FORECOURT.size())
	seen.fill(0)
	var gap := 0
	var longest := 0
	for frame in roundi(CYCLE * 60.0):
		await _helpers.frames(1)
		var any := false
		for i in FORECOURT.size():
			var point := bodies[i].global_position + Vector3.UP * 0.9
			var eye := sensor.eye_position()
			var angle := VisionRules.angle_off(sensor.facing(), eye, point)
			if VisionRules.zone_factor(angle, VisionRules.flat_distance(eye, point), config) > 0.0:
				seen[i] += 1
				any = true
		gap = 0 if any else gap + 1
		longest = maxi(longest, gap)
	var report := (
		"seen (s) %s, longest window %.1f s" % [seen.map(func(f: int) -> float: return f / 60.0), longest / 60.0]
	)
	print("roof camera: ", report)
	for i in FORECOURT.size():
		assert_float(seen[i] / 60.0).override_failure_message(report).is_greater(2.0)
	assert_float(longest / 60.0).override_failure_message(report).is_greater(MIN_WINDOW)


func test_a_lit_intruder_in_the_forecourt_and_an_upright_body_in_a_beam_ring_both_controllers() -> void:
	await _helpers.load_level(self)
	# A standing intruder in the forecourt, lit by the roof lamp: the camera finds it on its sweep.
	var intruder := _body(FORECOURT[1], 1.8, [&"actor.player"])
	assert_bool(await _helpers.wait_for(&"camera.detected", CYCLE + 2.0)).is_true()
	var detected := EventLog.find(&"camera.detected")[0]
	assert_str(String(detected.data["camera"])).is_equal(CAMERA)
	assert_int(int(detected.data["controllers"])).is_equal(2)
	assert_bool(await _helpers.wait_for(&"alarm.raised", 2.0)).is_true()
	intruder.free()

	# A crouched body (0.95 m) under each beam passes; an upright one (1.8 m) trips it.
	for laser_name: String in LASERS:
		var laser := LaserArray.of(_helpers.device_entity(laser_name))
		var middle := (laser.beam_start(laser.beams[0]) + laser.beam_end(laser.beams[0])) * 0.5
		var feet := Vector3(middle.x, ROOF, middle.z)
		EventLog.clear()
		var crouched := _body(feet, 0.95, [&"actor.player"])
		await _helpers.seconds(0.5)
		assert_array(EventLog.find(&"laser.tripped")).override_failure_message(laser_name + " crouched").is_empty()
		crouched.free()
		var upright := _body(feet, 1.8, [&"actor.player"])
		assert_bool(await _helpers.wait_for(&"laser.tripped", 0.5)).override_failure_message(laser_name).is_true()
		var tripped := EventLog.find(&"laser.tripped")[0]
		assert_str(String(tripped.data["laser"])).is_equal(laser_name)
		assert_int(int(tripped.data["controllers"])).is_equal(2)
		upright.free()
		await _helpers.seconds(1.5)


func test_breaker_a_switches_the_roof_off_and_the_console_disables_it() -> void:
	await _helpers.load_level(self)
	var console := _helpers.console()
	var lamp := _helpers.level.get_node(LAMP)
	var breaker := _helpers.device_entity("BreakerA").get_node("CircuitBreaker") as CircuitBreaker
	breaker.use(null)
	await _helpers.frames(2)
	for laser_name: String in LASERS:
		var laser := LaserArray.of(_helpers.device_entity(laser_name))
		assert_bool(laser.is_watching()).override_failure_message(laser_name + " still on").is_false()
		assert_bool(laser.beams[0].ray_visible()).is_false()
	assert_bool(Powered.of(lamp).on).is_false()
	assert_float(_measure(FORECOURT[1])).is_less(DARK)
	var rows := {}
	for row in console.devices():
		rows[String(row.device.entity.name)] = row.online
	for device_name: String in LASERS + [CAMERA]:
		assert_bool(rows[device_name]).override_failure_message(device_name + " online").is_false()
	breaker.use(null)
	await _helpers.frames(2)
	assert_float(_measure(FORECOURT[1])).is_greater_equal(LIT)

	# With the power back the console reaches them and disables them.
	assert_bool(console.log_in("dmarsh", "harbor77")).is_true()
	for device_name: String in LASERS + [CAMERA]:
		(
			assert_bool(console.send(Device.DISABLE, _helpers.device(device_name)))
			. override_failure_message(device_name)
			. is_true()
		)
	await _helpers.frames(3)
	for laser_name: String in LASERS:
		assert_bool(LaserArray.of(_helpers.device_entity(laser_name)).is_watching()).is_false()
	assert_bool(SecurityCamera.of(_helpers.device_entity(CAMERA)).is_watching()).is_false()


# The first world hit (layer 1) from `from` to `to`, ignoring `exclude`; {} when there is none.
func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, exclude: Array[RID]) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, PhysicsLayers.WORLD, exclude)
	return space.intersect_ray(query)


# A standing (or crouched: `height` 0.95) body at `feet` on the actors layer, with Tags `tags` and a
# LightExposure: the light it reads is the level's.
func _body(feet: Vector3, height: float, tags: Array[StringName]) -> Node3D:
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = PhysicsLayers.ACTORS
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = height
	shape.shape = capsule
	shape.position.y = height * 0.5
	body.add_child(shape)
	var tag_node := Tags.new()
	tag_node.name = "Tags"
	var all_tags := tags.duplicate()
	if height < 1.0:
		all_tags.append(&"stance.crouch")
	tag_node.initial_tags = all_tags
	body.add_child(tag_node)
	body.add_child(LightExposure.new())
	_helpers.level.add_child(body)
	body.global_position = feet
	return body


# The light level a standing body reads at `feet`.
func _measure(feet: Vector3) -> float:
	var body := _body(feet, 1.8, [])
	var level := LightExposure.of(body).update_now() if LightExposure.of(body) != null else -1.0
	body.free()
	return level
