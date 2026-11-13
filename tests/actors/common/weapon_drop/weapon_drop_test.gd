extends GdUnitTestSuite
## Integration (ADR 0087): WeaponDrop on any character with a WeaponHolder. Knocked out or killed
## (its tags, from any source), the weapons of its fixed loadout become pickups of their items beside
## the body, with the magazine they had; the holder no longer has them, so a woken guard stays
## unarmed and does not fight. Saved: a loaded guard stays unarmed. Weapons the holder does not own
## (the player's, from its inventory) stay in the inventory. Guards in the combat yard
## (tests/actors/guard/combat_helpers.gd), a hostile stand-in 8 m in front.

const Combat := preload("res://tests/actors/guard/combat_helpers.gd")
const FRONT := Vector3(0, 0, -8)

var _c: Combat


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_c = Combat.new()


func after_test() -> void:
	_c.teardown()
	StimulusSystem.clear()


func _pickups() -> Array[ItemPickup]:
	var found: Array[ItemPickup] = []
	for child in _c.scene.get_children():
		var pickup := ItemPickup.of(child)
		if pickup != null:
			found.append(pickup)
	return found


func _body() -> BodyParts:
	return _c.guard.get_node("BodyParts") as BodyParts


func test_a_knocked_out_guard_drops_its_pistol_with_its_magazine_and_wakes_unarmed() -> void:
	await _c.setup(scene_runner(Combat.YARD), Combat.PISTOL_GUARD)
	_c.holder.equip(0)
	_c.holder.state().magazine = 7

	_body().take_damage(&"damage.stun", 200.0)
	await _c.frames(3)

	var pickups := _pickups()
	assert_int(pickups.size()).is_equal(1)
	assert_str(String(pickups[0].item.id)).is_equal("pistol")
	assert_int(int(pickups[0].stack_state()["magazine"])).is_equal(7)
	var beside := pickups[0].entity().global_position.distance_to(_c.guard.global_position + Vector3.UP * 0.4)
	assert_float(beside).is_between(0.3, 1.0)
	assert_array(_c.holder.states).is_empty()
	assert_object(_c.holder.weapon()).is_null()
	var dropped := EventLog.find(&"weapon.dropped")
	assert_int(dropped.size()).is_equal(1)
	assert_int(int(dropped[0].data["magazine"])).is_equal(7)

	# Woken with an intruder in sight: alerted, but it has nothing to fight with.
	_body().revive("test")
	_c.intruder(FRONT)
	await _c.seconds(3.0)
	assert_str(_c.awareness.state_name()).is_equal("alerted")
	assert_array(Combat.guard_entries(&"actor.engaged")).is_empty()
	assert_array(Combat.guard_entries(&"weapon.fired")).is_empty()
	assert_int(_pickups().size()).is_equal(1)


func test_a_killed_guard_drops_its_baton() -> void:
	await _c.setup(scene_runner(Combat.YARD), Combat.BATON_GUARD)

	_body().take_damage(&"damage.ballistic", 200.0, BodyDamageModel.HEAD)
	await _c.frames(3)

	var pickups := _pickups()
	assert_int(pickups.size()).is_equal(1)
	assert_str(String(pickups[0].item.id)).is_equal("baton")
	assert_bool(pickups[0].state.has("magazine")).is_false()
	assert_array(_c.holder.states).is_empty()


func test_a_loaded_guard_stays_unarmed() -> void:
	await _c.setup(scene_runner(Combat.YARD), Combat.PISTOL_GUARD)
	_body().take_damage(&"damage.stun", 200.0)
	await _c.frames(3)
	var saved := _c.holder.save_state()
	var fresh := (load(Combat.PISTOL_GUARD) as PackedScene).instantiate()
	add_child(fresh)
	var holder := fresh.get_node("Aim/WeaponHolder") as WeaponHolder
	assert_int(holder.states.size()).is_equal(1)

	holder.load_state(saved)

	assert_array(holder.states).is_empty()
	assert_array(holder.weapons).is_empty()
	assert_dict(holder.save_state()).is_equal(saved)
	fresh.free()


func test_the_player_keeps_its_inventory_weapons_when_knocked_out() -> void:
	var runner := scene_runner(Combat.YARD_WITH_PLAYER)
	runner.set_time_factor(Combat.TIME_FACTOR)
	var player := runner.find_child("Player") as Player
	player.inventory.add(load("res://items/weapons/pistol/pistol_item.tres") as ItemData, 1)
	player.inventory.select_slot(0)
	await get_tree().physics_frame
	assert_object(player.weapons.weapon()).is_not_null()

	player.body.take_damage(&"damage.stun", 500.0)
	for i in 5:
		await get_tree().physics_frame

	assert_bool(ActorState.can_act(player)).is_false()
	assert_int(player.inventory.grid.count_of(&"pistol")).is_equal(1)
	var spawned := runner.scene().get_children().filter(func(node: Node) -> bool: return ItemPickup.of(node) != null)
	assert_array(spawned).is_empty()
	assert_object(WeaponDrop.of(player)).is_not_null()
