class_name LockpickAudio
extends Node
## The lockpicking minigame's sounds, heard by the player directly (non-positional, at the HTML
## prototype's mix; [ADR 0108](../../../design/decisions/0108-lockpick-sounds.md)).
## - One-shots: `play(cue)` plays a baked cue from `sounds.cues` (a random variant for noisy cues)
##   on a small pool of players, so overlapping cues never cut each other off.
## - Continuous voices: `set_scrape()` and `set_strain()` set targets for the scrape and strain
##   (`LockpickVoices`), synthesised live into an AudioStreamGenerator filled in `_process`.
## Sound only: guards hear lockpicking through noise stimuli the minigame emits, not through this.

const DEFAULT_SOUNDS: LockpickSounds = preload("res://items/lockpick/audio/sounds.tres")
## Generator buffer: short, so the voices follow the controls closely (about 46 ms once rounded
## up to a power of two of frames).
const GENERATOR_BUFFER_SECONDS: float = 0.03

@export var sounds: LockpickSounds = DEFAULT_SOUNDS
## The project has no bus layout: everything plays on Master.
@export var bus: StringName = &"Master"
## One-shot players; the oldest is reused when all are busy.
@export_range(1, 16) var pool_size: int = 6

var voices: LockpickVoices

var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _voice_player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _frames := PackedVector2Array()


func _ready() -> void:
	_ensure_voices()
	for i in pool_size:
		var player := AudioStreamPlayer.new()
		player.name = "OneShot%d" % i
		player.bus = bus
		add_child(player)
		_players.append(player)
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = sounds.sample_rate
	generator.buffer_length = GENERATOR_BUFFER_SECONDS
	_voice_player = AudioStreamPlayer.new()
	_voice_player.name = "Voices"
	_voice_player.bus = bus
	_voice_player.stream = generator
	add_child(_voice_player)
	_voice_player.play()
	_playback = _voice_player.get_stream_playback() as AudioStreamGeneratorPlayback


func _process(_delta: float) -> void:
	fill()


## Plays `cue` (&"click", &"click_muted", &"tick", &"clunk", &"creak", &"jam", &"snap", &"drop",
## &"open", &"relock"). An unknown cue warns and plays nothing.
func play(cue: StringName) -> void:
	var stream: AudioStream = sounds.cues.get(cue)
	if stream == null:
		push_warning("LockpickAudio: unknown cue '%s'" % cue)
		return
	if _players.is_empty():
		return  # not in the tree yet
	var player := _take_player()
	player.stream = stream
	player.play()


## Scrape target: `amount` of scraping (0..1) at wrench `tension` (0..1).
func set_scrape(amount: float, tension: float) -> void:
	_ensure_voices().set_scrape(amount, tension)


## Strain target (0..1); silent at or below the tuning's threshold.
func set_strain(strain: float) -> void:
	_ensure_voices().set_strain(strain)


## Silences everything: the continuous voices fade to 0 (their usual smoothing) and one-shots stop.
func stop_all() -> void:
	_ensure_voices().stop()
	for player in _players:
		player.stop()


## True while any one-shot player is playing.
func is_playing_one_shot() -> bool:
	for player in _players:
		if player.playing:
			return true
	return false


## Pushes as many voice frames as the generator has room for; returns how many.
func fill() -> int:
	if _playback == null:
		return 0
	var count := _playback.get_frames_available()
	if count <= 0:
		return 0
	_frames.resize(count)
	if voices.is_active():
		var mono := voices.render(count)
		for i in count:
			var value := mono[i]
			_frames[i] = Vector2(value, value)
	else:
		voices.render(0)
		_frames.fill(Vector2.ZERO)
	_playback.push_buffer(_frames)
	return count


## The voices exist before `_ready` too, so targets set early are kept.
func _ensure_voices() -> LockpickVoices:
	if voices == null:
		voices = LockpickVoices.new(sounds)
	return voices


func _take_player() -> AudioStreamPlayer:
	for i in _players.size():
		var index := (_next_player + i) % _players.size()
		if not _players[index].playing:
			_next_player = (index + 1) % _players.size()
			return _players[index]
	var oldest := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	return oldest
