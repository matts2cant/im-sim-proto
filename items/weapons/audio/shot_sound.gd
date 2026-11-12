class_name ShotSound
extends Resource
## A weapon's layered shot sound (ADR 0128): the `body` (the bang), a `bass` thump and the
## `mechanism` (the action cycling: a click, a pump, a bolt), each a ShotSoundLayer that may be
## empty. pick() chooses each layer's variant, volume and pitch for one shot; ShotAudio plays them.
## Fixed slots rather than a list so the shooting range's tuning panel can reach every layer.


## One layer of one shot, ready to play.
class Voice:
	extends RefCounted
	var stream: AudioStream
	var volume_db: float
	var pitch: float
	var delay: float
	var layer: StringName

	func _init(p_stream: AudioStream, p_volume_db: float, p_pitch: float, p_delay: float, p_layer: StringName) -> void:
		stream = p_stream
		volume_db = p_volume_db
		pitch = p_pitch
		delay = p_delay
		layer = p_layer


const LAYERS: Array[StringName] = [&"body", &"bass", &"mechanism"]

@export var body: ShotSoundLayer
@export var bass: ShotSoundLayer
@export var mechanism: ShotSoundLayer


## The voices of one shot, layer by layer (body, bass, mechanism; empty layers left out): each
## layer's variant (not `last[layer]` again when it has others; `last` is updated), its volume and
## pitch varied at random within the layer's jitter, its delay.
func pick(rng: RandomNumberGenerator, last: Dictionary = {}) -> Array[Voice]:
	var voices: Array[Voice] = []
	for layer_name in LAYERS:
		var layer := get(layer_name) as ShotSoundLayer
		if layer == null:
			continue
		var index := layer.pick_index(rng, int(last.get(layer_name, -1)))
		if index < 0:
			continue
		last[layer_name] = index
		var volume := layer.volume_db + rng.randf_range(-1.0, 1.0) * layer.volume_jitter_db
		var pitch := layer.pitch * (1.0 + rng.randf_range(-1.0, 1.0) * layer.pitch_jitter)
		voices.append(Voice.new(layer.streams[index], volume, maxf(pitch, 0.01), layer.delay, layer_name))
	return voices
