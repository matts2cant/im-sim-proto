extends GdUnitTestSuite
## Unit: the baked lockpicking one-shots (tools/sfx_gen/lockpick_sfx.py, ADR 0108). Every cue's files
## exist and load as 44.1 kHz mono 16-bit PCM, last as long as the prototype's longest part
## (delay + dur + 0.02 s), peak at the prototype's level, and noisy cues have three different
## variants. sounds.tres maps every cue to its files.

const DIR := "res://items/lockpick/audio/sfx/"
const SOUNDS: LockpickSounds = preload("res://items/lockpick/audio/sounds.tres")
const MASTER: float = 0.7

# cue: [length s, loudest part's vol, sum of the parts' vols, noisy]
const CUES: Dictionary = {
	"click": [0.06, 0.45, 0.63, true],
	"click_muted": [0.06, 0.12, 0.17, true],
	"tick": [0.04, 0.22, 0.22, true],
	"clunk": [0.16, 0.45, 0.75, true],
	"creak": [0.30, 0.12, 0.12, false],
	"jam": [0.18, 0.5, 0.85, true],
	"snap": [0.20, 0.7, 1.0, true],
	"drop": [0.10, 0.12, 0.22, false],
	"open": [0.26, 0.4, 1.15, true],
	"relock": [0.505, 0.12, 0.78, true],
}


func test_every_cue_is_pcm_44k_mono_with_the_prototype_length() -> void:
	for cue: String in CUES:
		for path in _files(cue):
			var stream := load(path) as AudioStreamWAV
			assert_object(stream).override_failure_message(path).is_not_null()
			assert_int(stream.format).override_failure_message(path).is_equal(AudioStreamWAV.FORMAT_16_BITS)
			assert_int(stream.mix_rate).override_failure_message(path).is_equal(44100)
			assert_bool(stream.stereo).override_failure_message(path).is_false()
			var seconds := stream.data.size() / 2.0 / 44100.0
			assert_float(seconds).override_failure_message("%s lasts %.4f s" % [path, seconds]).is_equal_approx(
				CUES[cue][0], 0.001
			)


func test_every_cue_peaks_at_the_prototype_level() -> void:
	for cue: String in CUES:
		var spec: Array = CUES[cue]
		# At least 40% of the loudest part through the master gain; at most twice the sum of the
		# parts (filtered noise can peak above 1), never clipping past full scale.
		var low: float = MASTER * spec[1] * 0.4
		var high: float = minf(MASTER * spec[2] * 2.0, 1.0)
		for path in _files(cue):
			var peak := _peak((load(path) as AudioStreamWAV).data)
			(
				assert_float(peak)
				. override_failure_message("%s peak %.3f not in %.3f..%.3f" % [path, peak, low, high])
				. is_between(low, high)
			)


func test_noisy_cue_variants_differ() -> void:
	for cue: String in CUES:
		if not CUES[cue][3]:
			continue
		var data: Array[PackedByteArray] = []
		for path in _files(cue):
			data.append((load(path) as AudioStreamWAV).data)
		assert_int(data.size()).is_equal(3)
		(
			assert_bool(data[0] != data[1] and data[1] != data[2] and data[0] != data[2])
			. override_failure_message(cue)
			. is_true()
		)


func test_sounds_maps_every_cue_to_its_files() -> void:
	assert_int(SOUNDS.cues.size()).is_equal(CUES.size())
	for cue: String in CUES:
		var stream: AudioStream = SOUNDS.cues.get(StringName(cue))
		assert_object(stream).override_failure_message(cue).is_not_null()
		var paths: Array[String] = []
		if stream is AudioStreamRandomizer:
			var randomizer := stream as AudioStreamRandomizer
			for i in randomizer.streams_count:
				paths.append(randomizer.get_stream(i).resource_path)
			# Variants vary only in noise: no pitch or volume randomisation on top.
			assert_float(randomizer.random_pitch).is_equal(1.0)
			assert_float(randomizer.random_volume_offset_db).is_equal(0.0)
		else:
			paths.append(stream.resource_path)
		assert_array(paths).override_failure_message(cue).contains_exactly(_files(cue))


func _files(cue: String) -> Array[String]:
	if CUES[cue][3]:
		return [DIR + cue + "_1.wav", DIR + cue + "_2.wav", DIR + cue + "_3.wav"]
	return [DIR + cue + ".wav"]


func _peak(data: PackedByteArray) -> float:
	var peak := 0
	for i in range(0, data.size(), 2):
		peak = maxi(peak, absi(data.decode_s16(i)))
	return peak / 32767.0
