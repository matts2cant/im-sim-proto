extends GdUnitTestSuite
## Integration in the real shooting range (inside the hub) with the player and its weapons: a pistol
## shot from the firing line hits the 10 m dummy's torso; the baton knocks the unaware melee dummy
## out from behind in one hit and the aware one in three; the blast lane barrel hurts a player on the
## 2 m line more than on the 3 m line and not at all on the 6 m line. The weapon RNG is seeded (Weapons.SEED).

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Weapons := preload("res://tests/items/weapons/weapon_test_helpers.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const HUB := "res://levels/hub/hub.tscn"
## Room-local feet positions (origin on the hub wall's outer face, -Z away from the hub).
const FIRING_LINE_LANE_2 := Vector3(4.25, 0, -7.45)
const BEHIND_UNAWARE := Vector3(18.6, 0, -5.6)
const BEHIND_AWARE := Vector3(18.2, 0, -5.6)
const BLAST_BARREL := Vector3(-1.5, 0.45, -20)
## A swing's cycle is 0.6 s (36 frames): wait a little longer between swings.
const SWING_FRAMES := 40

var _driver: PlayerDriver
var _weapons: Weapons
var _room: Node3D


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_pistol_from_the_firing_line_hits_the_10_m_dummy_torso() -> void:
	await _load_hub()
	var dummy := _room.get_node("Lanes/Dummy10m") as TrainingDummy
	await _weapons.equip(1)
	await _weapons.aim_at(_room.to_global(FIRING_LINE_LANE_2), Weapons.part_position(dummy, &"torso"))

	await _weapons.fire()

	var fired := EventLog.find(&"weapon.fired")
	assert_array(fired).has_size(1)
	assert_str(fired[0].data["hit"]).is_equal(String(dummy.hitboxes.box(&"torso").name))
	var hits := Weapons.damaged(&"torso")
	assert_array(hits).has_size(1)
	assert_str(hits[0].target).is_equal("Dummy10m")
	assert_str(hits[0].data["type"]).is_equal("damage.ballistic")
	assert_float(hits[0].data["amount"]).is_equal(25.0)
	assert_float(dummy.body.health(&"torso")).is_equal(55.0)


func test_baton_from_behind_knocks_the_unaware_melee_dummy_out_in_one_hit() -> void:
	await _load_hub()
	var dummy := _room.get_node("Melee/UnawareDummy") as TrainingDummy
	await _weapons.equip(2)
	await _weapons.aim_at(_room.to_global(BEHIND_UNAWARE), Weapons.part_position(dummy, &"torso"))

	await _weapons.fire()

	var stunned := EventLog.find(&"actor.stunned")
	assert_array(stunned).has_size(1)
	assert_str(stunned[0].target).is_equal("UnawareDummy")
	assert_bool(stunned[0].data["behind"]).is_true()
	assert_bool(stunned[0].data["aware"]).is_false()
	assert_bool(dummy.body.is_unconscious()).is_true()
	assert_array(EventLog.find(&"actor.knocked_out")).has_size(1)


func test_baton_from_behind_takes_three_hits_on_the_aware_melee_dummy() -> void:
	await _load_hub()
	var dummy := _room.get_node("Melee/AwareDummy") as TrainingDummy
	await _weapons.equip(2)
	await _weapons.aim_at(_room.to_global(BEHIND_AWARE), Weapons.part_position(dummy, &"torso"))

	for hit in 2:
		await _weapons.fire(SWING_FRAMES)
		assert_bool(dummy.body.is_unconscious()).is_false()
	await _weapons.fire()

	var stunned := EventLog.find(&"actor.stunned")
	assert_array(stunned).has_size(3)
	for entry: EventLogEntry in stunned:
		assert_str(entry.target).is_equal("AwareDummy")
		assert_bool(entry.data["behind"]).is_true()
		assert_bool(entry.data["aware"]).is_true()
		assert_float(entry.data["amount"]).is_equal(20.0)
	assert_bool(dummy.body.is_unconscious()).is_true()
	assert_array(EventLog.find(&"actor.knocked_out")).has_size(1)


func test_blast_lane_damage_falls_from_the_2_m_to_the_3_m_line_and_is_zero_on_the_6_m_line() -> void:
	await _load_hub()
	await _weapons.equip(1)

	# The room's barrel from the 6 m line, then fresh ones in its place from the 3 m and 2 m lines.
	var far := await _blast_damage(6.0)
	Objects.spawn(_room, Objects.EXPLOSIVE_BARREL, _room.to_global(BLAST_BARREL), "BlastBarrel2")
	await _driver.frames(5)
	var middle := await _blast_damage(3.0)
	Objects.spawn(_room, Objects.EXPLOSIVE_BARREL, _room.to_global(BLAST_BARREL), "BlastBarrel3")
	await _driver.frames(5)
	var near := await _blast_damage(2.0)

	var message := "2 m %.1f, 3 m %.1f, 6 m %.1f" % [near, middle, far]
	assert_float(near).override_failure_message(message).is_greater(middle)
	assert_float(middle).override_failure_message(message).is_greater(0.0)
	assert_float(far).override_failure_message(message).is_equal(0.0)
	assert_bool(_driver.player.is_dead()).is_false()


## Shoots the blast lane barrel from its `metres` line and returns the player's body damage total.
func _blast_damage(metres: float) -> float:
	var feet := BLAST_BARREL + Vector3(0, -BLAST_BARREL.y, metres)
	await _weapons.aim_at(_room.to_global(feet), _room.to_global(BLAST_BARREL))
	await _weapons.fire(10)
	assert_array(EventLog.find(&"object.exploded")).override_failure_message("%.0f m" % metres).has_size(1)
	var total := 0.0
	for entry in EventLog.find(&"actor.damaged"):
		if entry.target == "Player":
			total += float(entry.data["amount"])
	return total


func _load_hub() -> void:
	_driver = PlayerDriver.new(scene_runner(HUB))
	_weapons = Weapons.new(_driver)
	_room = _driver.runner.find_child("ShootingRangeRoom") as Node3D
	await _driver.settle()
