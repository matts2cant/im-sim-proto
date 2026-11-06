class_name ExplosionFx
extends Node3D
## One-shot explosion: light flash that fades, fireball and smoke burst, bang. Frees itself.

## Seconds the flash takes to fade.
const FLASH_TIME: float = 0.5
const LIFETIME: float = 4.0

var _energy: float = 0.0
var _age: float = 0.0

@onready var _light: OmniLight3D = $Light
@onready var _fireball: CPUParticles3D = $Fireball
@onready var _smoke: CPUParticles3D = $Smoke
@onready var _bang: AudioStreamPlayer3D = $Bang


func setup(config: ExplosiveConfig) -> void:
	_energy = config.light_energy
	_light.omni_range = config.light_range
	_light.light_energy = _energy
	_fireball.restart()
	_smoke.restart()
	if config.sound != null:
		_bang.stream = config.sound
		_bang.volume_db = config.sound_volume_db
		_bang.play()


func _process(delta: float) -> void:
	_age += delta
	_light.light_energy = _energy * clampf(1.0 - _age / FLASH_TIME, 0.0, 1.0)
	if _age >= LIFETIME:
		queue_free()
