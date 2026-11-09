extends GdUnitTestSuite
## MissionTally (ADR 0087), pure: tallies and badges from EventLog entries. Ghost is broken by an
## Alerted guard, an alarm or a found body (Suspicious is fine); Pacifist by any death the player
## caused, directly or down a stimulus cause chain (a shot barrel's blast, the fire it lit, a turret
## the player retargeted), never by a knockout. Entries are built by hand, as EventLog records them.

const PLAYER := "Player"

var _tally: MissionTally


func before_test() -> void:
	var names: Array[String] = [PLAYER]
	_tally = MissionTally.new(names)


func _entry(kind: StringName, source: String, target: String, data: Dictionary) -> EventLogEntry:
	return EventLogEntry.new(0, kind, source, target, data)


func _emitted(id: int, source: String, type: StringName, cause_id: int = 0) -> void:
	var data := {"id": id, "type": type, "source": source, "cause_id": cause_id}
	_tally.observe(_entry(&"stimulus.emitted", source, "", data))


func _died(actor: String, by: int) -> void:
	_tally.observe(_entry(&"actor.died", "", actor, {"actor": actor, "by": by}))


func _awareness(actor: String, to: String) -> void:
	_tally.observe(_entry(&"actor.awareness", actor, "", {"actor": actor, "from": "unaware", "to": to}))


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
	_tally.observe(_entry(&"alarm.raised", "Camera", "Controller", raised))
	var again := raised.duplicate()
	again["again"] = true
	_tally.observe(_entry(&"alarm.raised", "Camera", "Controller", again))

	assert_bool(_tally.ghost()).is_false()
	assert_int(_tally.alarms).is_equal(1)


func test_a_found_body_breaks_ghost() -> void:
	_tally.observe(_entry(&"actor.body_found", "GuardA", "GuardB", {"actor": "GuardA", "body": "GuardB"}))

	assert_bool(_tally.ghost()).is_false()
	assert_bool(_tally.pacifist()).is_true()


func test_a_direct_kill_breaks_pacifist() -> void:
	_emitted(5, PLAYER, &"damage.ballistic")
	_died("Guard", 5)

	assert_int(_tally.kills).is_equal(1)
	assert_bool(_tally.pacifist()).is_false()


func test_a_barrel_the_player_shot_kills_indirectly() -> void:
	_emitted(5, PLAYER, &"damage.ballistic")
	_emitted(6, "Barrel", &"damage.explosive", 5)
	_died("Guard", 6)

	assert_int(_tally.kills).is_equal(1)
	assert_bool(_tally.pacifist()).is_false()


func test_a_fire_the_players_blast_lit_kills_indirectly() -> void:
	_emitted(5, PLAYER, &"damage.ballistic")
	_emitted(6, "Barrel", &"fire", 5)
	# A crate's fire pulses name the stimulus that ignited it as their cause (Flammable).
	_emitted(40, "Crate", &"damage.fire", 6)
	_emitted(41, "Crate", &"damage.fire", 6)
	_died("Guard", 41)

	assert_bool(_tally.pacifist()).is_false()


func test_a_turret_the_player_retargeted_kills_indirectly() -> void:
	var command := {"command": &"command.target_guards", "from": "Terminal", "to": "Turret", "sent": true}
	command["stimulus"] = 20
	command["by"] = PLAYER
	_tally.observe(_entry(&"device.command", "Terminal", "Turret", command))
	_emitted(20, "Terminal", &"command.target_guards")
	_emitted(31, "Turret", &"damage.ballistic", 20)
	_died("Guard", 31)

	assert_int(_tally.kills).is_equal(1)
	assert_bool(_tally.pacifist()).is_false()


func test_deaths_the_player_did_not_cause_keep_pacifist() -> void:
	_emitted(5, PLAYER, &"damage.ballistic")
	_emitted(7, "Turret", &"damage.ballistic")
	_emitted(8, "Barrel", &"damage.explosive", 7)
	_died("GuardA", 7)
	_died("GuardB", 8)
	_died("GuardC", 0)
	# A command someone else sent.
	var command := {"command": &"command.target_guards", "stimulus": 9, "by": "Operator", "sent": true}
	_tally.observe(_entry(&"device.command", "Terminal", "Turret", command))
	_emitted(10, "Turret", &"damage.ballistic", 9)
	_died("GuardD", 10)

	assert_int(_tally.kills).is_equal(0)
	assert_bool(_tally.pacifist()).is_true()


func test_knockouts_are_counted_and_keep_pacifist() -> void:
	_emitted(5, PLAYER, &"damage.stun")
	_tally.observe(_entry(&"actor.knocked_out", PLAYER, "Guard", {"actor": "Guard", "stun": 80.0, "by": 5}))

	assert_int(_tally.knockouts).is_equal(1)
	assert_bool(_tally.pacifist()).is_true()


func test_the_players_own_death_is_no_kill() -> void:
	_emitted(5, PLAYER, &"damage.ballistic")
	_emitted(6, "Barrel", &"damage.explosive", 5)
	_died(PLAYER, 6)

	assert_int(_tally.kills).is_equal(0)


func test_noise_is_not_tracked() -> void:
	_emitted(5, PLAYER, &"noise")
	_emitted(6, "Guard", &"shout", 5)

	assert_bool(_tally.is_attributed(5)).is_false()
	assert_bool(_tally.is_attributed(6)).is_false()


func test_round_trip_keeps_counts_and_attribution() -> void:
	_emitted(5, PLAYER, &"damage.ballistic")
	_died("GuardA", 5)
	_awareness("GuardB", "alerted")
	_emitted(6, PLAYER, &"fire")
	var saved := _tally.to_dict()
	var names: Array[String] = [PLAYER]
	var loaded := MissionTally.new(names)

	loaded.from_dict(saved)
	# The fire the player lit before the save still counts after it.
	loaded.observe(_entry(&"stimulus.emitted", "Crate", "", {"id": 50, "type": &"damage.fire", "cause_id": 6}))
	loaded.observe(_entry(&"actor.died", "", "GuardC", {"actor": "GuardC", "by": 50}))

	assert_int(loaded.kills).is_equal(2)
	assert_int(loaded.alerts).is_equal(1)
	assert_dict(loaded.to_dict()).contains_keys(["kills", "knockouts", "alarms", "alerts", "bodies_found"])
	assert_bool(loaded.ghost()).is_false()
