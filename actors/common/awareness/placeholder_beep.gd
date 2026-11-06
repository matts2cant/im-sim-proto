class_name PlaceholderBeep
extends RefCounted
## Generated placeholder sounds (no audio files): a short sine tone with a soft attack and decay,
## 16-bit mono. Cached per frequency.

const MIX_RATE: int = 22050

static var _cache: Dictionary[int, AudioStreamWAV] = {}


## A `length`-second tone at `frequency` Hz.
static func tone(frequency: float, length: float = 0.18) -> AudioStreamWAV:
	var key := roundi(frequency * 10.0) * 1000 + roundi(length * 100.0)
	if _cache.has(key):
		return _cache[key]
	var count := maxi(int(MIX_RATE * length), 1)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / MIX_RATE
		var envelope := minf(t / 0.01, 1.0) * (1.0 - float(i) / count)
		var sample := int(sin(TAU * frequency * t) * envelope * 0.5 * 32767.0)
		data.encode_s16(i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	_cache[key] = stream
	return stream
