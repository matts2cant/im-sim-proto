extends GdUnitTestSuite
## Hit markers (ADR 0126): HitMarkerRules reads the EventLog the damage already writes; a character's
## damage, stun, knockout or death caused by one of the watched shooter's damage stimuli gives a
## marker (head: HEAD, a kill: KILL), nothing from anyone else's stimuli or on the shooter itself.
## HitMarker shows the kind for its time with its colour and shape, a stronger one replacing a
## weaker one, with a tick sound. The chain runs end to end with a shooter built from components
## (shooter_fixtures.gd) and a training dummy with the guards' body (torso 80, head 40, head x2).

const Shooter := preload("res://tests/items/weapons/shooter_fixtures.gd")
const PISTOL: WeaponData = preload("res://items/weapons/pistol/pistol.tres")
const SMG: WeaponData = preload("res://items/weapons/smg/smg.tres")
const BATON: WeaponData = preload("res://items/weapons/baton/baton.tres")
const DUMMY: PackedScene = preload("res://actors/dummy/training_dummy.tscn")
const GUARD_BODY: BodyProfile = preload("res://actors/guard/guard_body.tres")
const CONFIG: HitMarkerConfig = preload("res://ui/hud/hit_marker.tres")
const ORIGIN := Vector3(660, 0, -380)

var _rules: HitMarkerRules
var _marker: HitMarker
var _root: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_rules = HitMarkerRules.new(["Player"] as Array[String])
	_marker = auto_free(HitMarker.new()) as HitMarker
	_marker.size = Vector2(1920, 1080)
	add_child(_marker)
	_root = auto_free(Node3D.new()) as Node3D
	add_child(_root)


func after_test() -> void:
	StimulusSystem.clear()


func test_the_shooters_damage_gives_body_head_stun_knockout_and_kill() -> void:
	_emitted(7, "Player")

	assert_int(_observe(&"actor.damaged", "Guard", {"part": "torso", "amount": 25.0, "by": 7})).is_equal(
		HitMarkerRules.Kind.BODY
	)
	assert_int(_observe(&"actor.damaged", "Guard", {"part": "head", "amount": 50.0, "by": 7})).is_equal(
		HitMarkerRules.Kind.HEAD
	)
	assert_int(_observe(&"actor.stunned", "Guard", {"amount": 20.0, "by": 7})).is_equal(HitMarkerRules.Kind.STUN)
	assert_int(_observe(&"actor.knocked_out", "Guard", {"by": 7})).is_equal(HitMarkerRules.Kind.KNOCKOUT)
	assert_int(_observe(&"actor.died", "Guard", {"by": 7})).is_equal(HitMarkerRules.Kind.KILL)


func test_nothing_from_others_stimuli_noise_or_on_the_shooter() -> void:
	_emitted(8, "Guard")
	_emitted(9, "Player", &"noise")
	_emitted(10, "Player")

	assert_int(_observe(&"actor.damaged", "Dummy", {"part": "torso", "amount": 25.0, "by": 8})).is_equal(
		HitMarkerRules.Kind.NONE
	)
	assert_int(_observe(&"actor.damaged", "Dummy", {"part": "torso", "amount": 25.0, "by": 9})).is_equal(
		HitMarkerRules.Kind.NONE
	)
	# The player hurting itself (a blast it set off) shows nothing.
	assert_int(_observe(&"actor.damaged", "Player", {"part": "torso", "amount": 5.0, "by": 10})).is_equal(
		HitMarkerRules.Kind.NONE
	)
	assert_int(_observe(&"actor.damaged", "Dummy", {"part": "torso", "amount": 0.0, "by": 10})).is_equal(
		HitMarkerRules.Kind.NONE
	)


func test_markers_last_their_time_a_stronger_one_replaces_a_weaker() -> void:
	_marker.show_marker(HitMarkerRules.Kind.BODY)
	assert_float(_marker.time_left).is_equal_approx(CONFIG.body_time, 0.001)
	_marker.step(CONFIG.body_time + 0.01)
	assert_bool(_marker.is_showing()).is_false()

	_marker.show_marker(HitMarkerRules.Kind.BODY)
	_marker.show_marker(HitMarkerRules.Kind.KILL)
	assert_int(_marker.kind).is_equal(HitMarkerRules.Kind.KILL)
	assert_float(_marker.time_left).is_equal_approx(CONFIG.kill_time, 0.001)
	# A weaker one does not cut the kill short.
	_marker.show_marker(HitMarkerRules.Kind.HEAD)
	assert_int(_marker.kind).is_equal(HitMarkerRules.Kind.KILL)
	_marker.step(0.3)
	assert_bool(_marker.is_showing()).is_true()
	_marker.step(0.1)
	assert_bool(_marker.is_showing()).is_false()


