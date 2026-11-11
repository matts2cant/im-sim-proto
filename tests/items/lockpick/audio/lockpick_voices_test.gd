extends GdUnitTestSuite
## Unit: the continuous lockpicking voices (LockpickVoices, ADR 0108) follow the prototype's
## audioFrame(): the strain is a triangle at 260 + 900 s Hz with gain 0.09 s (s = strain above 0.12),
## the scrape a bandpass on white noise centred at 2000 + 1600 tension Hz with gain 0.16 x scraping,
## both through the 0.7 master gain and smoothed towards their targets.

const SOUNDS: LockpickSounds = preload("res://items/lockpick/audio/sounds.tres")
const RATE: int = 44100
const HALF_SECOND: int = 22050
const QUARTER_SECOND: int = 11025
const POINT_THREE_SECONDS: int = 13230

var _voices: LockpickVoices


func before_test() -> void:
	_voices = LockpickVoices.new(SOUNDS)


func test_strain_plays_its_pitch_and_level() -> void:
	_voices.set_strain(0.5)
	_voices.render(HALF_SECOND)  # settle: 10 time constants
	var samples := _voices.render(RATE)
	# 260 + 0.5 * 900 = 710 Hz; peak 0.5 * 0.09 * 0.7 = 0.0315; a triangle's RMS is peak / sqrt(3).
	assert_int(_upward_crossings(samples)).is_between(708, 712)
	assert_float(_peak(samples)).is_equal_approx(0.0315, 0.0005)
	assert_float(_rms(samples)).is_equal_approx(0.0315 / sqrt(3.0), 0.0005)


func test_scrape_centre_follows_tension_and_level_follows_scraping() -> void:
	_voices.set_scrape(1.0, 0.0)
	_voices.render(HALF_SECOND)  # settle: 10 time constants
	assert_float(_voices.get_scrape_frequency()).is_equal_approx(2000.0, 1.0)
	var low := _voices.render(RATE)
	_voices.set_scrape(1.0, 1.0)
	_voices.render(HALF_SECOND)
	assert_float(_voices.get_scrape_frequency()).is_equal_approx(3600.0, 1.0)
	var high := _voices.render(RATE)
	# A higher band crosses zero more often (the filter itself is checked in web_audio_biquad_test).
	assert_int(_upward_crossings(high)).is_greater(_upward_crossings(low) + 500)
	# Uniform noise (variance 1/3) through a Q 3 bandpass at 2000 Hz (noise bandwidth
	# pi/2 x 2000/3 Hz) at gain 0.16 x 0.7: RMS about 0.0134.
	var expected := 0.16 * 0.7 * sqrt(1.0 / 3.0 * (PI / 2.0 * 2000.0 / 3.0) / (RATE / 2.0))
	assert_float(_rms(low)).is_equal_approx(expected, expected * 0.15)
	# Half the scraping, half the level.
	_voices.set_scrape(0.5, 0.0)
	_voices.render(HALF_SECOND)
	assert_float(_rms(_voices.render(RATE))).is_equal_approx(expected * 0.5, expected * 0.1)


func test_no_scraping_and_low_strain_fade_to_silence() -> void:
	_voices.set_scrape(1.0, 0.5)
	_voices.set_strain(0.8)
	assert_float(_peak(_voices.render(QUARTER_SECOND))).is_greater(0.01)
	_voices.set_scrape(0.0, 0.7)
	_voices.set_strain(0.1)  # below the 0.12 threshold
	var fade := _voices.render(HALF_SECOND)
	var tail := fade.slice(POINT_THREE_SECONDS)  # 7.5 strain time constants
	assert_float(_peak(tail)).is_less(1e-4)
	# Then the voices go idle and render exact silence.
	_voices.render(RATE)
	assert_bool(_voices.is_active()).is_false()
	assert_float(_peak(_voices.render(1024))).is_equal(0.0)


func test_stop_fades_both_voices_out_smoothly() -> void:
	_voices.set_scrape(1.0, 0.5)
	_voices.set_strain(0.8)
	_voices.render(QUARTER_SECOND)
	_voices.stop()
	var fade := _voices.render(HALF_SECOND)
	# No click: the first samples after stop are still near the old level, then it decays.
	assert_float(_peak(fade.slice(0, 64))).is_greater(0.01)
	assert_float(_peak(fade.slice(POINT_THREE_SECONDS))).is_less(1e-4)


func _upward_crossings(samples: PackedFloat32Array) -> int:
	var count := 0
	for i in range(1, samples.size()):
		if samples[i - 1] < 0.0 and samples[i] >= 0.0:
			count += 1
	return count


func _peak(samples: PackedFloat32Array) -> float:
	var peak := 0.0
	for value in samples:
		peak = maxf(peak, absf(value))
	return peak


func _rms(samples: PackedFloat32Array) -> float:
	var sum := 0.0
	for value in samples:
		sum += value * value
	return sqrt(sum / samples.size())
