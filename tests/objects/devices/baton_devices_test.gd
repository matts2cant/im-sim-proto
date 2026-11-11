extends GdUnitTestSuite
## Integration: the player's baton against every device and lamp scene, through the real melee path
## (belt key, `fire` action, WeaponHolder sweep, CONTACT damage, Breakable). Each scene is mounted on
## a bare wall at a height it has in the levels; the player stands on the floor in front of it (behind
## the turret), aims at its Breakable and swings until it breaks. Every swing must hit the device
## (reach) and the hits to break must fall in the row's range (security.md "Breaking devices").

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Weapons := preload("res://tests/items/weapons/weapon_test_helpers.gd")
const FIXTURE := "res://tests/objects/devices/fixtures/baton_wall.tscn"
## The wall's face (the fixture's wall is 0.4 m thick, centred at z -2.2).
const WALL_Z := -2.0
const MAX_SWINGS := 30
const BATON_SLOT := 2

## name, scene, device origin (x is replaced), yaw, player feet z, fewest hits, most hits.
## Heights: camera 2.6 m (security wing), siren origin 3.2 m (the hub's highest, bottom 3.0 m),
## panel devices at their wall heights, the turret on the floor facing away (+Z) from the player.
const ROWS: Array = [
	["camera", "res://objects/camera/security_camera.tscn", Vector3(0, 2.6, WALL_Z), 0.0, -1.3, 1, 3],
	["laser_array", "res://objects/laser/laser_array.tscn", Vector3(0, 1.3, WALL_Z), 0.0, -1.0, 1, 3],
	["siren", "res://objects/alarm/siren.tscn", Vector3(0, 3.2, WALL_Z), 0.0, -1.4, 1, 3],
	["alarm_controller", "res://objects/alarm/alarm_controller.tscn", Vector3(0, 1.5, WALL_Z), 0.0, -1.0, 1, 3],
	["panic_button", "res://objects/alarm/panic_button.tscn", Vector3(0, 1.3, WALL_Z), 0.0, -1.0, 1, 3],
	["radio_base_station", "res://objects/alarm/radio_base_station.tscn", Vector3(0, 1.2, WALL_Z), 0.0, -1.0, 1, 3],
	["network_switch", "res://objects/devices/network_switch.tscn", Vector3(0, 1.5, WALL_Z), 0.0, -1.0, 1, 3],
	["computer", "res://objects/computer/computer.tscn", Vector3(0, 1.45, WALL_Z), 0.0, -1.0, 1, 3],
	["turret", "res://objects/turret/turret.tscn", Vector3(0, 0, 1.0), 0.0, -0.1, 5, 8],
	["wall_lamp", "res://objects/light_fixture/wall_lamp.tscn", Vector3(0, 2.4, WALL_Z), 0.0, -1.2, 1, 3],
	["ceiling_lamp", "res://objects/light_fixture/ceiling_lamp.tscn", Vector3(0, 3.0, -1.0), 0.0, -0.4, 1, 3],
	["flood_lamp", "res://objects/light_fixture/flood_lamp.tscn", Vector3(0, 2.6, -1.8), PI, -1.0, 1, 3],
]

var _driver: PlayerDriver
var _weapons: Weapons


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	StimulusSystem.clear()


func test_baton_breaks_every_device_within_its_target_hits() -> void:
	await _load()
	var devices := _driver.runner.find_child("Devices") as Node3D
	var report: Array[String] = []
	var failures: Array[String] = []
	for index in ROWS.size():
		var row: Array = ROWS[index]
		var x := -15.0 + index * 2.5
		var origin: Vector3 = row[2]
		origin.x = x
		var entity := (load(row[1] as String) as PackedScene).instantiate() as Node3D
		devices.add_child(entity)
		entity.global_transform = Transform3D(Basis(Vector3.UP, row[3] as float), origin)
		await _driver.frames(2)
		var result := await _swing_until_broken(entity, Vector3(x, 0, row[4] as float))
		var hits: int = result["hits"]
		report.append(
			(
				"%s: %d hits (%s per hit), every swing hit: %s"
				% [row[0], hits, str(result["per_hit"]), str(result["all_hit"])]
			)
		)
		if not result["broken"] or hits < (row[5] as int) or hits > (row[6] as int) or not result["all_hit"]:
			failures.append("%s: %s" % [row[0], str(result)])
		if is_instance_valid(entity):
			entity.queue_free()
		await _driver.frames(2)
	print("Baton hits to break:\n  " + "\n  ".join(report))
	assert_array(failures).is_empty()


func test_broken_device_is_tagged_and_logged_like_a_shot_one() -> void:
	await _load()
	var devices := _driver.runner.find_child("Devices") as Node3D
	var camera := (load(ROWS[0][1] as String) as PackedScene).instantiate() as Node3D
	devices.add_child(camera)
	camera.global_position = Vector3(0, 2.6, WALL_Z)
	await _driver.frames(2)

	var result := await _swing_until_broken(camera, Vector3(0, 0, -1.3))

	assert_bool(result["broken"] as bool).is_true()
	assert_bool(Device.of(camera).broken).is_true()
	assert_bool((camera.get_node("Tags") as Tags).has(Device.BROKEN)).is_true()
	assert_bool(Device.of(camera).is_up()).is_false()
	var states := EventLog.find(&"device.state")
	assert_bool(states.any(func(entry: EventLogEntry) -> bool: return entry.data["broken"] == true)).is_true()
	assert_array(EventLog.find(&"object.damaged")).is_not_empty()


func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(FIXTURE))
	_weapons = Weapons.new(_driver)
	await _driver.settle()
	await _weapons.equip(BATON_SLOT)


# Aims the player standing at `feet` at the entity's Breakable and swings until it breaks (or
# MAX_SWINGS). Returns hits (swings until broken), broken, all_hit (every swing hit the entity) and
# per_hit (the object.damaged amounts of the first swing).
func _swing_until_broken(entity: Node3D, feet: Vector3) -> Dictionary:
	var breakable := Breakable.of(entity)
	var target := breakable.global_position
	var entity_name := String(entity.name)
	await _weapons.aim_at(feet, target)
	var swings := 0
	var all_hit := true
	var per_hit: Array[float] = []
	while swings < MAX_SWINGS and not _is_broken(entity, breakable):
		var swung_before := EventLog.find(&"weapon.swung").size()
		await _driver.hold(&"fire", 2)
		await _wait_ready()
		swings += 1
		var swung := EventLog.find(&"weapon.swung")
		if swung.size() <= swung_before or String(swung[-1].data["hit"]) != entity_name:
			all_hit = false
			break
		if swings == 1:
			for entry in EventLog.find(&"object.damaged"):
				per_hit.append(float(entry.data["amount"]))
	return {"hits": swings, "broken": _is_broken(entity, breakable), "all_hit": all_hit, "per_hit": per_hit}


# Until the swing's cooldown is over (and its CONTACT stimuli delivered), at most 2 s.
func _wait_ready() -> void:
	await _driver.frames(3)
	for frame in 120:
		var state := _driver.player.weapons.state()
		if state == null or state.cooldown <= 0.0:
			break
		await _driver.frames(1)


# Lamps free themselves when they break: the arguments may be freed objects (untyped on purpose).
static func _is_broken(entity: Variant, breakable: Variant) -> bool:
	if not is_instance_valid(entity) or (entity as Node).is_queued_for_deletion():
		return true
	var component := breakable as Breakable
	return component.is_broken or component.health() <= 0.0
