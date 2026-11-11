extends GdUnitTestSuite
## Warehouse doors, locks and keys (design/levels/mission-warehouse.md "Doors, locks and keys", ADR
## 0090): every doorway of the layout holds its door with the intended locks; no key is locked
## behind its own lock (the key graph has no deadlock; forced entries such as the weak wall's breach
## panel, placed by the people population, are left out); the back gate opens from inside without a
## key and needs a lockpick from the river side; no two CSG roots of the populated level z-fight;
## wall devices and door wall boxes keep clear of doorways, door sweeps and signs (M9h).

const Helpers := preload("res://tests/levels/mission/warehouse_security_helpers.gd")
const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const HardwareChecks := preload("res://tests/objects/door/door_hardware_checks.gd")
const WallDeviceChecks := preload("res://tests/levels/wall_device_checks.gd")

## Doorway -> [locked at the start, lock components, extra tags, free side (Lock.NO_SIDE / FRONT /
## BACK), breakable]. The intended locks of the layout's doorway table.
const EXPECTED: Dictionary[String, Array] = {
	"FrontGate": [false, ["ElectronicLock"], ["door.fail_secure"], Lock.NO_SIDE, false],
	"BoothDoor": [false, [], [], Lock.NO_SIDE, false],
	"BackGate": [true, ["MechanicalLock"], [], Lock.BACK, false],
	"SideDoor": [true, ["KeypadLock"], [], Lock.FRONT, false],
	"RollerDoor1": [false, [], [], Lock.NO_SIDE, false],
	"RollerDoor2": [false, [], [], Lock.NO_SIDE, false],
	"AnnexDoor": [true, ["MechanicalLock"], [], Lock.NO_SIDE, false],
	"AnnexRoofDoor": [true, ["MechanicalLock"], [], Lock.BACK, false],
	"FireEscapeDoor": [true, ["MechanicalLock"], [], Lock.BACK, false],
	"OfficeEntrance": [false, [], [], Lock.NO_SIDE, false],
	"BreakRoomHall": [false, [], [], Lock.NO_SIDE, false],
	"BreakRoomCorridor": [false, [], [], Lock.NO_SIDE, false],
	"SecurityDoor": [true, ["KeycardLock", "ElectronicLock"], ["door.fail_secure"], Lock.BACK, false],
	"StairsGround": [false, [], [], Lock.NO_SIDE, false],
	"LockerRoom": [false, [], [], Lock.NO_SIDE, false],
	"BridgeDoor": [true, ["ElectronicLock"], ["door.fail_safe"], Lock.FRONT, false],
	"ManagerDoor": [true, ["KeypadLock"], [], Lock.BACK, false],
	"VaultDoor": [true, ["KeycardLock", "ElectronicLock"], ["door.fail_secure"], Lock.BACK, false],
	"StairsUpper": [false, [], [], Lock.NO_SIDE, false],
	"CatwalkStairsDoor": [false, [], [], Lock.NO_SIDE, false],
	"OfficeTwo": [true, ["MechanicalLock"], [], Lock.FRONT, false],
	"BoilerStore": [false, [], [], Lock.NO_SIDE, false],
	"BoilerTunnel": [false, [], [], Lock.NO_SIDE, false],
	"TunnelGate": [true, ["MechanicalLock"], [], Lock.FRONT, false],
}
## Doorways closed by the people population instead of a door (M9d): doorway -> its closing node.
const CLOSED_BY_PEOPLE: Dictionary[String, String] = {"WeakWall": "Population/People/WeakWall/BreachPanel"}
## Doorways bigger than a 1.2 x 2.2 m door (width, height).
const BIG: Dictionary[String, Vector2] = {
	"FrontGate": Vector2(6, 3), "BackGate": Vector2(1.2, 3), "RollerDoor1": Vector2(4, 4), "RollerDoor2": Vector2(4, 4)
}

