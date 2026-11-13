extends GdUnitTestSuite
## Integration (ADR 0131, M14b): the frag payload on a grenade stand-in built from components
## (explosive_fixtures.grenade(): Explosive + Breakable + frag_payload.tscn), set off with
## Explosive.explode(). Distances are horizontal, from the grenade (0.1 m above the floor) to the
## character's feet; the damage is measured at the character's receiver (1.2 m up; the guard's
## 1.6 m). Targets: dead at 2 m, more than half the torso gone but alive at 4.5 m, untouched at 7 m;
## the player's body (player_body.tres) and the guards' (the training dummy's numbers, and the
## shipped guard scene) alike. It pushes props, sets off barrels and other grenades, starts no fire
## and is very loud.
##   plan (x east, z south): a grenade at (0, -7) with player bodies at x = 2, 4.5, 7 on z = -7;
##   another at (0, 7) with guard bodies on z = 7 (14 m apart: neither reaches the other row).

const Grenades := preload("res://tests/objects/explosives/explosive_fixtures.gd")
const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const PLAYER_BODY: BodyProfile = preload("res://actors/player/player_body.tres")
const GUARD_BODY: BodyProfile = preload("res://actors/guard/guard_body.tres")
const GUARD: PackedScene = preload("res://actors/guard/guard.tscn")
const BARREL: PackedScene = preload("res://objects/explosive_barrel/explosive_barrel.tscn")
const PUSHED: Receptron = preload("res://objects/components/receptrons/pushed_by_force.tres")
const ORIGIN := Vector3(260, 0, -560)
const GRENADE_AT := Vector3(0, 0.1, 0)
const DISTANCES: Array[float] = [2.0, 4.5, 7.0]

var _root: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new()) as Node3D
	_root.position = ORIGIN
	add_child(_root)
	Characters.floor_box(_root)


func after_test() -> void:
	Grenades.clear_effects(get_tree())
	StimulusSystem.clear()


func test_kills_within_3_m_hurts_badly_to_6_m_and_spares_7_m() -> void:
	var rows: Dictionary[String, BodyProfile] = {"Player": PLAYER_BODY, "Guard": GUARD_BODY}
	var bodies: Dictionary[String, BodyParts] = {}
	var z := -7.0
	for row: String in rows:
		for d in DISTANCES:
			var key := "%s%.1f" % [row, d]
			var body := Characters.character(_root, key, Vector3(d, 0, z), [], PhysicsLayers.ACTORS, [], rows[row])
			bodies[key] = Characters.body_parts(body)
		z += 14.0
	await _frames(2)
	var grenade := Grenades.grenade(_root, "Frag", GRENADE_AT + Vector3(0, 0, -7), Grenades.FRAG)
	# One grenade per row, 14 m apart: neither reaches the other row or grenade.
	var second := Grenades.grenade(_root, "Frag2", GRENADE_AT + Vector3(0, 0, 7), Grenades.FRAG)
	Grenades.explosive_of(grenade).explode()
	await _frames(1)
	Grenades.explosive_of(second).explode()
	await _frames(4)

	for row: String in rows:
		var torso := rows[row].torso_health
		var near := bodies["%s2.0" % row]
		var mid := bodies["%s4.5" % row]
		var far := bodies["%s7.0" % row]
		assert_bool(near.is_dead()).override_failure_message("%s at 2 m" % row).is_true()
		assert_bool(mid.is_dead()).override_failure_message("%s at 4.5 m" % row).is_false()
		assert_float(mid.health(BodyDamageModel.TORSO)).override_failure_message("%s at 4.5 m" % row).is_less(
			torso * 0.5
		)
		assert_float(far.health(BodyDamageModel.TORSO)).override_failure_message("%s at 7 m" % row).is_equal(torso)


func test_kills_the_shipped_guard_at_2_m_and_hurts_it_at_4_5_m() -> void:
	var near := _guard("GuardNear", Vector3(2, 0, -7))
	var mid := _guard("GuardMid", Vector3(4.5, 0, 7))
	await _frames(2)
	var first := Grenades.grenade(_root, "Frag", GRENADE_AT + Vector3(0, 0, -7), Grenades.FRAG)
	var second := Grenades.grenade(_root, "Frag2", GRENADE_AT + Vector3(0, 0, 7), Grenades.FRAG)
	Grenades.explosive_of(first).explode()
	await _frames(1)
	Grenades.explosive_of(second).explode()
	await _frames(4)

	assert_bool(BodyParts.of(near).is_dead()).is_true()
	var body := BodyParts.of(mid)
	assert_bool(body.is_dead()).is_false()
	assert_float(body.health(BodyDamageModel.TORSO)).is_less(GUARD_BODY.torso_health * 0.5)


func test_pushes_props_chains_to_barrels_and_grenades_without_fire_and_loud() -> void:
	var prop := Fixtures.rigid_entity(_root, "Crate", Vector3(3, 0.3, 0), [PUSHED])
	var pushed := Characters.character(_root, "Walker", Vector3(0, 0, -5), [Characters.KNOCKBACK_COMPONENT])
	var barrel := BARREL.instantiate() as Node3D
	barrel.name = "Barrel"
	barrel.position = Vector3(-4, 0.45, 0)
	_root.add_child(barrel)
	var gas := Grenades.grenade(_root, "GasGrenade", Vector3(0, 0.1, 3.5), Grenades.GAS)
	await _frames(3)
	var frag := Grenades.grenade(_root, "Frag", GRENADE_AT, Grenades.FRAG)
	Grenades.explosive_of(frag).explode()
	await _frames(6)

	assert_float(prop.linear_velocity.length()).is_greater(1.0)
	# The walker 5 m north was pushed further north.
	assert_float(pushed.position.z).is_less(-5.05)
	var exploded: Array = EventLog.find(&"object.exploded").map(func(e: EventLogEntry) -> String: return e.source)
	assert_array(exploded).contains(["Frag", "Barrel", "GasGrenade"])
	assert_bool(is_instance_valid(gas)).is_false()
	assert_object(Grenades.first(get_tree(), GasCloud.GROUP)).is_not_null()
	# No fire from the frag itself (the barrel's own blast has fire).
	var frag_stimuli := EventLog.find(&"stimulus.emitted").filter(
		func(e: EventLogEntry) -> bool: return e.data["source"] == "Frag"
	)
	var types: Array = frag_stimuli.map(func(e: EventLogEntry) -> StringName: return e.data["type"])
	assert_array(types).not_contains([&"fire"])
	assert_array(types).contains([&"damage.explosive", &"force.blast", &"noise"])
	var noise: Array = frag_stimuli.filter(func(e: EventLogEntry) -> bool: return e.data["type"] == &"noise")
	assert_float(float((noise[0] as EventLogEntry).data["intensity"])).is_greater_equal(60.0)


func _guard(guard_name: String, feet: Vector3) -> Node3D:
	var guard := GUARD.instantiate() as Node3D
	guard.name = guard_name
	guard.position = feet
	_root.add_child(guard)
	return guard


func _frames(count: int) -> void:
	await Fixtures.frames(get_tree(), count)
