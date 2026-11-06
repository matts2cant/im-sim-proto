extends GdUnitTestSuite
## Unit: CommsRules (ADR 0072): who shouts and radios, how far shouts and radio calls carry, how the
## alarm is answered; and the barks for the new search reasons (BarkLines).

const COMMS: CommsConfig = preload("res://actors/guard/guard_comms.tres")
const BARKS: BarkLines = preload("res://actors/guard/guard_barks.tres")
const SHOUT: Receptron = preload("res://actors/common/awareness/receptrons/heard_shout.tres")

const UNAWARE := AwarenessModel.State.UNAWARE
const SUSPICIOUS := AwarenessModel.State.SUSPICIOUS
const SEARCHING := AwarenessModel.State.SEARCHING
const ALERTED := AwarenessModel.State.ALERTED


func test_shouts_and_radios_only_on_entering_alerted() -> void:
	assert_bool(CommsRules.should_shout(UNAWARE, ALERTED)).is_true()
	assert_bool(CommsRules.should_shout(SEARCHING, ALERTED)).is_true()
	assert_bool(CommsRules.should_shout(UNAWARE, SEARCHING)).is_false()
	assert_bool(CommsRules.should_shout(ALERTED, SEARCHING)).is_false()
	assert_bool(CommsRules.should_radio(UNAWARE, ALERTED, true)).is_true()
	assert_bool(CommsRules.should_radio(UNAWARE, ALERTED, false)).is_false()
	assert_bool(CommsRules.should_radio(UNAWARE, SUSPICIOUS, true)).is_false()


func test_a_shout_carries_17_m_of_path() -> void:
	var margin := SHOUT.min_intensity
	assert_float(COMMS.shout_loudness).is_equal(18.0)
	assert_bool(CommsRules.shout_heard(COMMS.shout_loudness, 12.0, margin)).is_true()
	assert_bool(CommsRules.shout_heard(COMMS.shout_loudness, 20.0, margin)).is_false()


func test_radio_carries_30_m_straight() -> void:
	assert_bool(CommsRules.radio_heard(25.0, COMMS.radio_range)).is_true()
	assert_bool(CommsRules.radio_heard(35.0, COMMS.radio_range)).is_false()


func test_the_alarm_sends_unaware_and_suspicious_characters_searching() -> void:
	assert_bool(CommsRules.alarm_searches(UNAWARE)).is_true()
	assert_bool(CommsRules.alarm_searches(SUSPICIOUS)).is_true()
	assert_bool(CommsRules.alarm_searches(SEARCHING)).is_false()
	assert_bool(CommsRules.alarm_searches(ALERTED)).is_false()


func test_barks_follow_the_reason_of_a_search() -> void:
	assert_array(BARKS.lines_for(UNAWARE, SEARCHING, "body")).contains(["Man down!"])
	assert_array(BARKS.lines_for(UNAWARE, SEARCHING, "shout")).is_equal(BARKS.called)
	assert_array(BARKS.lines_for(UNAWARE, SEARCHING, "radio")).is_equal(BARKS.called)
	assert_array(BARKS.lines_for(UNAWARE, SEARCHING, "woken")).is_equal(BARKS.woken)
	assert_array(BARKS.lines_for(ALERTED, SEARCHING, "lost")).is_equal(BARKS.searching)