## Areas of the level, first match wins: name -> [x0, x1, z0, z1, y0, y1].
const AREAS: Array[Array] = [
	["manager_office", 8.25, 13.75, 0.25, 5.0, 4.0, 7.2],
	["vault", 14.0, 19.75, 0.25, 5.0, 4.0, 7.2],
	["upper_corridor", 8.25, 19.75, 5.25, 6.75, 4.0, 7.2],
	["second_office", 13.25, 19.75, 7.0, 14.75, 4.0, 7.2],
	["stairwell", 8.25, 13.0, 7.0, 14.75, -0.5, 7.2],
	["break_room", 8.25, 13.75, 0.25, 5.0, -0.5, 4.0],
	["security_room", 14.0, 19.75, 0.25, 5.0, -0.5, 4.0],
	["ground_corridor", 8.25, 19.75, 5.25, 6.75, -0.5, 4.0],
	["locker_room", 13.25, 19.75, 7.0, 14.75, -0.5, 4.0],
	["boiler_room", 8.0, 19.5, -9.0, -0.5, -5.0, -0.9],
	["store", 8.0, 19.5, 0.0, 14.75, -5.0, -0.9],
	["tunnel", 19.5, 36.8, -6.0, -4.0, -5.0, -0.5],
	["ditch", 36.8, 41.3, -27.0, 22.3, -3.0, -0.2],
	["annex_roof", -26.5, -20.5, 1.0, 13.0, 4.5, 8.0],
	["fire_escape", 20.5, 23.0, 4.8, 7.2, 4.0, 5.5],
	["catwalks", -20.0, 20.0, -10.0, 15.0, 3.5, 7.0],
	["hall", -20.0, 20.0, -10.0, 15.0, -0.5, 3.5],
	["annex", -26.0, -20.5, 1.5, 12.5, -0.5, 4.25],
	["booth", -12.5, -9.5, -24.0, -20.0, -0.5, 2.6],
	["yard", -35.0, 35.0, -25.0, 25.0, -0.5, 3.0],
	["riverside", -35.0, 60.0, 25.0, 40.0, -0.5, 3.0],
	["road", -45.0, 60.0, -40.0, -25.0, -0.5, 3.0],
]
## Ways between areas without a door (climbs, drops, ducts, open doorways): [from, to, both ways].
const FREE_WAYS: Array[Array] = [
	["road", "yard", true],  # over the fence from the outside container
	["road", "ditch", true],  # ditch ramp
	["ditch", "yard", true],  # culvert, drain chamber, step
	["yard", "tunnel", true],  # drain chamber doorway into the tunnel
	["road", "riverside", true],  # east verge
	["yard", "annex_roof", true],  # pallets, container, crate
	["annex_roof", "roof", true],  # annex roof stair
	["yard", "fire_escape", true],  # bottom landing mantle
	["fire_escape", "roof", true],
	["roof", "catwalks", false],  # skylight drop (one way)
	["roof", "catwalks", true],  # duct A
	["roof", "manager_office", true],  # duct B
	["hall", "catwalks", true],  # hall stairs
	["hall", "boiler_room", true],  # hatch stair
	["stairwell", "store", true],  # service stair
	["boiler_room", "security_room", true],  # duct C
]

var _helpers: Helpers


# One populated level for the suite (design/tech/testing.md "Writing fast tests"): the tests read it;
# the back gate test, last, opens and unlocks the back gate.
func before() -> void:
	_helpers = Helpers.new()
	await _helpers.load_level(self, false, true)


func after() -> void:
	_helpers.teardown()


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	StimulusSystem.clear()