func test_each_kind_has_its_colour_shape_and_a_tick() -> void:
	assert_float(CONFIG.head_time).is_greater(CONFIG.body_time)
	assert_float(CONFIG.kill_time).is_greater(CONFIG.head_time)
	# White, yellow, red, pale blue.
	assert_float(CONFIG.color_of(HitMarkerRules.Kind.BODY).s).is_less(0.1)
	assert_float(CONFIG.color_of(HitMarkerRules.Kind.HEAD).r).is_greater(
		CONFIG.color_of(HitMarkerRules.Kind.HEAD).b * 2.0
	)
	assert_float(CONFIG.color_of(HitMarkerRules.Kind.KILL).r).is_greater(
		CONFIG.color_of(HitMarkerRules.Kind.KILL).g * 2.0
	)
	assert_float(CONFIG.color_of(HitMarkerRules.Kind.STUN).b).is_greater(CONFIG.color_of(HitMarkerRules.Kind.STUN).r)
	_marker.show_marker(HitMarkerRules.Kind.BODY)
	var ticks := _marker.segments()
	_marker.show_marker(HitMarkerRules.Kind.KILL)
	var cross := _marker.segments()

	assert_int(ticks.size()).is_equal(4)
	# Four diagonal ticks around the centre; the kill's X reaches closer in and further out.
	var centre := _marker.size * 0.5
	assert_float(ticks[0][0].distance_to(centre)).is_equal_approx(CONFIG.tick_inner, 0.01)
	assert_float(absf(ticks[0][1].x - centre.x)).is_equal_approx(absf(ticks[0][1].y - centre.y), 0.01)
	assert_float(cross[0][0].distance_to(centre)).is_less(ticks[0][0].distance_to(centre))
	assert_float(cross[0][1].distance_to(centre)).is_greater(ticks[0][1].distance_to(centre))
	assert_int(_marker.sounds).is_equal(2)


func test_a_showing_marker_follows_the_aim_offset() -> void:
	var draws: Array[int] = [0]
	_marker.draw.connect(func() -> void: draws[0] += 1)
	_marker.show_marker(HitMarkerRules.Kind.BODY)
	await await_idle_frame()
	var before := draws[0]

	# The crosshair climbs under recoil while the marker shows.
	_marker.offset = Vector2(3, -40)
	await await_idle_frame()

	assert_int(draws[0]).is_greater(before)
	var ticks := _marker.segments()
	var centre := _marker.size * 0.5 + Vector2(3, -40)
	assert_float(ticks[0][0].distance_to(centre)).is_equal_approx(CONFIG.tick_inner, 0.01)
	# No marker showing: nothing to redraw.
	_marker.clear()
	await await_idle_frame()
	before = draws[0]
	_marker.offset = Vector2(0, -10)
	await await_idle_frame()
	assert_int(draws[0]).is_equal(before)


func test_a_burst_of_pellet_hits_ticks_once() -> void:
	for i in 8:
		_marker.show_marker(HitMarkerRules.Kind.BODY)

	assert_int(_marker.sounds).is_equal(1)


func test_shots_at_a_dummy_show_body_head_and_kill_markers() -> void:
	var shooter := Shooter.new(_root, ORIGIN, [SMG, PISTOL] as Array[WeaponData])
	_marker.watch(shooter.user)
	var dummy := _dummy(Vector3(0, 0, -4))
	await _settle()

	await _shoot(shooter, dummy.hitboxes.box(&"torso").global_position)
	assert_int(_marker.shown.size()).is_equal(1)
	assert_int(_marker.shown[0]).is_equal(HitMarkerRules.Kind.BODY)

	await _shoot(shooter, dummy.hitboxes.box(&"head").global_position)
	assert_int(_marker.shown[-1]).is_equal(HitMarkerRules.Kind.HEAD)

	# The pistol's headshot (25 x 2) finishes the 40-point head: the kill outranks the headshot.
	shooter.holder.equip(1)
	await _shoot(shooter, dummy.hitboxes.box(&"head").global_position)
	assert_int(_marker.kind).is_equal(HitMarkerRules.Kind.KILL)


func test_a_baton_hit_shows_the_stun_marker() -> void:
	var shooter := Shooter.new(_root, ORIGIN, [BATON] as Array[WeaponData])
	_marker.watch(shooter.user)
	var dummy := _dummy(Vector3(0, 0, -1.2))
	await _settle()

	await _shoot(shooter, dummy.hitboxes.box(&"torso").global_position)

	assert_bool(_marker.shown.has(HitMarkerRules.Kind.STUN)).is_true()


func test_another_shooters_hits_show_nothing() -> void:
	var player := Shooter.new(_root, ORIGIN + Vector3(3, 0, 0), [PISTOL] as Array[WeaponData])
	player.user.name = "Watched"
	var other := Shooter.new(_root, ORIGIN, [PISTOL] as Array[WeaponData])
	_marker.watch(player.user)
	var dummy := _dummy(Vector3(0, 0, -4))
	await _settle()

	await _shoot(other, dummy.hitboxes.box(&"torso").global_position)

	assert_array(_marker.shown).is_empty()
	assert_bool(dummy.body.health(&"torso") < 80.0).is_true()


func _dummy(offset: Vector3) -> TrainingDummy:
	var dummy := DUMMY.instantiate() as TrainingDummy
	(dummy.get_node("BodyParts") as BodyParts).profile = GUARD_BODY
	_root.add_child(dummy)
	dummy.global_transform = Transform3D(Basis(Vector3.UP, PI), ORIGIN + offset)
	return dummy


func _settle() -> void:
	for i in 3:
		await get_tree().physics_frame


# One exact shot (or swing) at `point`, then the frames its stimuli take to land.
func _shoot(shooter: Shooter, point: Vector3) -> void:
	shooter.aim_at(point)
	shooter.holder.aim.spread = 0.0
	shooter.holder.state().cooldown = 0.0
	shooter.holder.trigger()
	for i in 2:
		await get_tree().physics_frame


func _emitted(id: int, source: String, type: StringName = &"damage.ballistic") -> void:
	_rules.observe(_entry(&"stimulus.emitted", "", {"id": id, "type": type, "source": source}, source))


func _observe(kind: StringName, target: String, data: Dictionary) -> int:
	return _rules.observe(_entry(kind, target, data))


func _entry(kind: StringName, target: String, data: Dictionary, source: String = "") -> EventLogEntry:
	return EventLogEntry.new(0, kind, source, target, data)
