extends GdUnitTestSuite
## Integration (ADR 0131, M14b): the gas payload on a grenade stand-in (explosive_fixtures) releases a
## GasCloud in the level; its `damage.stun.gas` pulses (uniform, line of sight to its centre) knock
## out whoever breathes them in about 3 s: a body with the player's profile, one with the guards' and
## the shipped guard alike. Not behind a wall, not outside its radius; no more after it ends (12 s).
## Game time runs 8x (physics delta 1/60 s). Times are measured from the release, in physics frames.
##   plan (x east, z south; grenade at (0, 0.1, 0), the cloud's centre rises to 1.1 m):
##     Player body (1, 0, 0)  Guard body (-1, 0, 0.5)  shipped Guard (0, 0, -1.2)
##     wall: z = 1.5 (0.2 thick, 4 m wide, 3 m tall);  Hidden body behind it (0, 0, 2.2)
##     Outside body (4, 0, 0) (3.9 m from the centre, radius 2.5)

const Grenades := preload("res://tests/objects/explosives/explosive_fixtures.gd")
const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const PLAYER_BODY: BodyProfile = preload("res://actors/player/player_body.tres")
const GUARD_BODY: BodyProfile = preload("res://actors/guard/guard_body.tres")
const GUARD: PackedScene = preload("res://actors/guard/guard.tscn")
const CLOUD: PackedScene = preload("res://objects/explosives/gas_cloud/gas_cloud.tscn")
const CONFIG: GasCloudConfig = preload("res://objects/explosives/gas_cloud/gas_cloud.tres")
const ORIGIN := Vector3(-260, 0, -620)
const TIME_FACTOR := 8.0

var _root: Node3D
var _saved_time: Vector2


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_saved_time = Grenades.speed_up(TIME_FACTOR)
	_root = auto_free(Node3D.new()) as Node3D
	_root.position = ORIGIN
	add_child(_root)
	Characters.floor_box(_root)


func after_test() -> void:
	Grenades.restore_time(_saved_time)
	Grenades.clear_effects(get_tree())
	StimulusSystem.clear()


func test_knocks_out_the_player_and_guards_in_about_3_s_but_not_behind_a_wall() -> void:
	var player := _body("PlayerBody", Vector3(1, 0, 0), PLAYER_BODY)
	var guard_body := _body("GuardBody", Vector3(-1, 0, 0.5), GUARD_BODY)
	var guard := GUARD.instantiate() as Node3D
	guard.name = "Guard"
	guard.position = Vector3(0, 0, -1.2)
	_root.add_child(guard)
	Grenades.wall(_root, Vector3(0, 1.5, 1.5), Vector3(4, 3, 0.2))
	var hidden := _body("Hidden", Vector3(0, 0, 2.2), GUARD_BODY)
	var outside := _body("Outside", Vector3(4, 0, 0), GUARD_BODY)
	await Grenades.seconds(get_tree(), 0.05)
	var grenade := Grenades.grenade(_root, "GasGrenade", Vector3(0, 0.1, 0), Grenades.GAS)
	Grenades.explosive_of(grenade).explode()
	var cloud := Grenades.first(get_tree(), GasCloud.GROUP) as GasCloud
	assert_object(cloud).is_not_null()
	cloud.drift = Vector3.ZERO
	# In the level, not under the grenade (which is removed).
	assert_bool(grenade.is_ancestor_of(cloud)).is_false()
	var start := Engine.get_physics_frames()
	var knocked: Dictionary[String, float] = {}
	var watched: Dictionary[String, BodyParts] = {
		"player": BodyParts.of(player), "guard body": BodyParts.of(guard_body), "guard": BodyParts.of(guard)
	}
	for frame in roundi(4.0 * 60.0):
		await get_tree().physics_frame
		for who: String in watched:
			if not knocked.has(who) and watched[who].is_unconscious():
				knocked[who] = (Engine.get_physics_frames() - start) / 60.0
	print("M14b gas: knocked out after (s) ", knocked)
	for who: String in watched:
		assert_bool(knocked.has(who)).override_failure_message("%s not knocked out" % who).is_true()
		# Six pulses of 10 every 0.5 s against a threshold of 60: 3 s, a tick or two of delivery.
		assert_float(knocked.get(who, 0.0)).override_failure_message(who).is_between(2.9, 3.2)
	assert_float(BodyParts.of(hidden).stun).is_equal(0.0)
	assert_float(BodyParts.of(outside).stun).is_equal(0.0)
	# A breath is not a blow: no hit reaction from the gas.
	assert_array(EventLog.find(&"actor.hit_reacted")).is_empty()


