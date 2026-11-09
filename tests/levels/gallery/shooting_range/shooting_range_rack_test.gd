extends GdUnitTestSuite
## The shooting range's weapons rack (ADR 0085): a 1.0 m wooden table (2.4 x 1.0 m) against the
## south wall west of the door holding the shotgun, sniper rifle, assault rifle, their ammo and a
## second silencer, with signs for the scope (RMB toggles), full-auto (hold LMB) and fitting the
## silencer. It stays clear of the door and the walk to the counter gap. In the hub with the player:
## the whole rack fits in the inventory next to the hub's starting kit, and scoped and still the
## sniper rifle's first shot from the firing line hits the 40 m dummy's torso.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const ROOM_SCENE: PackedScene = preload("res://levels/gallery/shooting_range/shooting_range_room.tscn")
const HUB := "res://levels/hub/hub.tscn"
const RACK: Dictionary[StringName, int] = {
	&"shotgun": 1,
	&"sniper_rifle": 1,
	&"assault_rifle": 1,
	&"shotgun_shells": 24,
	&"sniper_rounds": 15,
	&"rifle_rounds": 90,
	&"silencer": 1,
}
const SIGNS: Dictionary[String, String] = {
	"Rack": "Weapons rack",
	"RackScope": "RMB: sniper scope on / off",
	"RackFullAuto": "Hold LMB: rifle full-auto",
	"RackSilencer": "Silencer: I, drag onto a weapon",
}
## Room-local: the door opening (x -1..1 in the south wall z -4), the counter gap (x -3.5..-2.3 at
## the counter's back z -8).
const DOOR_X := Vector2(-1.0, 1.0)
const COUNTER_BACK_Z := -8.0
const PLAYER_DIAMETER := 0.7
## Lane 4 on the firing line (feet), room-local.
const LANE_4 := Vector3(9.25, 0, -7.45)

var _room: Node3D


func before_test() -> void:
	_room = auto_free(ROOM_SCENE.instantiate())
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_rack_holds_the_weapons_ammo_and_a_silencer() -> void:
	var table := _room.get_node("Rack/Table") as Ledge
	assert_float(table.height).is_equal(1.0)
	assert_str(table.surface).is_equal("wood")
	var counts: Dictionary[StringName, int] = {}
	var footprints: Array[Rect2] = []
	for child: Node in _room.get_node("Rack").get_children():
		var pickup := ItemPickup.of(child)
		if pickup == null:
			continue
		counts[pickup.item.id] = counts.get(pickup.item.id, 0) + pickup.count
		var body := child as RigidBody3D
		var footprint := _footprint(body)
		# Resting on the table top, inside its footprint, not touching a neighbour.
		var size := ((body.get_node("Collision") as CollisionShape3D).shape as BoxShape3D).size
		assert_float(body.position.y - size.y * 0.5).override_failure_message(child.name).is_equal_approx(1.0, 0.001)
		assert_bool(_table_rect(table).encloses(footprint)).override_failure_message(child.name).is_true()
		for other in footprints:
			assert_bool(footprint.intersects(other)).override_failure_message(child.name).is_false()
		footprints.append(footprint)
	assert_dict(counts).is_equal(RACK)


func test_rack_keeps_clear_of_the_door_and_the_walk_to_the_counter_gap() -> void:
	var rect := _table_rect(_room.get_node("Rack/Table") as Ledge)
	var hall := _room.get_node("Shell/Hall") as Room
	var west_wall := hall.position.x - hall.size.x * 0.5
	assert_float(rect.position.x).is_greater_equal(west_wall)
	# Beside the door, never in front of its opening.
	assert_float(rect.end.x).is_less(DOOR_X.x)
	# Room to walk between the rack and the counter (gap, surface to surface).
	assert_float(rect.position.y - COUNTER_BACK_Z).is_greater(PLAYER_DIAMETER * 2.0)
	# The medkit table is on the other side of the door.
	assert_float((_room.get_node("Medkits/Table") as Ledge).position.x).is_greater(DOOR_X.y)


func test_rack_signs() -> void:
	for name: String in SIGNS:
		var sign := _room.get_node_or_null("Labels/" + name) as Sign
		assert_object(sign).override_failure_message(name).is_not_null()
		assert_str(sign.text).is_equal(SIGNS[name])


func test_the_whole_rack_fits_next_to_the_hub_kit() -> void:
	var driver := PlayerDriver.new(scene_runner(HUB))
	var player := driver.player
	var room := driver.runner.find_child("ShootingRangeRoom") as Node3D
	await driver.settle()
	var hub_kit := driver.runner.find_child("Loadout") as Node3D
	for source: Node3D in [hub_kit, room.get_node("Rack") as Node3D]:
		for child: Node in source.get_children():
			var pickup := ItemPickup.of(child)
			if pickup != null:
				assert_bool(player.inventory.pick_up(pickup)).override_failure_message(child.name).is_true()
				assert_int(pickup.count).override_failure_message(child.name).is_equal(0)
	assert_array(EventLog.find(&"item.pickup_refused")).is_empty()


func test_scoped_sniper_first_shot_hits_the_40_m_dummy_torso() -> void:
	var driver := PlayerDriver.new(scene_runner(HUB))
	var player := driver.player
	var room := driver.runner.find_child("ShootingRangeRoom") as Node3D
	await driver.settle()
	var rack := room.get_node("Rack")
	player.inventory.pick_up(ItemPickup.of(rack.get_node("SniperRifle")))
	player.inventory.pick_up(ItemPickup.of(rack.get_node("SniperRounds")))
	var dummy := room.get_node("Lanes/Dummy40m") as TrainingDummy
	var torso := dummy.hitboxes.box(&"torso").global_position
	player.load_state(Objects.aiming_state(player, room.to_global(LANE_4), torso))
	await driver.frames(5)
	await driver.hold(&"belt_1", 2)
	await driver.hold(&"alt_fire", 2)
	# Scoped and still for 1.5 s: the cone settles.
	await driver.frames(90)
	assert_bool(player.weapons.scope.scoped).is_true()
	assert_float(player.weapons.aim.spread).is_less(0.25)
	player.weapons.seed_rng(4242)
	EventLog.clear()

	await driver.hold(&"fire", 2)
	await driver.frames(4)

	var fired := EventLog.find(&"weapon.fired")
	assert_array(fired).has_size(1)
	assert_str(fired[0].data["hit"]).is_equal(String(dummy.hitboxes.box(&"torso").name))
	assert_bool(dummy.body.is_dead()).is_true()


# Room-local x / z rectangle of a Ledge (unrotated: lip at its origin, block towards -Z).
static func _table_rect(table: Ledge) -> Rect2:
	return Rect2(table.position.x - table.width * 0.5, table.position.z - table.depth, table.width, table.depth)


# Room-local x / z rectangle of a pickup's collision box (turned by its yaw).
static func _footprint(body: RigidBody3D) -> Rect2:
	var size := ((body.get_node("Collision") as CollisionShape3D).shape as BoxShape3D).size
	var half_x := body.basis.x.abs() * size.x * 0.5 + body.basis.z.abs() * size.z * 0.5
	return Rect2(body.position.x - half_x.x, body.position.z - half_x.z, half_x.x * 2.0, half_x.z * 2.0)
