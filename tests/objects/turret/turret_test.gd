extends GdUnitTestSuite
## Integration (ADR 0079): the turret in the security showcase
## (tests/objects/fixtures/showcase/security_helpers.gd has the layout). The camera is disabled in
## every test. The turret spot is 6 m in front of the turret's eye, lit: gain 2.0 x 0.95 -> the meter
## fills in about 0.5 s, then 1 s of wind-up before the first shot.

const Showcase := preload("res://tests/objects/fixtures/showcase/security_helpers.gd")
const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const HITBOXES := preload("res://actors/common/body/hitboxes.tscn")
## Facing the turret (-X) from the turret spot.
const FACING_TURRET := PI / 2.0
## Behind the turret, out of its view.
const HIDDEN_SPOT := Vector3(4, 0, -3)

var _show: Showcase


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	_show = Showcase.new()
	await _show.setup(scene_runner(Showcase.SHOWCASE))
	await _show.command(Device.DISABLE, "Camera")
	_show.turret().holder.seed_rng(7)
	EventLog.clear()


func after_test() -> void:
	StimulusSystem.clear()


func test_it_reports_winds_up_then_fires_and_hurts_the_player() -> void:
	var body := BodyParts.of(_show.player)
	await _show.place_player(Showcase.TURRET_SPOT, FACING_TURRET)
	var engaged_after := await _show.wait_for(&"turret.engaged", 3.0)
	assert_float(engaged_after).is_between(0.3, 1.2)
	var detected := EventLog.find(&"turret.detected")
	assert_array(detected).has_size(1)
	assert_int(int(detected[0].data["controllers"])).is_equal(1)
	# Wind-up: the laser is on, nothing fired yet.
	await _show.seconds(0.8)
	assert_bool((_show.node("Turret").get_node("Model/Head/Aim/Laser") as Node3D).visible).is_true()
	assert_array(_fired()).is_empty()
	await _show.seconds(1.0)
	assert_array(_fired()).is_not_empty()
	assert_float(_total_health(body)).is_less(_full_health(body))
	# The incident went through the switch to the controller: the siren rings.
	assert_array(EventLog.find(&"siren.started")).is_not_empty()


func test_it_stops_a_second_after_losing_sight() -> void:
	await _show.place_player(Showcase.TURRET_SPOT, FACING_TURRET)
	await _show.wait_for(&"turret.engaged", 3.0)
	await _show.seconds(1.5)
	await _show.place_player(HIDDEN_SPOT)
	await _show.seconds(0.5)
	assert_bool(_show.turret().model.is_engaged()).is_true()
	await _show.seconds(0.8)
	assert_bool(_show.turret().model.is_engaged()).is_false()
	assert_str(String(EventLog.find(&"turret.disengaged")[0].data["reason"])).is_equal("lost")
	var shots := _fired().size()
	await _show.seconds(1.0)
	assert_int(_fired().size()).is_equal(shots)
	assert_bool((_show.node("Turret").get_node("Model/Head/Aim/Laser") as Node3D).visible).is_false()


func test_retargeted_at_guards_it_shoots_a_guard_and_ignores_the_player() -> void:
	await _show.place_player(Vector3(12, 0, 1), FACING_TURRET)
	await _show.command(Device.TARGET_GUARDS, "Turret")
	assert_array(_show.turret().hostile_tags()).contains_exactly([&"actor.guard"])
	var guard := _guard(Showcase.TURRET_SPOT)
	var guard_body := BodyParts.of(guard)
	var full := _total_health(guard_body)
	assert_float(await _show.wait_for(&"turret.engaged", 3.0)).is_greater_equal(0.0)
	assert_str(String(EventLog.find(&"turret.engaged")[0].data["target"])).is_equal("Guard")
	await _show.seconds(2.0)
	assert_float(_total_health(guard_body)).is_less(full)
	assert_float(_total_health(BodyParts.of(_show.player))).is_equal(_full_health(BodyParts.of(_show.player)))


func test_the_player_is_not_a_target_once_retargeted_and_is_again_after() -> void:
	await _show.command(Device.TARGET_GUARDS, "Turret")
	await _show.place_player(Showcase.TURRET_SPOT, FACING_TURRET)
	await _show.seconds(2.0)
	assert_array(EventLog.find(&"turret.engaged")).is_empty()
	await _show.command(Device.TARGET_INTRUDERS, "Turret")
	assert_float(await _show.wait_for(&"turret.engaged", 2.0)).is_greater_equal(0.0)


func test_a_downed_guard_or_player_is_not_a_target_for_any_preset() -> void:
	await _show.command(Device.TARGET_GUARDS, "Turret")
	var guard := _guard(Showcase.TURRET_SPOT)
	Characters.tags_of(guard).add(ActorState.DEAD)
	await _show.seconds(2.0)
	assert_array(EventLog.find(&"turret.engaged")).is_empty()
	assert_float(_show.turret().meter.meter).is_equal(0.0)
	guard.queue_free()
	await _show.command(Device.TARGET_INTRUDERS, "Turret")
	ActorState.set_tag(_show.player, ActorState.UNCONSCIOUS, true)
	await _show.place_player(Showcase.TURRET_SPOT, FACING_TURRET)
	await _show.seconds(2.0)
	assert_array(EventLog.find(&"turret.engaged")).is_empty()
	ActorState.set_tag(_show.player, ActorState.UNCONSCIOUS, false)


