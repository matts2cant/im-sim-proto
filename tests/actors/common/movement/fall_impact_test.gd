extends GdUnitTestSuite
## Integration: FallImpact on a minimal CharacterBody3D emits `damage.fall` (intensity = impact
## speed) on itself; the `fall_damage` receptron turns it into leg damage, the generic `body_damage`
## receptron ignores it (own stimulus), and a receptron change alters the outcome.

const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")

var _root: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	add_child(_root)
	Characters.floor_box(_root)


func test_ten_metre_fall_hurts_both_legs_by_the_formula() -> void:
	# 10 m at 1 g lands at about 14 m/s: (14 - 10) x 8 = 32 per leg.
	var walker := _faller(10.0)

	await Fixtures.frames(get_tree(), 120)

	var falls := _falls()
	assert_array(falls).has_size(1)
	var impact: float = falls[0].data["intensity"]
	assert_float(impact).is_equal_approx(14.0, 0.3)
	assert_str(falls[0].source).is_equal("Walker")
	assert_str(falls[0].target).is_equal("Walker")
	var damaged := EventLog.find(&"actor.damaged")
	assert_array(damaged).has_size(2)
	var body := Characters.body_parts(walker)
	for leg: StringName in [&"leg_l", &"leg_r"]:
		assert_float(body.health(leg)).is_equal_approx(body.profile.leg_health - (impact - 10.0) * 8.0, 0.001)
	assert_float(body.health(&"torso")).is_equal(body.profile.torso_health)


func test_short_fall_reports_but_does_not_hurt() -> void:
	_faller(3.0)

	await Fixtures.frames(get_tree(), 60)

	assert_array(_falls()).has_size(1)
	assert_array(EventLog.find(&"actor.damaged")).is_empty()


func test_a_receptron_change_alters_fall_damage() -> void:
	# An augmentation that swaps the fall receptron for one with a higher threshold.
	var walker := _faller(10.0)
	var effect := BodyDamageEffect.new()
	effect.threshold = 16.0
	effect.scale = 16.0
	var hardened := Fixtures.receptron(&"damage.fall", [effect], "fall_damage_hardened")
	hardened.include_self = true
	var receiver := Fixtures.receiver_of(walker)
	var receptrons: Array[Receptron] = [Characters.BODY_DAMAGE, hardened]
	receiver.receptrons = receptrons

	await Fixtures.frames(get_tree(), 120)

	assert_array(_falls()).has_size(1)
	assert_array(EventLog.find(&"actor.damaged")).is_empty()


func test_only_the_fall_receptron_reacts_to_a_fall() -> void:
	# body_damage also matches `damage.fall` by type, but skips the entity's own stimulus.
	_faller(10.0)

	await Fixtures.frames(get_tree(), 120)

	var fired := EventLog.find(&"receptron.fired").filter(
		func(entry: EventLogEntry) -> bool: return entry.target == "Walker"
	)
	assert_array(fired).has_size(1)
	assert_str(fired[0].data["receptron"]).is_equal("fall_damage")


func _faller(height: float) -> CharacterBody3D:
	return Characters.character(_root, "Walker", Vector3(0, height, 0), [Characters.FALL_IMPACT])


func _falls() -> Array[EventLogEntry]:
	return EventLog.find(&"stimulus.emitted").filter(
		func(entry: EventLogEntry) -> bool: return entry.data["type"] == &"damage.fall"
	)
