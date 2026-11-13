extends GdUnitTestSuite
## MissionTally (ADR 0087, ADR 0136), pure: tallies and badges from EventLog entries. Ghost is
## broken by an Alerted guard, an alarm or a found body (Suspicious is fine); Pacifist by any death
## the player caused, directly or down a stimulus cause chain (a shot barrel's blast, the fire it
## lit, a turret the player retargeted), never by a knockout. The player is whatever entity has the
## `actor.player` tag, never a name. Entries are built by hand with EventLogEntry.make(), as
## EventLog records them (entities in, names and references kept).

const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")

var _tally: MissionTally
var _player: Node3D
var _guards: Dictionary[String, Node3D] = {}


func before_test() -> void:
	_tally = MissionTally.new()
	_guards.clear()
	_player = _entity("Hero", [&"actor.player"])


func _entity(entity_name: String, tags: Array[StringName] = []) -> Node3D:
	return auto_free(Fixtures.entity(self, entity_name, Vector3(0, -50, 0), [], tags)) as Node3D


# A guard stand-in (no tags) per name.
func _guard(guard_name: String) -> Node3D:
	if not _guards.has(guard_name):
		_guards[guard_name] = _entity(guard_name, [&"actor.guard"])
	return _guards[guard_name]


func _entry(kind: StringName, source: Variant, target: Variant, data: Dictionary) -> EventLogEntry:
	return EventLogEntry.make(0, kind, source, target, data)


func _emitted(id: int, source: Variant, type: StringName, cause_id: int = 0) -> void:
	var data := {"id": id, "type": type, "source": str(source), "cause_id": cause_id}
	_tally.observe(_entry(EventKinds.STIMULUS_EMITTED, source, "", data))


func _died(actor: Node, by: int) -> void:
	_tally.observe(_entry(EventKinds.ACTOR_DIED, "", actor, {"actor": String(actor.name), "by": by}))


func _awareness(actor: String, to: String) -> void:
	var data := {"actor": actor, "from": "unaware", "to": to}
	_tally.observe(_entry(EventKinds.ACTOR_AWARENESS, _guard(actor), "", data))


func test_a_quiet_mission_earns_both_badges() -> void:
	assert_bool(_tally.ghost()).is_true()
	assert_bool(_tally.pacifist()).is_true()


func test_suspicious_keeps_ghost_and_alerted_breaks_it() -> void:
	_awareness("Guard", "suspicious")
	_awareness("Guard", "searching")
	assert_bool(_tally.ghost()).is_true()

	_awareness("Guard", "alerted")

	assert_bool(_tally.ghost()).is_false()
	assert_int(_tally.alerts).is_equal(1)


func test_an_alarm_breaks_ghost_and_counts_once_per_ring() -> void:
	var raised := {"by": "Camera", "point": Vector3.ZERO, "duration": 30.0, "again": false}
	_tally.observe(_entry(EventKinds.ALARM_RAISED, "Camera", "Controller", raised))
	var again := raised.duplicate()
	again["again"] = true
	_tally.observe(_entry(EventKinds.ALARM_RAISED, "Camera", "Controller", again))

	assert_bool(_tally.ghost()).is_false()
	assert_int(_tally.alarms).is_equal(1)


func test_a_found_body_breaks_ghost() -> void:
	var found := {"actor": "GuardA", "body": "GuardB"}
	_tally.observe(_entry(EventKinds.ACTOR_BODY_FOUND, _guard("GuardA"), _guard("GuardB"), found))

	assert_bool(_tally.ghost()).is_false()
	assert_bool(_tally.pacifist()).is_true()


func test_a_direct_kill_breaks_pacifist() -> void:
	_emitted(5, _player, &"damage.ballistic")
	_died(_guard("Guard"), 5)

	assert_int(_tally.kills).is_equal(1)
	assert_bool(_tally.pacifist()).is_false()


func test_the_player_is_decided_by_tag_never_by_name() -> void:
	# Named like the player but untagged: not the player.
	var impostor := _entity("Player")
	_emitted(5, impostor, &"damage.ballistic")
	_died(_guard("GuardA"), 5)
	assert_int(_tally.kills).is_equal(0)
	# A tag added at run time counts from then on, whatever the name.
	ActorState.set_tag(impostor, &"actor.player", true)
	_emitted(6, impostor, &"damage.ballistic")
	_died(_guard("GuardB"), 6)
	assert_int(_tally.kills).is_equal(1)
	# A name alone (an entry without its entity) never attributes.
	_emitted(7, "Hero", &"damage.ballistic")
	_died(_guard("GuardC"), 7)
	assert_int(_tally.kills).is_equal(1)
	# A mission's own player tag.
	var tagged := MissionTally.new(&"actor.hero")
	var hero := _entity("Someone", [&"actor.hero"])
	tagged.observe(_entry(EventKinds.STIMULUS_EMITTED, hero, "", {"id": 8, "type": &"damage.ballistic"}))
	tagged.observe(_entry(EventKinds.ACTOR_DIED, "", _guard("GuardD"), {"by": 8}))
	assert_int(tagged.kills).is_equal(1)