func test_a_target_going_down_ends_the_engagement_for_good() -> void:
	await _show.command(Device.TARGET_GUARDS, "Turret")
	var guard := _guard(Showcase.TURRET_SPOT)
	assert_float(await _show.wait_for(&"turret.engaged", 3.0)).is_greater_equal(0.0)
	Characters.tags_of(guard).add(ActorState.UNCONSCIOUS)
	await _show.seconds(0.2)
	var dropped := EventLog.find(&"turret.disengaged")
	assert_array(dropped).has_size(1)
	assert_str(String(dropped[0].data["reason"])).is_equal("target_down")
	var shots := _fired().size()
	await _show.seconds(2.0)
	assert_array(EventLog.find(&"turret.engaged")).has_size(1)
	assert_int(_fired().size()).is_equal(shots)
	assert_object(_show.turret().target).is_null()


func test_never_fires_when_someone_else_is_in_the_line() -> void:
	# A guard stand-in (not a target) 2 m in front of the turret, the player behind it on the line.
	_guard(Vector3(10.3, 0, -3))
	await _show.place_player(Showcase.TURRET_SPOT, FACING_TURRET)
	await _show.seconds(3.5)
	assert_array(EventLog.find(&"turret.engaged")).is_not_empty()
	assert_array(_fired()).is_empty()
	assert_bool(_show.turret().line_clear).is_false()


func test_disabled_unpowered_or_broken_turrets_stay_idle() -> void:
	await _show.command(Device.DISABLE, "Turret")
	await _show.place_player(Showcase.TURRET_SPOT, FACING_TURRET)
	await _show.seconds(3.0)
	assert_array(EventLog.find(&"turret.detected")).is_empty()
	await _show.command(Device.ENABLE, "Turret")
	Powered.of(_show.node("Turret")).on = false
	await _show.seconds(3.0)
	assert_array(EventLog.find(&"turret.detected")).is_empty()
	Powered.of(_show.node("Turret")).on = true
	# Three pistol rounds (25 each) break its 60 health.
	var breakable := Breakable.of(_show.node("Turret"))
	breakable.take_damage(&"damage.ballistic", 25.0)
	breakable.take_damage(&"damage.ballistic", 25.0)
	assert_bool(ActorState.has(_show.node("Turret"), Device.BROKEN)).is_false()
	breakable.take_damage(&"damage.ballistic", 25.0)
	assert_bool(ActorState.has(_show.node("Turret"), Device.BROKEN)).is_true()
	await _show.seconds(3.0)
	assert_array(EventLog.find(&"turret.detected")).is_empty()
	assert_array(_fired()).is_empty()


func test_time_to_kill_a_standing_player_at_6_m() -> void:
	# From stepping into view (meter empty) to death, over several runs with different shot seeds.
	var body := BodyParts.of(_show.player)
	var times: Array[float] = []
	for run in 5:
		body.reset()
		await _show.place_player(HIDDEN_SPOT)
		await _show.command(Device.DISABLE, "Turret")
		await _show.command(Device.ENABLE, "Turret")
		_show.turret().holder.seed_rng(101 + run * 17)
		await _show.place_player(Showcase.TURRET_SPOT, FACING_TURRET)
		var ticks := 0
		while not body.is_dead() and ticks < 20 * 60:
			await _show.frames(1)
			ticks += 1
		times.append(ticks / 60.0)
	var total := 0.0
	for time in times:
		total += time
	var mean := total / times.size()
	print("turret vs standing player at 6 m: time to kill %s s, mean %.2f s" % [str(times), mean])
	assert_float(mean).is_between(3.0, 5.0)


func _guard(local: Vector3) -> CharacterBody3D:
	# Positions under the scene root are showcase-local.
	var body := Characters.character(_show.scene, "Guard", local, [] as Array[StringName], PhysicsLayers.ACTORS)
	body.rotation.y = -PI / 2.0
	body.add_child(HITBOXES.instantiate())
	Characters.tags_of(body).add(&"actor.guard")
	return body


func _fired() -> Array[EventLogEntry]:
	return EventLog.find(&"weapon.fired").filter(func(entry: EventLogEntry) -> bool: return entry.source == "Turret")


static func _total_health(body: BodyParts) -> float:
	var total := 0.0
	for part in BodyDamageModel.PARTS:
		total += body.health(part)
	return total


static func _full_health(body: BodyParts) -> float:
	var profile := body.profile
	return profile.head_health + profile.torso_health + 2.0 * profile.arm_health + 2.0 * profile.leg_health
