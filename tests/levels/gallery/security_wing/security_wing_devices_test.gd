extends GdUnitTestSuite
## Gallery room 5 (security wing) on its own: the security devices. The terminal reaches the camera,
## turret, alarm controller, both sirens, the panic button, the radio base station and the vault door
## through the network switch; with breaker B (the switch's circuit) off it reaches nothing and lists
## nothing, and the fail-secure vault door stays locked; breaker A off unlocks the fail-safe D4. The
## closed vault door blocks the turret's line of sight to the corridor and the entry hall. The camera
## covers the corridor (within 15 m and its sweep); the corridor centre line is lit (> 0.5) and both
## alcoves are dark (< 0.1). Room-local coordinates (origin on the hub wall's outer face, +Z south).

const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const ROOM_SCENE: PackedScene = preload("res://levels/gallery/security_wing/security_wing.tscn")
const NETWORK: Array[String] = [
	"Devices/Camera",
	"Devices/Turret",
	"Devices/Controller",
	"Devices/SirenHall",
	"Devices/SirenCorridor",
	"Devices/PanicButton",
	"Devices/BaseStation",
	"Doors/VaultDoor",
]
## Corridor centre line (x 9), from the hall end to the guard post, and between the alcoves.
const CORRIDOR_LINE: Array[Vector3] = [
	Vector3(9, 0, 7.5), Vector3(9, 0, 10.3), Vector3(9, 0, 12.6), Vector3(9, 0, 14.9), Vector3(9, 0, 16.4)
]
## Alcove floors, centre and the back half (where a player crouches).
const ALCOVES: Array[Vector3] = [
	Vector3(6.25, 0, 10.3), Vector3(5.9, 0, 10.3), Vector3(6.25, 0, 14.9), Vector3(5.9, 0, 14.9)
]
const CAMERA_RANGE := 15.0
## Focus half-angle 25 degrees plus the sweep's 40.
const CAMERA_REACH_DEG := 65.0

var _room: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_room = auto_free(ROOM_SCENE.instantiate())
	# Far from the origin so other suites' leftovers neither light nor block anything here.
	_room.position = Vector3(300, 0, -300)
	add_child(_room)
	await KitGeometry.settle(get_tree(), 5)


func after_test() -> void:
	StimulusSystem.clear()


func _device(path: String) -> Device:
	return Device.of(_room.get_node(path))


func _terminal() -> Terminal:
	return Terminal.of(_room.get_node("Devices/Terminal"))


func _breaker(breaker_name: String) -> CircuitBreaker:
	return _room.get_node("Devices/" + breaker_name + "/CircuitBreaker") as CircuitBreaker


func _listed() -> Array[String]:
	var names: Array[String] = []
	for row in _terminal().listing():
		names.append(String(row.device.entity.name))
	return names


func test_terminal_reaches_the_security_devices_through_the_switch() -> void:
	var terminal := _device("Devices/Terminal")
	for path in NETWORK:
		assert_bool(terminal.reaches(_room.get_node(path))).override_failure_message(path).is_true()
	assert_array(_listed()).contains_exactly_in_any_order(
		["Camera", "Turret", "Controller", "SirenHall", "SirenCorridor", "VaultDoor"]
	)
	# The controller rings both sirens and dispatches through the base station; the camera and the
	# panic button report to it.
	var controller := _device("Devices/Controller")
	assert_array(controller.reached(Device.RING)).has_size(2)
	assert_array(controller.reached(Device.BROADCAST)).has_size(1)
	assert_array(_device("Devices/Camera").reached(Device.INCIDENT)).contains_exactly([controller])
	assert_array(_device("Devices/PanicButton").reached(Device.INCIDENT)).contains_exactly([controller])
	# Every row offers its commands: the turret Disable and its presets, the vault door Open.
	for row in _terminal().listing():
		if row.device.entity.name == &"Turret":
			assert_array(row.commands).contains([Device.DISABLE, Device.TARGET_GUARDS])
		if row.device.entity.name == &"VaultDoor":
			assert_array(row.commands).contains([Device.OPEN])


func test_breaker_b_off_cuts_the_chain_and_keeps_the_vault_locked() -> void:
	var switch_power := Powered.of(_room.get_node("Devices/Switch"))
	assert_str(String(switch_power.circuit)).is_equal(String(_breaker("BreakerB").circuit))

	_breaker("BreakerB").set_closed(false)

	assert_bool(switch_power.on).is_false()
	var terminal := _device("Devices/Terminal")
	assert_bool(terminal.is_up()).is_true()
	for path in NETWORK:
		assert_bool(terminal.reaches(_room.get_node(path))).override_failure_message(path).is_false()
	assert_array(_listed()).is_empty()
	assert_array(_device("Devices/Camera").reached(Device.INCIDENT)).is_empty()
	# Fail-secure: no power, still locked (and no remote command gets through).
	var vault := Door.of(_room.get_node("Doors/VaultDoor"))
	assert_bool(vault.is_locked()).is_true()
	assert_bool(_device("Doors/VaultDoor").is_up()).is_false()
	# The fail-safe D4 is on the other breaker and stays locked.
	assert_bool(Door.of(_room.get_node("Doors/D4Electronic")).is_locked()).is_true()

	_breaker("BreakerB").set_closed(true)

	assert_array(_listed()).has_size(6)