func test_every_doorway_holds_its_door_and_intended_locks() -> void:
	var markers := _helpers.level.get_node("LayoutMarkers/Doorways").get_children()
	assert_int(markers.size()).is_equal(EXPECTED.size() + CLOSED_BY_PEOPLE.size())
	var problems: PackedStringArray = []
	for marker: Marker3D in markers:
		var key := String(marker.name)
		if CLOSED_BY_PEOPLE.has(key):
			var panel := _helpers.level.get_node_or_null(CLOSED_BY_PEOPLE[key]) as Node3D
			if panel == null or panel.global_position.distance_to(marker.global_position) > 0.01:
				problems.append("%s: not closed by %s" % [key, CLOSED_BY_PEOPLE[key]])
			if _helpers.level.has_node("%s/Doors/%s" % [Helpers.SECURITY, key]):
				problems.append("%s: a door as well" % key)
			continue
		var entity := _helpers.level.get_node_or_null("%s/Doors/%s" % [Helpers.SECURITY, key]) as StaticBody3D
		if entity == null:
			problems.append("%s: no door" % key)
			continue
		var door := Door.of(entity)
		var spec: Array = EXPECTED[key]
		if entity.global_position.distance_to(marker.global_position) > 0.01:
			problems.append("%s: not on its marker" % key)
		# The door's X runs along the wall (the marker's X), either way round.
		if absf(entity.global_basis.x.dot(marker.global_basis.x)) < 0.99:
			problems.append("%s: not along its wall" % key)
		if door.is_locked() != bool(spec[0]):
			problems.append("%s: locked %s" % [key, door.is_locked()])
		var kinds: Array[String] = []
		var sides: Array[int] = []
		for lock in Lock.locks_of(entity):
			kinds.append(String((lock.get_script() as Script).get_global_name()))
			if lock.free_side != Lock.NO_SIDE:
				sides.append(lock.free_side)
		if kinds != Array(spec[1], TYPE_STRING, "", null):
			problems.append("%s: locks %s" % [key, kinds])
		for tag: String in spec[2]:
			if not ActorState.has(entity, StringName(tag)):
				problems.append("%s: missing tag %s" % [key, tag])
		var free: int = spec[3]
		if (free == Lock.NO_SIDE and not sides.is_empty()) or (free != Lock.NO_SIDE and not sides.has(free)):
			problems.append("%s: free sides %s" % [key, sides])
		if (Breakable.of(entity) != null) != bool(spec[4]):
			problems.append("%s: breakable %s" % [key, Breakable.of(entity) != null])
		var doorway: Vector2 = BIG.get(key, Vector2(1.2, 2.2))
		if not door.settings.doorway.is_equal_approx(doorway):
			problems.append("%s: doorway %s" % [key, door.settings.doorway])
	assert_array(problems).is_empty()


func test_every_key_is_reachable_without_its_own_lock() -> void:
	var level := _helpers.level
	var doors: Dictionary[String, Dictionary] = {}
	var areas: Dictionary[String, bool] = {}
	for each in AREAS:
		areas[each[0]] = true
	areas["roof"] = true
	for door in _helpers.doors():
		var entity := door.entity
		var front := _area(entity.global_position + entity.global_basis.z + Vector3.UP * 0.5)
		var back := _area(entity.global_position - entity.global_basis.z + Vector3.UP * 0.5)
		assert_str(front).override_failure_message("%s front" % entity.name).is_not_empty()
		assert_str(back).override_failure_message("%s back" % entity.name).is_not_empty()
		doors[String(entity.name)] = {
			"door": door, "front": front, "back": back, "options": _key_options(level, door), "free": _free_side(entity)
		}
	# Everything is reachable from the road.
	var everything := _reach(doors, "")
	for area: String in areas:
		assert_bool(everything.has(area)).override_failure_message("unreachable: " + area).is_true()
	# Every locked door's key is reachable without passing that door.
	var deadlocks: PackedStringArray = []
	for key: String in doors:
		var spec := doors[key]
		var door := spec["door"] as Door
		if not door.is_locked() or Lock.locks_of(door.entity).is_empty():
			continue
		var reached := _reach(doors, key)
		if not _any_option(spec["options"], reached):
			deadlocks.append("%s: needs %s, reached %s" % [key, spec["options"], reached.keys()])
	assert_array(deadlocks).is_empty()


