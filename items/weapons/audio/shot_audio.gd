class_name ShotAudio
extends Node3D
## Plays layered shot sounds (ShotSound, ADR 0128) where it is (a WeaponHolder's child, at its
## eye): each layer of a shot on its own 3D voice from a small round-robin pool, so every voice
## keeps its own pitch and volume while earlier tails ring on (the oldest voice is reused). A
## layer with a delay starts that many seconds later. Each voice starts on the bus of its place
## (Acoustics.player_bus_at(): Effects indoors, where the zone's reverb send adds a short tail,
## the outdoor reverb bus elsewhere) and lets acoustic zones reach it (`area_mask`).

## Voices in the pool: an automatic weapon's tails overlap (three layers a shot).
const VOICES: int = 9

var rng := RandomNumberGenerator.new()
## The voices of the last shot played (tests, the debug panel).
var last_voices: Array[ShotSound.Voice] = []

var _players: Array[AudioStreamPlayer3D] = []
var _next: int = 0
# Last variant index per layer name, so a layer does not repeat itself.
var _last: Dictionary = {}
# Delayed voices: [{voice, left, offset}].
var _pending: Array[Dictionary] = []


func _init(p_seed: int = 0) -> void:
	name = "ShotAudio"
	if p_seed != 0:
		rng.seed = p_seed
	else:
		rng.randomize()
	for i in VOICES:
		var player := AudioStreamPlayer3D.new()
		player.name = "Voice%d" % i
		player.bus = GameSettings.EFFECTS_BUS
		player.area_mask = PhysicsLayers.ACOUSTICS
		player.max_polyphony = 1
		add_child(player)
		_players.append(player)
	set_physics_process(false)


## Plays one shot of `sound`, every layer `volume_offset_db` louder (an attachment's volume
## change). Returns the voices chosen.
func play(sound: ShotSound, volume_offset_db: float = 0.0) -> Array[ShotSound.Voice]:
	last_voices = sound.pick(rng, _last)
	for voice in last_voices:
		if voice.delay > 0.0:
			_pending.append({"voice": voice, "left": voice.delay, "offset": volume_offset_db})
		else:
			_start(voice, volume_offset_db)
	set_physics_process(not _pending.is_empty())
	return last_voices


## The bus a voice started now plays on (Acoustics.player_bus_at() here).
func current_bus() -> StringName:
	return Acoustics.player_bus_at(get_world_3d() if is_inside_tree() else null, _position(), GameSettings.EFFECTS_BUS)


## The pool's voices (tests).
func voices() -> Array[AudioStreamPlayer3D]:
	return _players


func _physics_process(delta: float) -> void:
	var waiting: Array[Dictionary] = []
	for entry in _pending:
		entry["left"] = float(entry["left"]) - delta
		if float(entry["left"]) <= 0.0:
			_start(entry["voice"] as ShotSound.Voice, float(entry["offset"]))
		else:
			waiting.append(entry)
	_pending = waiting
	set_physics_process(not _pending.is_empty())


func _start(voice: ShotSound.Voice, offset_db: float) -> void:
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stop()
	player.stream = voice.stream
	player.volume_db = voice.volume_db + offset_db
	player.pitch_scale = voice.pitch
	player.bus = current_bus()
	if player.is_inside_tree():
		player.play()


func _position() -> Vector3:
	return global_position if is_inside_tree() else position