func test_hisses_when_released() -> void:
	var grenade := Grenades.grenade(_root, "GasGrenade", Vector3(0, 0.1, 0), Grenades.GAS)
	Grenades.explosive_of(grenade).explode()
	await Grenades.seconds(get_tree(), 0.05)
	var noises := EventLog.find(&"stimulus.emitted").filter(
		func(e: EventLogEntry) -> bool: return e.data["type"] == &"noise" and e.data["source"] == "GasGrenade"
	)
	assert_array(noises).has_size(1)
	assert_float(float((noises[0] as EventLogEntry).data["intensity"])).is_between(5.0, 15.0)
	# No blast damage, no fire, no push.
	var blast := EventLog.find(&"stimulus.emitted").filter(
		func(e: EventLogEntry) -> bool: return String(e.data["type"]).begins_with("damage.explosive")
	)
	assert_array(blast).is_empty()


func test_ends_after_12_s_and_stuns_no_more() -> void:
	var player := _body("PlayerBody", Vector3(1, 0, 0), PLAYER_BODY)
	var cloud := _cloud(Vector3(0, 0.1, 0))
	await Grenades.seconds(get_tree(), 1.2)
	assert_float(BodyParts.of(player).stun).is_greater(0.0)
	# Skip to its last second (each second of game time is simulated otherwise).
	cloud.age = CONFIG.duration - 1.0
	await Grenades.seconds(get_tree(), 1.1)
	assert_bool(is_instance_valid(cloud)).is_false()
	assert_array(EventLog.find(&"gas.ended")).has_size(1)
	var stun := BodyParts.of(player).stun
	await Grenades.seconds(get_tree(), 1.0)
	assert_float(BodyParts.of(player).stun).is_equal(stun)


func test_drifts_and_stops_short_of_a_wall() -> void:
	Grenades.wall(_root, Vector3(2.0, 1.5, 0), Vector3(0.2, 3, 4))
	var cloud := _cloud(Vector3(0.7, 0.1, 0))
	cloud.drift = Vector3.RIGHT
	await Grenades.seconds(get_tree(), 3.0)
	# The wall's face is at x = 1.9: it stops once the face is within the 1 m margin ahead.
	var x := cloud.global_position.x - ORIGIN.x
	assert_float(x).is_between(0.85, 0.95)
	assert_float(cloud.global_position.y - ORIGIN.y).is_equal_approx(0.1 + CONFIG.lift, 0.01)


func test_saves_its_time_and_place() -> void:
	var cloud := _cloud(Vector3(0.5, 0.1, 0))
	cloud.drift = Vector3.ZERO
	await Grenades.seconds(get_tree(), 0.5)
	cloud.age = 7.0
	var data := cloud.save_state()
	var copy := CLOUD.instantiate() as GasCloud
	_root.add_child(copy)
	copy.load_state(data)
	assert_float(copy.time_left()).is_equal_approx(CONFIG.duration - 7.0, 0.01)
	assert_vector(copy.global_position).is_equal_approx(cloud.global_position, Vector3.ONE * 0.001)
	await Grenades.seconds(get_tree(), 0.1)
	# Loaded: it does not rise a second time.
	assert_vector(copy.global_position).is_equal_approx(cloud.global_position, Vector3.ONE * 0.001)


func _body(body_name: String, feet: Vector3, profile: BodyProfile) -> CharacterBody3D:
	return Characters.character(_root, body_name, feet, [], PhysicsLayers.ACTORS, [], profile)


func _cloud(at: Vector3) -> GasCloud:
	return ExplosivePayload.spawn_in_level(CLOUD, _root, ORIGIN + at) as GasCloud
