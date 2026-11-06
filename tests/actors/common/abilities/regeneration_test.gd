extends GdUnitTestSuite
## Integration: Regeneration and Run Silent on a minimal character built in code (no player):
## Regeneration's `heal` pulses (2 every 0.5 s) heal a hurt leg through the shared `heal` receptron and
## stop when nothing is hurt while the drain goes on; Run Silent silences MovementNoise footsteps.

const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const Abilities := preload("res://tests/actors/common/abilities/ability_fixtures.gd")
const HEAL: Receptron = preload("res://actors/common/body/receptrons/heal.tres")

var _world: Node3D
var _body: CharacterBody3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_world = auto_free(Node3D.new())
	add_child(_world)
	Characters.floor_box(_world, 0.0, &"metal")
	var extra: Array[Receptron] = [HEAL]
	var components: Array[StringName] = [Characters.MOVEMENT_NOISE]
	_body = Characters.character(_world, "Walker", Vector3(0, 0, 0), components, PhysicsLayers.ACTORS, extra)
	Abilities.equip(_body)
	await Fixtures.frames(get_tree(), 5)


func test_regeneration_heals_a_hurt_leg_over_time_and_costs_energy() -> void:
	var parts := Characters.body_parts(_body)
	parts.take_damage(&"damage.ballistic", 20.0, &"leg_l")
	var hurt := parts.health(&"leg_l")
	Augmentations.of(_body).activate(&"regeneration")

	# 70 frames (1.17 s): two pulses of 2.
	await Fixtures.frames(get_tree(), 70)

	assert_float(parts.health(&"leg_l")).is_equal_approx(hurt + 4.0, 0.01)
	assert_array(EventLog.find(&"actor.healed")).has_size(2)
	assert_float(Energy.of(_body).current()).is_equal_approx(100.0 - 5.0 * 70.0 / 60.0, 0.2)


func test_regeneration_stops_emitting_when_nothing_is_hurt_but_keeps_draining() -> void:
	var parts := Characters.body_parts(_body)
	parts.take_damage(&"damage.ballistic", 3.0, &"leg_l")
	Augmentations.of(_body).activate(&"regeneration")

	await Fixtures.frames(get_tree(), 130)

	assert_float(parts.health(&"leg_l")).is_equal(parts.model.max_health(&"leg_l"))
	var heals := EventLog.find(&"stimulus.emitted").filter(
		func(entry: EventLogEntry) -> bool: return entry.data["type"] == &"heal"
	)
	assert_array(heals).has_size(2)
	assert_bool(Augmentations.of(_body).is_active(&"regeneration")).is_true()
	assert_float(Energy.of(_body).current()).is_less(92.0)


func test_run_silent_removes_footstep_noise() -> void:
	var noise := _body.get_node(String(Characters.MOVEMENT_NOISE)) as MovementNoise
	assert_float(noise.footstep(MovementNoiseRules.Stance.SPRINT)).is_greater(20.0)
	EventLog.clear()
	StimulusSystem.clear()
	Augmentations.of(_body).activate(&"run_silent")

	assert_float(noise.footstep(MovementNoiseRules.Stance.SPRINT)).is_equal(0.0)
	assert_float(noise.landed(9.0)).is_equal(0.0)
	await Fixtures.frames(get_tree(), 2)
	assert_array(EventLog.find(&"actor.footstep")).is_empty()
	assert_array(EventLog.find(&"stimulus.emitted")).is_empty()


func test_speed_enhancement_makes_landings_louder() -> void:
	var noise := _body.get_node(String(Characters.MOVEMENT_NOISE)) as MovementNoise
	var plain := noise.landed(9.0)
	Augmentations.of(_body).activate(&"speed_enhancement")

	assert_float(noise.landed(9.0)).is_equal_approx(plain * 1.5, 0.001)
