class_name ShotSoundLayer
extends Resource
## One layer of a shot sound (ShotSound, ADR 0128): a few recorded variants of which each shot
## picks one (never the same one twice in a row), at a base volume and pitch with a random
## variation per shot, starting `delay` seconds after the shot (a pump or a bolt after the bang).
## The numbers are @export_range so the shooting range's tuning panel lists them.

@export var streams: Array[AudioStream] = []
@export_range(-40.0, 12.0, 0.5) var volume_db: float = 0.0
## Playback speed: below 1 deeper and longer, above 1 higher and shorter.
@export_range(0.25, 3.0, 0.01) var pitch: float = 1.0
## Random variation per shot: pitch x (1 +- pitch_jitter), volume +- volume_jitter_db.
@export_range(0.0, 0.3, 0.005) var pitch_jitter: float = 0.03
@export_range(0.0, 6.0, 0.1) var volume_jitter_db: float = 1.0
@export_range(0.0, 1.0, 0.01) var delay: float = 0.0


## The index of the variant to play, avoiding `last` when there is a choice; -1 without streams.
func pick_index(rng: RandomNumberGenerator, last: int = -1) -> int:
	var count := streams.size()
	if count == 0:
		return -1
	if count == 1:
		return 0
	if last < 0 or last >= count:
		return rng.randi_range(0, count - 1)
	# One of the others, each equally likely: skip over the last one.
	var index := rng.randi_range(0, count - 2)
	return index + 1 if index >= last else index
