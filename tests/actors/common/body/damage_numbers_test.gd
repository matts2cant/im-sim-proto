extends GdUnitTestSuite
## DamageNumbers on a minimal character built from the body components (no Hitboxes, no dummy
## script): a number per hit, stun and knockout, alternating sides above the entity, rising and
## fading out, cleared when the body is restored (BodyParts.reset()).

const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const Wait := preload("res://tests/helpers/wait.gd")
const CONFIG: DamageNumbersConfig = preload("res://actors/common/body/damage_numbers.tres")
const FEET := Vector3(0, 0, 520)

var _character: CharacterBody3D
var _numbers: DamageNumbers


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	var world := auto_free(Node3D.new()) as Node3D
	add_child(world)
	_character = Characters.character(world, "Subject", FEET, [])
	_numbers = DamageNumbers.new()
	_numbers.name = "DamageNumbers"
	_numbers.config = CONFIG
	_character.add_child(_numbers)


func test_hits_stun_and_knockout_show_their_numbers() -> void:
	var body := Characters.body_parts(_character)

	body.take_damage(&"damage.ballistic", 25.0, &"torso")
	body.take_damage(&"damage.blunt", 12.5, &"arm_l")
	body.take_damage(&"damage.stun", 100.0)

	var texts := Array(_numbers.texts())
	# The dummy profile knocks out at 60 stun: the stun number, then KO.
	assert_array(texts).contains_exactly(["torso 25", "arm_l 12.5", "stun 100", "KO"])
	var labels := _numbers.labels()
	assert_object(labels[0].modulate).is_equal(CONFIG.damage_color)
	assert_object(labels[2].modulate).is_equal(CONFIG.stun_color)
	assert_object(labels[3].modulate).is_equal(CONFIG.knockout_color)


func test_numbers_alternate_sides_above_an_entity_without_hitboxes() -> void:
	var body := Characters.body_parts(_character)

	body.take_damage(&"damage.ballistic", 10.0, &"torso")
	body.take_damage(&"damage.ballistic", 10.0, &"torso")

	var labels := _numbers.labels()
	var anchor := FEET + Vector3.UP * CONFIG.fallback_height
	assert_vector(labels[0].global_position).is_equal_approx(
		anchor + Vector3(CONFIG.side_offset, CONFIG.lift, 0), Vector3.ONE * 0.001
	)
	assert_vector(labels[1].global_position).is_equal_approx(
		anchor + Vector3(-CONFIG.side_offset, CONFIG.lift + CONFIG.step_height, 0), Vector3.ONE * 0.001
	)


func test_numbers_rise_fade_and_go() -> void:
	var body := Characters.body_parts(_character)
	body.take_damage(&"damage.ballistic", 10.0, &"torso")
	var label := _numbers.labels()[0]
	var start := label.position.y

	await Wait.frames(get_tree(), roundi(CONFIG.lifetime * 0.5 * 60.0))
	assert_float(label.position.y).is_greater(start + CONFIG.rise * 0.2)
	assert_float(label.modulate.a).is_less(1.0)

	await Wait.frames(get_tree(), roundi(CONFIG.lifetime * 0.5 * 60.0) + 6)
	assert_array(_numbers.labels()).is_empty()


func test_restoring_the_body_clears_them() -> void:
	var body := Characters.body_parts(_character)
	body.take_damage(&"damage.ballistic", 10.0, &"torso")
	assert_array(_numbers.labels()).has_size(1)

	body.reset()

	assert_array(_numbers.labels()).is_empty()