func test_a_barrel_the_player_shot_kills_indirectly() -> void:
	_emitted(5, _player, &"damage.ballistic")
	_emitted(6, "Barrel", &"damage.explosive", 5)
	_died(_guard("Guard"), 6)

	assert_int(_tally.kills).is_equal(1)
	assert_bool(_tally.pacifist()).is_false()


func test_a_fire_the_players_blast_lit_kills_indirectly() -> void:
	_emitted(5, _player, &"damage.ballistic")
	_emitted(6, "Barrel", &"fire", 5)
	# A crate's fire pulses name the stimulus that ignited it as their cause (Flammable).
	_emitted(40, "Crate", &"damage.fire", 6)
	_emitted(41, "Crate", &"damage.fire", 6)
	_died(_guard("Guard"), 41)

	assert_bool(_tally.pacifist()).is_false()


func test_a_turret_the_player_retargeted_kills_indirectly() -> void:
	var command := {"command": &"command.target_guards", "from": "Terminal", "to": "Turret", "sent": true}
	command["stimulus"] = 20
	command["by"] = _player
	_tally.observe(_entry(EventKinds.DEVICE_COMMAND, "Terminal", "Turret", command))
	_emitted(20, "Terminal", &"command.target_guards")
	_emitted(31, "Turret", &"damage.ballistic", 20)
	_died(_guard("Guard"), 31)

	assert_int(_tally.kills).is_equal(1)
	assert_bool(_tally.pacifist()).is_false()


func test_deaths_the_player_did_not_cause_keep_pacifist() -> void:
	_emitted(5, _player, &"damage.ballistic")
	_emitted(7, "Turret", &"damage.ballistic")
	_emitted(8, "Barrel", &"damage.explosive", 7)
	_died(_guard("GuardA"), 7)
	_died(_guard("GuardB"), 8)
	_died(_guard("GuardC"), 0)
	# A command someone else sent.
	var command := {"command": &"command.target_guards", "stimulus": 9, "by": _guard("Operator"), "sent": true}
	_tally.observe(_entry(EventKinds.DEVICE_COMMAND, "Terminal", "Turret", command))
	_emitted(10, "Turret", &"damage.ballistic", 9)
	_died(_guard("GuardD"), 10)

	assert_int(_tally.kills).is_equal(0)
	assert_bool(_tally.pacifist()).is_true()


func test_knockouts_are_counted_and_keep_pacifist() -> void:
	_emitted(5, _player, &"damage.stun")
	var knocked := {"actor": "Guard", "stun": 80.0, "by": 5}
	_tally.observe(_entry(EventKinds.ACTOR_KNOCKED_OUT, _player, _guard("Guard"), knocked))

	assert_int(_tally.knockouts).is_equal(1)
	assert_bool(_tally.pacifist()).is_true()


func test_the_players_own_death_is_no_kill() -> void:
	_emitted(5, _player, &"damage.ballistic")
	_emitted(6, "Barrel", &"damage.explosive", 5)
	_died(_player, 6)

	assert_int(_tally.kills).is_equal(0)


func test_noise_is_not_tracked() -> void:
	_emitted(5, _player, &"noise")
	_emitted(6, "Guard", &"shout", 5)

	assert_bool(_tally.is_attributed(5)).is_false()
	assert_bool(_tally.is_attributed(6)).is_false()


func test_round_trip_keeps_counts_and_attribution() -> void:
	_emitted(5, _player, &"damage.ballistic")
	_died(_guard("GuardA"), 5)
	_awareness("GuardB", "alerted")
	_emitted(6, _player, &"fire")
	var saved := _tally.to_dict()
	var loaded := MissionTally.new()

	loaded.from_dict(saved)
	# The fire the player lit before the save still counts after it.
	var pulse := {"id": 50, "type": &"damage.fire", "cause_id": 6}
	loaded.observe(_entry(EventKinds.STIMULUS_EMITTED, "Crate", "", pulse))
	loaded.observe(_entry(EventKinds.ACTOR_DIED, "", _guard("GuardC"), {"actor": "GuardC", "by": 50}))

	assert_int(loaded.kills).is_equal(2)
	assert_int(loaded.alerts).is_equal(1)
	assert_dict(loaded.to_dict()).contains_keys(["kills", "knockouts", "alarms", "alerts", "bodies_found"])
	assert_bool(loaded.ghost()).is_false()