func test_signs_name_the_office_rooms_over_their_doors() -> void:
	# Sign -> [door, text]: over the doorway, on the side it names, facing away from the wall.
	var expected: Dictionary[String, Array] = {
		"OfficeEntranceBack": ["OfficeEntrance", "OFFICES"],
		"BridgeDoorBack": ["BridgeDoor", "OFFICES"],
		"SecurityDoorFront": ["SecurityDoor", "SECURITY"],
		"ManagerDoorFront": ["ManagerDoor", "MANAGER"],
		"VaultDoorFront": ["VaultDoor", "VAULT"],
	}
	for sign_name: String in expected:
		var label := _helpers.level.get_node("%s/Signs/%s" % [Helpers.SECURITY, sign_name]) as Label3D
		var door := _helpers.door_entity(String(expected[sign_name][0]))
		assert_str(label.text).is_equal(String(expected[sign_name][1]))
		var offset := label.global_position - door.global_position
		assert_float(offset.y).override_failure_message(sign_name).is_between(2.25, 2.7)
		assert_float(Vector2(offset.x, offset.z).length()).override_failure_message(sign_name).is_less(0.5)
		(
			assert_float(label.global_basis.z.dot(Vector3(offset.x, 0, offset.z)))
			. override_failure_message(sign_name)
			. is_greater(0.0)
		)


func test_the_populated_level_has_no_coplanar_faces_with_different_materials() -> void:
	assert_array(KitGeometry.coplanar_material_overlaps(_helpers.level)).is_empty()


func test_door_hardware_sits_flush_on_the_walls_beside_every_frame() -> void:
	# ADR 0098: every door's wall boxes (keypads, readers, status and control boxes) flush on a wall
	# surface on both faces, inside no wall and clear of the leaf's sweep, in the real level geometry
	# (gate posts, roller-door walls, short corridors' side walls); pin locks have their keyholes.
	var problems: PackedStringArray = []
	var boxes := 0
	for entity: Node in _helpers.level.get_node("%s/Doors" % Helpers.SECURITY).get_children():
		var door := Door.of(entity)
		problems.append_array(HardwareChecks.problems(door))
		boxes += door.hardware.controls(true).size()
		var keyholes := entity.get_node("HandleMesh").get_child_count()
		var picks := Lock.locks_of(entity).filter(func(lock: Lock) -> bool: return lock is MechanicalLock).size()
		if keyholes != picks * 2:
			problems.append("%s: %d keyholes for %d pin locks" % [entity.name, keyholes, picks])
	assert_array(problems).is_empty()
	# Keypads (side door, manager), readers (security, vault), status boxes (front gate, bridge door)
	# and the two roller doors' control boxes.
	assert_int(boxes).is_equal(8)


func test_wall_devices_keep_clear_of_doorways_door_sweeps_and_signs() -> void:
	# M9h: SirenOfficeGround hung in front of the office entrance (a red disc over the door leaf)
	# and CameraOffice over the upper corridor's FIRE EXIT sign.
	var level := _helpers.level
	assert_array(WallDeviceChecks.problems(level)).is_empty()
	# The check sees the security population: its devices, doors and signs.
	var devices := level.find_children("*", "", true, false).filter(func(node: Node) -> bool: return node is Device)
	assert_int(devices.size()).is_greater(30)
	# FIRE EXIT runs along z on the fire escape door's west face, 1 m long.
	var sign := level.get_node("%s/Signs/FireEscapeDoorBack" % Helpers.SECURITY) as Sign
	assert_float(WallDeviceChecks.sign_box(sign).size.z).is_greater(0.8)


func test_the_back_gate_opens_from_inside_and_needs_a_lockpick_outside() -> void:
	var gate := _helpers.door("BackGate")
	var inside := _helpers.stand_in("Inside", Vector3(7, 0, 23.5))
	var outside := _helpers.stand_in("Outside", Vector3(7, 0, 26.5))
	var lock := Lock.locks_of(gate.entity)[0] as MechanicalLock

	assert_str(gate.prompt(outside)).is_equal("Locked: lockpick")
	assert_bool(gate.use(outside)).is_false()
	assert_bool(lock.accepts_tool(&"lockpick")).is_true()
	assert_str(gate.prompt(inside)).is_equal("E: open")
	assert_bool(gate.use(inside)).is_true()
	assert_bool(gate.is_open()).is_true()
	await _helpers.seconds(1.0)
	gate.close(inside)
	await _helpers.seconds(1.0)
	# Still locked from the river side; picking it (the minigame's success) opens it.
	assert_bool(gate.is_open()).is_false()
	assert_bool(lock.complete_pick(outside)).is_true()
	assert_bool(gate.is_locked()).is_false()
	assert_bool(gate.is_open()).is_true()


