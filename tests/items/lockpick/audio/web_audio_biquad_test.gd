extends GdUnitTestSuite
## Unit: WebAudioBiquad uses the same coefficients and difference equation as the bake tool
## (`tools/sfx_gen/lockpick_sfx.py --vectors` printed the expected values; Chrome's
## BiquadFilterNode gave the same outputs to 6 decimals), so the live scrape matches the baked
## formulas (ADR 0108).

const RATE: float = 44100.0
const SIGNAL: Array[float] = [1.0, 0.5, -0.25, 0.0, -1.0, 0.75, 0.0, 0.0, 0.3, -0.6]

# [type, frequency, q, coefficients (b0, b1, b2, a1, a2), outputs for SIGNAL]
const CASES: Array = [
	[
		WebAudioBiquad.Type.BANDPASS,
		2600.0,
		3.0,
		[0.056903760923, 0.0, -0.056903760923, -1.758250434841, 0.886192478155],
		[
			0.056903760923,
			0.128502942848,
			0.104382969079,
			0.041201178939,
			-0.062739231952,
			-0.104145636036,
			-0.070611313483,
			-0.074537114040,
			-0.051408570015,
			-0.058477167332,
		],
	],
	[
		WebAudioBiquad.Type.LOWPASS,
		900.0,
		1.0,
		[0.003883680322, 0.007767360644, 0.003883680322, -1.876639145139, 0.892173866426],
		[
			0.003883680322,
			0.016997467324,
			0.035229635023,
			0.050948616011,
			0.059326607103,
			0.061025009100,
			0.063534112630,
			0.067698444736,
			0.071527180639,
			0.073831923937,
		],
	],
	[
		WebAudioBiquad.Type.HIGHPASS,
		3200.0,
		1.0,
		[0.793281806307, -1.586563612615, 0.793281806307, -1.501172834766, 0.671954390464],
		[
			0.793281806307,
			0.000930388481,
			-0.729972970286,
			-0.303158965424,
			-0.956187719091,
			0.949830936335,
			0.085170419428,
			0.084573806833,
			0.307713805970,
			-0.546836301984,
		],
	],
]


func test_coefficients_match_the_bake_tool() -> void:
	for case: Array in CASES:
		var filter := WebAudioBiquad.new()
		filter.configure(case[0], case[1], case[2], RATE)
		var got: Array[float] = [filter.b0, filter.b1, filter.b2, filter.a1, filter.a2]
		var expected: Array = case[3]
		for i in 5:
			(
				assert_float(got[i])
				. override_failure_message("type %d coefficient %d: %f" % [case[0], i, got[i]])
				. is_equal_approx(expected[i], 1e-10)
			)


func test_outputs_match_the_bake_tool() -> void:
	for case: Array in CASES:
		var filter := WebAudioBiquad.new()
		filter.configure(case[0], case[1], case[2], RATE)
		var expected: Array = case[4]
		for i in SIGNAL.size():
			(
				assert_float(filter.process(SIGNAL[i]))
				. override_failure_message("type %d sample %d" % [case[0], i])
				. is_equal_approx(expected[i], 1e-10)
			)


func test_block_processing_matches_sample_processing() -> void:
	var single := WebAudioBiquad.new()
	var block := WebAudioBiquad.new()
	single.configure(WebAudioBiquad.Type.BANDPASS, 2600.0, 3.0, RATE)
	block.configure(WebAudioBiquad.Type.BANDPASS, 2600.0, 3.0, RATE)
	var buffer := PackedFloat32Array(SIGNAL + SIGNAL)
	# Two calls, so the state carries across blocks.
	block.process_range(buffer, 0, 7)
	block.process_range(buffer, 7, buffer.size())
	var input: Array[float] = SIGNAL + SIGNAL
	for i in input.size():
		assert_float(buffer[i]).is_equal_approx(single.process(input[i]), 1e-6)
