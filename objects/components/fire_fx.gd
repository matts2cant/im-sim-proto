class_name FireFx
extends Node3D
## Visuals and sound of a burning object: flickering orange light, flame particles, crackle loop.
## Sized from the FlammableConfig in setup(); freed by its Flammable when the fire goes out.

var _base_energy: float = 1.0
var _flicker: float = 0.0
var _time: float = 0.0

@onready var _light: OmniLight3D = $Light
@onready var _flames: CPUParticles3D = $Flames
@onready var _crackle: AudioStreamPlayer3D = $Crackle


func setup(config: FlammableConfig) -> void:
	_base_energy = config.light_energy
	_flicker = config.light_flicker
	_light.omni_range = config.radius * config.light_range_factor
	_light.light_energy = _base_energy
	_flames.emission_sphere_radius = config.flame_size
	_flames.scale_amount_min = config.flame_size * 1.2
	_flames.scale_amount_max = config.flame_size * 2.0
	_time = randf() * 10.0
	if config.crackle != null:
		_crackle.stream = config.crackle
		_crackle.volume_db = config.crackle_volume_db
		_crackle.finished.connect(_crackle.play)
		_crackle.play(randf() * 0.5)


func _process(delta: float) -> void:
	_time += delta
	var wobble := sin(_time * 13.0) * 0.5 + sin(_time * 7.3 + 1.7) * 0.3 + sin(_time * 23.1) * 0.2
	_light.light_energy = _base_energy * (1.0 + _flicker * wobble)