func test_shooting_the_switch_cuts_the_chain_too() -> void:
	var switch_entity := _room.get_node("Devices/Switch")
	# Shot: ballistic damage at the switch (a pistol round is 25), as the weapon path delivers it.
	StimulusSystem.emit(Stimulus.make_contact(&"damage.ballistic", 200.0, switch_entity, _room))
	await KitGeometry.settle(get_tree(), 3)

	assert_bool(Device.of(switch_entity).is_up()).is_false()
	assert_array(_listed()).is_empty()


func test_breaker_a_off_unlocks_d4_only() -> void:
	var d4 := Door.of(_room.get_node("Doors/D4Electronic"))
	assert_bool(d4.is_locked()).is_true()

	_breaker("BreakerA").set_closed(false)

	assert_bool(d4.is_locked()).is_false()
	assert_bool(Door.of(_room.get_node("Doors/VaultDoor")).is_locked()).is_true()
	assert_array(_listed()).has_size(6)


func test_closed_vault_door_blocks_the_turrets_line_of_sight() -> void:
	var eye := (_room.get_node("Devices/Turret").find_child("Eye", true, false) as Node3D).global_position
	var vault_door := _room.get_node("Doors/VaultDoor")
	# Corridor centre, the guard post's floor area and the entry hall in front of the corridor mouth.
	var targets: Array[Vector3] = [Vector3(9, 1.2, 12.6), Vector3(8.2, 1.2, 15), Vector3(9, 1.2, 4)]
	for target in targets:
		var hit := _world_ray(eye, _room.to_global(target))
		assert_object(hit.get("collider")).override_failure_message(str(target)).is_same(vault_door)
	# Open, the turret sees straight up the corridor: the door was what blocked it.
	Door.of(vault_door).open()
	await KitGeometry.settle(get_tree(), 50)
	assert_dict(_world_ray(eye, _room.to_global(Vector3(9, 1.2, 12.6)))).is_empty()
	# The turret faces the door's inside, within 3 m.
	var turret := _room.get_node("Devices/Turret") as Node3D
	assert_float(turret.global_basis.z.dot(Vector3.FORWARD)).is_greater(0.99)
	assert_float(turret.position.distance_to((vault_door as Node3D).position)).is_less(3.5)


func test_camera_covers_the_corridor() -> void:
	var camera := _room.get_node("Devices/Camera") as Node3D
	var eye := (camera.find_child("Eye", true, false) as Node3D).global_position
	var rest := camera.global_basis.z
	assert_float(eye.y - _room.global_position.y).is_between(2.3, 2.7)
	for spot in CORRIDOR_LINE:
		var chest := _room.to_global(spot + Vector3.UP * 1.0)
		var to := chest - eye
		var flat := Vector2(to.x, to.z)
		assert_float(flat.length()).override_failure_message(str(spot)).is_less(CAMERA_RANGE)
		var angle := rad_to_deg(Vector2(rest.x, rest.z).angle_to(flat))
		assert_float(absf(angle)).override_failure_message(str(spot)).is_less(CAMERA_REACH_DEG)
		assert_dict(_world_ray(eye, chest)).override_failure_message(str(spot)).is_empty()


func test_corridor_is_lit_and_the_alcoves_are_dark() -> void:
	var levels: Array[String] = []
	for spot in CORRIDOR_LINE:
		var level := LightExposure.of(_stand_in(spot)).update_now()
		levels.append("%s %.2f" % [spot, level])
		assert_float(level).override_failure_message("corridor %s: %.2f" % [spot, level]).is_greater(0.5)
	for spot in ALCOVES:
		var level := LightExposure.of(_stand_in(spot)).update_now()
		levels.append("%s %.2f" % [spot, level])
		assert_float(level).override_failure_message("alcove %s: %.2f" % [spot, level]).is_less(0.1)
	# The guard's post is lit, so the player can watch it react.
	var guard := _room.get_node("Guards/GuardBatonVault")
	var post := LightExposure.of(guard).update_now()
	levels.append("guard post %.2f" % post)
	assert_float(post).is_greater(0.5)
	# The vault in front of the turret is lit too, so it sees whoever opens the door.
	var vault := LightExposure.of(_stand_in(Vector3(9, 0, 19.5))).update_now()
	levels.append("vault %.2f" % vault)
	assert_float(vault).is_greater(0.5)
	print("security wing light levels: ", ", ".join(levels))


func _world_ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, PhysicsLayers.WORLD)
	return _room.get_world_3d().direct_space_state.intersect_ray(query)


# A static 1.8 m capsule with a real LightExposure (no tags: nobody looks at it) at room-local feet.
func _stand_in(feet: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = PhysicsLayers.ACTORS
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	body.add_child(shape)
	body.add_child(LightExposure.new())
	_room.add_child(body)
	body.position = feet
	return body