# --- key graph ---------------------------------------------------------------------------------


# The area a point lies in ("" outside every area); above the hall and annex roofs: "roof".
func _area(point: Vector3) -> String:
	for each in AREAS:
		if (
			point.x >= each[1]
			and point.x <= each[2]
			and point.z >= each[3]
			and point.z <= each[4]
			and point.y >= each[5]
			and point.y <= each[6]
		):
			return each[0]
	if point.y >= 7.0:
		return "roof"
	return ""


# The free side's area of a door's locks ("" when none): "front" or "back".
func _free_side(entity: Node) -> String:
	for lock in Lock.locks_of(entity):
		if lock.free_side == Lock.FRONT:
			return "front"
		if lock.free_side == Lock.BACK:
			return "back"
	return ""


# Alternative sets of areas that open a door's locks (any one set, all of its areas reached).
func _key_options(level: Node, door: Door) -> Array[Array]:
	var options: Array[Array] = []
	for lock in Lock.locks_of(door.entity):
		if lock is KeypadLock:
			for pad in _readables_with((lock as KeypadLock).data.code_id):
				options.append([_area(pad.global_position)])
		elif lock is KeycardLock:
			for card in _keycards((lock as KeycardLock).access_id()):
				options.append([_area(card.global_position)])
		elif lock is MechanicalLock:
			# Lockpicks: placed by the population (the layout's marker in the basement store).
			options.append([_area((level.get_node("LayoutMarkers/Items/Lockpicks") as Node3D).global_position)])
		elif lock is ElectronicLock:
			var powered := Powered.of(door.entity)
			if (lock as ElectronicLock).is_fail_safe() and powered != null:
				for node in _all():
					var breaker := node as CircuitBreaker
					if breaker != null and breaker.circuit == powered.circuit:
						options.append([_area(breaker.entity.global_position)])
			for node in _all():
				var computer := node as Computer
				if computer != null and computer.device != null and computer.device.reaches(door.entity):
					for pad in _readables_with(computer.credentials_id):
						options.append([_area(computer.entity.global_position), _area(pad.global_position)])
	return options


func _readables_with(code_id: StringName) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for node in _all():
		if node is Readable and (node as Readable).codes.has(code_id):
			result.append(node.get_parent() as Node3D)
	return result


func _keycards(access_id: StringName) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for node in _all():
		if node is ItemPickup and str((node as ItemPickup).state.get("key_id", "")) == String(access_id):
			result.append(node.get_parent() as Node3D)
	return result


# Every node under the level.
func _all() -> Array[Node]:
	return _helpers.level.find_children("*", "", true, false)


func _any_option(options: Array, reached: Dictionary) -> bool:
	for option: Array in options:
		var all := true
		for area: String in option:
			all = all and reached.has(area)
		if all:
			return true
	return false


# Areas reached from the road with `excluded` never passed (doors open with their keys once those
# are reached, free sides let through one way, forced entries are never used).
func _reach(doors: Dictionary[String, Dictionary], excluded: String) -> Dictionary:
	var reached := {"road": true}
	var changed := true
	while changed:
		changed = false
		var ways: Array[Array] = FREE_WAYS.duplicate()
		for key: String in doors:
			if key == excluded:
				continue
			var spec := doors[key]
			var door := spec["door"] as Door
			var open := not door.is_locked() or _any_option(spec["options"], reached)
			if open:
				ways.append([spec["front"], spec["back"], true])
			elif spec["free"] == "front":
				ways.append([spec["front"], spec["back"], false])
			elif spec["free"] == "back":
				ways.append([spec["back"], spec["front"], false])
		for way in ways:
			if reached.has(way[0]) and not reached.has(way[1]):
				reached[way[1]] = true
				changed = true
			if way[2] and reached.has(way[1]) and not reached.has(way[0]):
				reached[way[0]] = true
				changed = true
	return reached
