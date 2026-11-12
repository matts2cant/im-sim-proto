extends GdUnitTestSuite
## Integration: the LockpickAudio node (ADR 0108), the API the lockpicking minigame calls. Every cue
## plays on its own pooled player (overlapping cues never cut each other off), an unknown cue only
## warns, the continuous voices go silent with no scraping and low strain, and stop_all silences
## everything. Non-positional players on the Effects bus (ADR 0124).

const CUES: Array[StringName] = [
	&"click",
	&"click_muted",
	&"tick",
	&"clunk",
	&"creak",
	&"jam",
	&"snap",
	&"drop",
	&"open",
	&"relock",
]

var _audio: LockpickAudio


func before_test() -> void:
	_audio = auto_free(LockpickAudio.new())
	add_child(_audio)


func test_every_cue_plays_on_its_own_player() -> void:
	for cue in CUES:
		_audio.play(cue)
	var playing: Array[AudioStream] = []
	for player in _players():
		assert_str(player.bus).is_equal(String(GameSettings.EFFECTS_BUS))
		if player.playing:
			playing.append(player.stream)
	# The pool has 6 players: the last 6 cues are all still playing, none cut off by the next.
	assert_int(playing.size()).is_equal(_audio.pool_size)
	for cue: StringName in CUES.slice(CUES.size() - _audio.pool_size):
		assert_bool(playing.has(_audio.sounds.cues[cue])).override_failure_message(cue).is_true()


func test_unknown_cue_warns_and_plays_nothing() -> void:
	assert_error(func() -> void: _audio.play(&"whistle")).is_push_warning("LockpickAudio: unknown cue 'whistle'")
	assert_bool(_audio.is_playing_one_shot()).is_false()


func test_stop_all_silences_everything() -> void:
	_audio.play(&"snap")
	_audio.play(&"creak")
	_audio.set_scrape(1.0, 0.5)
	_audio.set_strain(0.9)
	_audio.voices.render(4410)
	_audio.stop_all()
	assert_bool(_audio.is_playing_one_shot()).is_false()
	_audio.voices.render(22050)
	assert_bool(_audio.voices.is_active()).is_false()


func test_no_scraping_and_low_strain_are_silent_after_smoothing() -> void:
	_audio.set_scrape(1.0, 0.3)
	_audio.set_strain(0.6)
	_audio.voices.render(4410)
	_audio.set_scrape(0.0, 0.3)
	_audio.set_strain(0.1)
	_audio.voices.render(22050)
	assert_bool(_audio.voices.is_active()).is_false()
	var peak := 0.0
	for value in _audio.voices.render(2048):
		peak = maxf(peak, absf(value))
	assert_float(peak).is_equal(0.0)


func test_voices_stream_to_a_generator() -> void:
	var voice_player := _audio.get_node("Voices") as AudioStreamPlayer
	assert_object(voice_player.stream).is_instanceof(AudioStreamGenerator)
	assert_str(voice_player.bus).is_equal(String(GameSettings.EFFECTS_BUS))
	_audio.set_strain(0.5)
	# Whatever room the generator has is filled without errors (none in a headless run may be free).
	assert_int(_audio.fill()).is_greater_equal(0)


func _players() -> Array[AudioStreamPlayer]:
	var players: Array[AudioStreamPlayer] = []
	for child in _audio.get_children():
		if child is AudioStreamPlayer and child.name.begins_with("OneShot"):
			players.append(child)
	return players
