extends GdUnitTestSuite
## Scenario (ADR 0087): in the mission fixture the player shoots an explosive barrel with its starting
## pistol; the blast kills a wounded guard standing beside it. The death's cause chain (the guard's
## `actor.died` names the blast, whose cause is the player's shot) reaches the player: one kill,
## Pacifist lost. The same guard killed by a barrel nobody the player started blew up keeps Pacifist.
## Fixture-local: player at (0, 0, 10) facing -Z, barrel centre (0, 0.45, 3) (7 m ahead), the guard
## 1 m beside it (gap ~0.4 m surface to surface, inside the 4 m blast).

const Wait := preload("res://tests/helpers/wait.gd")
const Missions := preload("res://tests/levels/mission/mission_kit/mission_helpers.gd")
const Saves := preload("res://tests/core/save/save_test_helpers.gd")
const BARREL := preload("res://objects/explosive_barrel/explosive_barrel.tscn")
const GUARD := preload("res://actors/guard/guard_baton.tscn")
const BARREL_AT := Vector3(0, 0.45, 3)
const GUARD_AT := Vector3(1.0, 0, 3)

var _original: Node


func before_test() -> void:
	_original = get_tree().current_scene
	EventLog.clear()
	StimulusSystem.clear()
	DebugPanel.set_open(false)


func after_test() -> void:
	Saves.close_level(get_tree(), _original)
	StimulusSystem.clear()


# The fixture with a barrel and a guard wounded (torso at 10 of 80, no cause) beside it.
func _setup() -> Node3D:
	var level := await Missions.open(get_tree())
	await Missions.close_briefing(level)
	var barrel := BARREL.instantiate() as Node3D
	barrel.name = "Barrel"
	level.add_child(barrel)
	barrel.global_position = Missions.at(BARREL_AT)
	var guard := GUARD.instantiate() as Node3D
	guard.name = "Guard"
	level.add_child(guard)
	guard.global_position = Missions.at(GUARD_AT)
	(guard.get_node("BodyParts") as BodyParts).take_damage(&"damage.ballistic", 70.0, BodyDamageModel.TORSO)
	await Wait.frames(get_tree(), 5)
	return level


func test_a_barrel_the_player_shot_kills_a_guard_and_breaks_pacifist() -> void:
	var level := await _setup()
	var mission := Missions.mission(level)
	var player := Missions.player(level)
	# Look at the barrel's centre from the eye (1.65 m): 1.2 m down over 7 m.
	var pitch := -atan2(1.65 - BARREL_AT.y, 10.0 - BARREL_AT.z)
	player.load_state(
		{"position": Missions.at(Vector3(0, 0, 10)), "yaw": 0.0, "pitch": pitch, "velocity": Vector3.ZERO}
	)
	player.inventory.hold(player.inventory.inventory.stacks_of(&"pistol")[0])
	player.weapons.seed_rng(7)
	await Wait.frames(get_tree(), 3)
	player.weapons.settle()

	assert_int(player.weapons.trigger()).is_equal(WeaponState.Result.FIRED)
	await Wait.frames(get_tree(), 10)

	assert_int(EventLog.find(&"object.exploded").size()).is_equal(1)
	assert_bool(ActorState.is_dead(level.get_node("Guard"))).is_true()
	assert_int(mission.tally.kills).is_equal(1)
	assert_bool(mission.tally.pacifist()).is_false()
	assert_bool(mission.results()["pacifist"]).is_false()


func test_a_blast_the_player_did_not_start_keeps_pacifist() -> void:
	var level := await _setup()
	var mission := Missions.mission(level)
	var barrel := level.get_node("Barrel")

	(barrel.get_node("Explosive") as Explosive).explode(null)
	await Wait.frames(get_tree(), 10)

	assert_bool(ActorState.is_dead(level.get_node("Guard"))).is_true()
	assert_int(mission.tally.kills).is_equal(0)
	assert_bool(mission.tally.pacifist()).is_true()
