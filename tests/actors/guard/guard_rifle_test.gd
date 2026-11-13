extends GdUnitTestSuite
## Integration (ADR 0087): the rifle guard (actors/guard/guard_rifle.tscn, the assault rifle through
## the same CombatBehaviour) fires bursts: 3 to 5 shots at the rifle's cycle (0.1 s = 6 ticks), then
## the shot interval (0.6-0.9 s) before the next burst. The stand-in target 8 m in front is healed
## every tick so it lives through several bursts. Knocked out, its rifle goes into its inventory.

const Combat := preload("res://tests/actors/guard/combat_helpers.gd")
const CONFIG: CombatConfig = preload("res://actors/guard/guard_combat.tres")
const RIFLE_GUARD := "res://actors/guard/guard_rifle.tscn"
const FRONT := Vector3(0, 0, -8)
## Shots closer than this (ticks) belong to one burst: the cycle is 6 ticks, the pause 36 or more.
const BURST_GAP := 15

var _c: Combat


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_c = Combat.new()
	await _c.setup(scene_runner(Combat.YARD), RIFLE_GUARD)


func after_test() -> void:
	_c.teardown()
	StimulusSystem.clear()


# Groups shot ticks into bursts.
static func _bursts(ticks: Array[int]) -> Array[Array]:
	var bursts: Array[Array] = []
	for tick in ticks:
		if bursts.is_empty() or tick - int(bursts[-1][-1]) > BURST_GAP:
			bursts.append([tick])
		else:
			bursts[-1].append(tick)
	return bursts


func test_the_rifle_guard_fires_bursts() -> void:
	assert_str(String(_c.holder.weapons[0].id)).is_equal("assault_rifle")
	var target := _c.intruder(FRONT)
	var target_body := target.get_node("BodyParts") as BodyParts
	for i in 60 * 6:
		target_body.heal(1000.0)
		await _c.frames(1)

	var ticks: Array[int] = []
	for entry in Combat.guard_entries(&"weapon.fired"):
		ticks.append(entry.tick)
	var bursts := _bursts(ticks)
	assert_int(bursts.size()).is_greater_equal(3)
	# Every burst but the last (it may be cut off by the end of the test) has 3-5 shots.
	for i in bursts.size() - 1:
		var burst: Array = bursts[i]
		assert_int(burst.size()).override_failure_message(str(bursts)).is_between(
			CONFIG.burst_shots_min, CONFIG.burst_shots_max
		)
		for j in range(1, burst.size()):
			assert_int(int(burst[j]) - int(burst[j - 1])).override_failure_message(str(bursts)).is_between(6, 7)
		var pause := int(bursts[i + 1][0]) - int(burst[-1])
		assert_int(pause).override_failure_message(str(bursts)).is_greater_equal(
			roundi(CONFIG.shot_interval_min * 60.0)
		)
	assert_bool(_c.holder.trigger_held and not _c.combat.is_bursting()).is_false()
	# ADR 0101: the assault rifle is in the `rifle` class now, but a guard has no Skills, so its
	# shots, cone and sway read the rifle's own numbers (no accidental change to guards).
	assert_object(Skills.of(_c.guard)).is_null()
	for stat: String in ["spread_mult", "reload_mult", "damage_mult", "settle_time", "sway_mult"]:
		assert_float(Attributes.read(_c.guard, StringName("rifle_" + stat), 1.0)).is_equal(1.0)
	# ADR 0127: guards shoot with the weapon's own cone and recoil and pull back their share of it.
	assert_bool(_c.holder.recoil_enabled and _c.holder.weapon_aim).is_true()
	assert_float(_c.holder.recoil.view_share).is_equal(CONFIG.recoil_compensation)
	assert_float(_c.holder.recoil.since_shot).is_less(1.0)
	var shots := EventLog.find(&"stimulus.emitted").filter(
		func(entry: EventLogEntry) -> bool:
			return entry.data["type"] == &"damage.ballistic" and entry.source == String(_c.guard.name)
	)
	assert_array(shots).is_not_empty()
	for entry: EventLogEntry in shots:
		assert_float(float(entry.data["intensity"]) * float(entry.data["scale"])).is_equal(14.0)


func test_a_knocked_out_rifle_guard_keeps_the_rifle_in_its_inventory() -> void:
	(_c.guard.get_node("BodyParts") as BodyParts).take_damage(&"damage.stun", 200.0)
	await _c.frames(3)

	var found: Array[String] = []
	for child in _c.scene.get_children():
		if ItemPickup.of(child) != null:
			found.append(String(child.name))
	assert_array(found).is_empty()
	var rifles := Inventory.of(_c.guard).grid.stacks_of(&"assault_rifle")
	assert_int(rifles.size()).is_equal(1)
	assert_int(int(rifles[0].state.get("magazine", -1))).is_equal(30)
