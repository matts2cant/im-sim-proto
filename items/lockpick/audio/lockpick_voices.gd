class_name LockpickVoices
extends RefCounted
## The lockpicking minigame's two continuous voices, synthesised sample by sample (pure logic; the
## LockpickAudio node streams `render()` into an AudioStreamGenerator). A port of the prototype's
## `audioFrame()` ([ADR 0108](../../../design/decisions/0108-lockpick-sounds.md)):
## - scrape: a looping 1 s white-noise buffer through a Web Audio bandpass (Q `scrape_q`, centre
##   `scrape_frequency + tension * scrape_frequency_per_tension`), gain `scraping * scrape_gain`;
## - strain: a triangle oscillator, gain `s * strain_gain`, pitch
##   `strain_frequency + s * strain_frequency_per_strain`, where s = strain above the threshold, else 0.
## Gains and frequencies approach their targets like Web Audio's setTargetAtTime (a first-order
## approach with the tuning's time constants), per sample; the bandpass coefficients follow the
## smoothed centre every BLOCK samples. Both voices go through the master gain.

## Samples per filter-coefficient update (inaudible next to the 50 ms frequency smoothing).
const BLOCK: int = 32
## A voice whose gain and target are below this renders nothing.
const SILENT: float = 1e-6
const NOISE_SEED: int = 0x10C4

var sounds: LockpickSounds

var _noise := PackedFloat32Array()
var _noise_position: int = 0
var _filter := WebAudioBiquad.new()

var _scrape_gain: float = 0.0
var _scrape_gain_target: float = 0.0
var _scrape_frequency: float = 0.0
var _scrape_frequency_target: float = 0.0

var _strain_gain: float = 0.0
var _strain_gain_target: float = 0.0
var _strain_frequency: float = 0.0
var _strain_frequency_target: float = 0.0
var _strain_phase: float = 0.0


func _init(tuning: LockpickSounds) -> void:
	sounds = tuning
	var rng := RandomNumberGenerator.new()
	rng.seed = NOISE_SEED
	_noise.resize(int(sounds.sample_rate))
	for i in _noise.size():
		_noise[i] = rng.randf() * 2.0 - 1.0
	_scrape_frequency = sounds.scrape_start_frequency
	_scrape_frequency_target = sounds.scrape_start_frequency
	_strain_frequency = sounds.strain_start_frequency
	_strain_frequency_target = sounds.strain_start_frequency


## `amount` how much the pick is scraping (0..1), `tension` the wrench's tension (0..1).
func set_scrape(amount: float, tension: float) -> void:
	_scrape_gain_target = maxf(amount, 0.0) * sounds.scrape_gain
	_scrape_frequency_target = (sounds.scrape_frequency + tension * sounds.scrape_frequency_per_tension)


## `strain` on the pick (0..1, it breaks at 1).
func set_strain(strain: float) -> void:
	var s := strain if strain > sounds.strain_threshold else 0.0
	_strain_gain_target = s * sounds.strain_gain
	_strain_frequency_target = sounds.strain_frequency + s * sounds.strain_frequency_per_strain


## Both voices fade out (the same smoothing).
func stop() -> void:
	set_scrape(0.0, 0.0)
	set_strain(0.0)


## True while either voice is audible or heading somewhere audible.
func is_active() -> bool:
	return _scrape_active() or _strain_active()


## The scrape filter's current (smoothed) centre frequency, Hz.
func get_scrape_frequency() -> float:
	return _scrape_frequency


## The next `frames` mono samples (master gain applied).
func render(frames: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(frames)
	# A silent voice skips its work; its frequency is taken as settled on its target.
	if _scrape_active():
		_render_scrape(out)
	else:
		_scrape_gain = 0.0
		_scrape_frequency = _scrape_frequency_target
	if _strain_active():
		_render_strain(out)
	else:
		_strain_gain = 0.0
		_strain_frequency = _strain_frequency_target
	return out


func _scrape_active() -> bool:
	return _scrape_gain > SILENT or _scrape_gain_target > SILENT


func _strain_active() -> bool:
	return _strain_gain > SILENT or _strain_gain_target > SILENT


func _render_scrape(out: PackedFloat32Array) -> void:
	var rate := sounds.sample_rate
	var gain_keep := exp(-1.0 / (rate * sounds.scrape_gain_time))
	var frequency_keep := exp(-1.0 / (rate * sounds.scrape_frequency_time))
	var master := sounds.master_gain
	var gain := _scrape_gain
	var target := _scrape_gain_target
	var position := _noise_position
	var noise_size := _noise.size()
	var block := PackedFloat32Array()
	var start := 0
	while start < out.size():
		var count := mini(BLOCK, out.size() - start)
		_filter.configure(WebAudioBiquad.Type.BANDPASS, _scrape_frequency, sounds.scrape_q, rate)
		_scrape_frequency = (
			_scrape_frequency_target + (_scrape_frequency - _scrape_frequency_target) * pow(frequency_keep, count)
		)
		block.resize(count)
		for i in count:
			block[i] = _noise[position]
			position += 1
			if position == noise_size:
				position = 0
		_filter.process_range(block, 0, count)
		for i in count:
			out[start + i] += block[i] * gain * master
			gain = target + (gain - target) * gain_keep
		start += count
	_scrape_gain = gain
	_noise_position = position


func _render_strain(out: PackedFloat32Array) -> void:
	var rate := sounds.sample_rate
	var gain_keep := exp(-1.0 / (rate * sounds.strain_gain_time))
	var frequency_keep := exp(-1.0 / (rate * sounds.strain_frequency_time))
	var master := sounds.master_gain
	var gain := _strain_gain
	var gain_target := _strain_gain_target
	var frequency := _strain_frequency
	var frequency_target := _strain_frequency_target
	var phase := _strain_phase
	for i in out.size():
		# Triangle as Web Audio defines it: 0 at phase 0, rising to 1 at a quarter period.
		var wave: float
		if phase < 0.25:
			wave = 4.0 * phase
		elif phase < 0.75:
			wave = 2.0 - 4.0 * phase
		else:
			wave = 4.0 * phase - 4.0
		out[i] += wave * gain * master
		phase += frequency / rate
		if phase >= 1.0:
			phase -= 1.0
		gain = gain_target + (gain - gain_target) * gain_keep
		frequency = frequency_target + (frequency - frequency_target) * frequency_keep
	_strain_gain = gain
	_strain_frequency = frequency
	_strain_phase = phase
